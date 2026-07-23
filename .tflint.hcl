config {
  # Lint calls into child modules as well (replaces the deprecated `module = true`).
  call_module_type = "all"
}

# azurerm ruleset (this is the Azure sibling of the AWS module's aws ruleset).
plugin "azurerm" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = true
}

# This module's only storage accounts back the expiring-reservations Function
# (ephemeral runtime state) and the cost exports (regenerated daily). Neither
# holds data that must survive a replace, so prevent_destroy would wrongly block
# routine recreation. Disable the rule module-wide rather than annotate each
# account inline (an inline tflint-ignore would sit between the trivy:ignore
# comments and the resource and break trivy's ignore association).
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
