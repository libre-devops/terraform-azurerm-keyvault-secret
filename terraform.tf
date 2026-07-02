terraform {
  # 1.11 is the floor for write-only arguments (value_wo) and ephemeral values.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # 4.23.0 is where azurerm_key_vault_secret gained value_wo / value_wo_version.
      version = ">= 4.23.0, < 5.0.0"
    }
    random = {
      source = "hashicorp/random"
      # 3.7.0 is where the random provider gained the ephemeral random_password resource.
      version = ">= 3.7.0, < 4.0.0"
    }
  }
}
