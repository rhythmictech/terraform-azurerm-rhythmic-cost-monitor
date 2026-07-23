mock_provider "azurerm" {
  source = "./tests/setup"
}

# The examples/basic root config must produce a valid plan, guarding that the
# published example stays in sync with the module interface.
run "examples_basic_plans" {
  command = plan

  variables {
    subscription_id = "00000000-0000-0000-0000-000000000000"
  }

  module {
    source = "./examples/basic"
  }
}
