locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  kv_name  = "kv-${var.short}-${var.loc}-${terraform.workspace}-002"
}

data "azurerm_client_config" "current" {}

# The runner's public egress IP, so it can be allow-listed on the vault firewall (this subscription
# enforces default-deny network rules on key vaults, so the writer's IP must be permitted).
module "runner_ip" {
  source  = "libre-devops/get-ip-address/external"
  version = "~> 4.0"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-keyvault-secret" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# A vault to hold the secrets. Access policies grant the caller secret access so the writes work
# immediately. purge_protection is off only so the example is disposable.
module "keyvault" {
  source  = "libre-devops/keyvault/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  key_vaults = {
    (local.kv_name) = {
      rbac_authorization_enabled = false
      purge_protection_enabled   = false
      network_acls = {
        default_action = "Deny"
        bypass         = "AzureServices"
        ip_rules       = ["${module.runner_ip.public_ip_address}/32"]
      }
      access_policies = [
        {
          object_id          = data.azurerm_client_config.current.object_id
          secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Purge"]
        }
      ]
    }
  }
}

# Give the vault firewall rule a moment to take effect before the data-plane secret writes.
resource "time_sleep" "kv_firewall" {
  create_duration = "60s"

  triggers = {
    vault = module.keyvault.ids[local.kv_name]
    ip    = module.runner_ip.public_ip_address
  }
}

# A caller-side ephemeral value, to demonstrate supplying a secret value that never touches state. Any
# ephemeral source works here (an ephemeral variable, another ephemeral resource, and so on).
ephemeral "random_password" "supplied" {
  length  = 40
  special = true
}

# Complete call: every feature. A caller-supplied value (from the ephemeral resource above), several
# generated secrets exercising the generation controls, a rotated secret (value_wo_version = 2),
# content_type, not_before / expiration dates, and per-secret tags. No secret value is ever stored in
# state or shown in the plan.
module "keyvault_secret" {
  source = "../../"

  key_vault_id = module.keyvault.ids[local.kv_name]
  tags         = module.tags.tags

  # Ephemeral, never persisted. Keyed by the same name as the secrets entry below.
  secret_values = {
    "app-connection-string" = ephemeral.random_password.supplied.result
  }

  secrets = {
    # Value supplied by the caller (from secret_values), with metadata and dates.
    "app-connection-string" = {
      content_type    = "text/plain"
      not_before_date = "2026-01-01T00:00:00Z"
      expiration_date = "2027-01-01T00:00:00Z"
      tags            = { Component = "app" }
    }

    # Simple generated secret.
    "generated-password" = {
      generate = true
      length   = 32
    }

    # Generated, alphanumeric only, rotated once (bump value_wo_version again to rotate further).
    "generated-api-key" = {
      generate         = true
      length           = 48
      special          = false
      value_wo_version = 2
    }

    # Generated with the full set of complexity controls and a custom special-character set.
    "complex-generated" = {
      generate         = true
      length           = 24
      min_lower        = 4
      min_upper        = 4
      min_numeric      = 4
      min_special      = 4
      override_special = "!#$%&*-_=+"
    }
  }

  depends_on = [time_sleep.kv_firewall]
}
