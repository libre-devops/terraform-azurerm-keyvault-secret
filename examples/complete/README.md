<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

Every feature of the module. A caller-supplied ephemeral value (from an `ephemeral "random_password"`
in the example, showing how to pass a value that never touches state), several generated secrets that
exercise the generation controls (`length`, `special`, `override_special`, and the `min_*` counts), a
rotated secret via `value_wo_version`, plus `content_type`, not-before / expiration dates, and per-secret
tags. No secret value is ever stored in state or printed in the plan. Run it with `just e2e complete`,
which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
locals {
  location = lookup(var.regions, var.loc, "uksouth")
  rg_name  = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  kv_name  = "kv-${var.short}-${var.loc}-${terraform.workspace}-002"
}

data "azurerm_client_config" "current" {}

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
      access_policies = [
        {
          object_id          = data.azurerm_client_config.current.object_id
          secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Purge"]
        }
      ]
    }
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
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.23.0, < 5.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.23.0, < 5.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_keyvault"></a> [keyvault](#module\_keyvault) | libre-devops/keyvault/azurerm | ~> 4.0 |
| <a name="module_keyvault_secret"></a> [keyvault\_secret](#module\_keyvault\_secret) | ../../ | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secret_ids"></a> [secret\_ids](#output\_secret\_ids) | Map of secret name to versioned id. |
| <a name="output_secret_ids_zipmap"></a> [secret\_ids\_zipmap](#output\_secret\_ids\_zipmap) | Map of secret name to { name, id }. |
| <a name="output_secret_versionless_ids"></a> [secret\_versionless\_ids](#output\_secret\_versionless\_ids) | Map of secret name to versionless id. |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Full secret metadata map (no values; value\_wo is never stored). |
<!-- END_TF_DOCS -->
