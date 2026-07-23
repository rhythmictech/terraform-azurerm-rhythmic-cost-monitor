"""Timer-triggered Function that reports soon-to-expire Azure reservations and
savings plans to Datadog as events.

This is the Azure port of the AWS ``monitor_sps_and_ris`` Lambda. The AWS version
enumerated EC2, RDS, and Redshift reserved instances plus Savings Plans and
published a single SNS message with ``Warning`` (expiring within the warning
window) and ``Alert`` (expiring within the tighter alert window) buckets. Azure
has no SNS analog an Action Group can receive an arbitrary message through, so
this version posts directly to the Datadog Events API instead. The warning and
alert windows arrive as the WARNING_EXP and ALERT_EXP environment variables
because timer triggers, unlike EventBridge rules, take no input payload.

Identity: the Function runs with a system-assigned managed identity picked up by
DefaultAzureCredential. Reservation and savings-plan visibility additionally
needs the Reservations Reader role (Microsoft.Capacity) at tenant scope, which a
billing or tenant admin must grant out of band; the Terraform identity cannot
assign a tenant-scope role. See the module README.
"""

import datetime
import json
import logging
import os

import azure.functions as func
import requests
from azure.identity import DefaultAzureCredential

app = func.FunctionApp()

# 17:00:00 UTC daily, the equivalent of the AWS module's noon-Eastern cron.
# NCRONTAB fields are {second} {minute} {hour} {day} {month} {day-of-week}.
_SCHEDULE = "0 0 17 * * *"


def _parse_date(value):
    """Coerce an SDK expiry value (datetime or ISO-8601 string) to an aware
    UTC datetime, or return None if it cannot be parsed."""
    if value is None:
        return None
    if isinstance(value, datetime.datetime):
        parsed = value
    else:
        try:
            parsed = datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        except ValueError:
            logging.warning("could not parse expiry value %r", value)
            return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=datetime.timezone.utc)
    return parsed


def _bucket(notifications, kind, identifier, expiry, warning_days, alert_days, now):
    """Classify a single reservation or savings plan into the Warning or Alert
    bucket, mirroring the AWS module's 0 <= days <= warning window with the
    tighter alert cutoff."""
    expiration_date = _parse_date(expiry)
    if expiration_date is None:
        return
    days_until_expiration = (expiration_date - now).days
    if 0 <= days_until_expiration <= warning_days:
        category = "Alert" if days_until_expiration <= alert_days else "Warning"
        notifications[category].append(
            {
                "Type": kind,
                "Id": identifier,
                "ExpiryDate": expiration_date.strftime("%Y-%m-%dT%H:%M:%SZ"),
            }
        )


def _collect_reservations(credential, notifications, warning_days, alert_days, now):
    """Enumerate every reservation across every reservation order."""
    # TODO(verify-live): confirm the AzureReservationAPIClient operation names
    # (reservation_order.list / reservation.list) and the reservation expiry
    # property against the installed azure-mgmt-reservations version; property
    # names below are accessed defensively.
    try:
        from azure.mgmt.reservations import AzureReservationAPIClient

        client = AzureReservationAPIClient(credential)
        for order in client.reservation_order.list():
            order_id = getattr(order, "name", None) or getattr(order, "id", None)
            for reservation in client.reservation.list(reservation_order_id=order_id):
                props = getattr(reservation, "properties", reservation)
                expiry = (
                    getattr(props, "expiry_date_time", None)
                    or getattr(props, "expiry_date", None)
                )
                identifier = getattr(reservation, "name", None) or order_id
                _bucket(
                    notifications,
                    "Reservation",
                    identifier,
                    expiry,
                    warning_days,
                    alert_days,
                    now,
                )
    except Exception:  # noqa: BLE001 - never fail the run on one data source
        logging.exception("failed to enumerate reservations")


def _collect_savings_plans(credential, notifications, warning_days, alert_days, now):
    """Enumerate every savings plan."""
    # TODO(verify-live): confirm the BillingBenefitsRP savings-plan operation
    # (savings_plan.list_all) and expiry property against the installed
    # azure-mgmt-billingbenefits version; accessed defensively below.
    try:
        from azure.mgmt.billingbenefits import BillingBenefitsRP

        client = BillingBenefitsRP(credential)
        for plan in client.savings_plan.list_all():
            props = getattr(plan, "properties", plan)
            expiry = (
                getattr(props, "expiry_date_time", None)
                or getattr(props, "expiry_date", None)
            )
            identifier = getattr(plan, "name", None) or getattr(plan, "id", None)
            _bucket(
                notifications,
                "SavingsPlan",
                identifier,
                expiry,
                warning_days,
                alert_days,
                now,
            )
    except Exception:  # noqa: BLE001 - never fail the run on one data source
        logging.exception("failed to enumerate savings plans")


def _post_datadog_event(notifications):
    """Post one Datadog event summarizing the expiring commitments. alert_type
    is error when anything is inside the tight alert window, warning otherwise."""
    api_key = os.environ["DD_API_KEY"]
    site = os.environ.get("DD_SITE", "datadoghq.com")
    alert_type = "error" if notifications["Alert"] else "warning"
    payload = {
        "title": "Expiring Azure reservations and savings plans",
        "text": json.dumps(
            {"Warning": notifications["Warning"], "Alert": notifications["Alert"]}
        ),
        "alert_type": alert_type,
        "tags": [
            "source:rhythmic-cost-monitor",
            "service:azure_managed_services",
        ],
    }
    response = requests.post(
        "https://api.{}/api/v1/events".format(site),
        headers={"DD-API-KEY": api_key, "Content-Type": "application/json"},
        data=json.dumps(payload),
        timeout=30,
    )
    response.raise_for_status()


@app.timer_trigger(
    schedule=_SCHEDULE,
    arg_name="timer",
    run_on_startup=False,
    use_monitor=True,
)
def monitor_expiring_reservations(timer: func.TimerRequest) -> None:
    warning_days = int(os.environ.get("WARNING_EXP", "30"))
    alert_days = int(os.environ.get("ALERT_EXP", "7"))
    now = datetime.datetime.now(datetime.timezone.utc)

    notifications = {"Warning": [], "Alert": []}
    credential = DefaultAzureCredential()

    _collect_reservations(credential, notifications, warning_days, alert_days, now)
    _collect_savings_plans(credential, notifications, warning_days, alert_days, now)

    if notifications["Warning"] or notifications["Alert"]:
        _post_datadog_event(notifications)
    else:
        logging.info("no reservations or savings plans expiring within the window")
