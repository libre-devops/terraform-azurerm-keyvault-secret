<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Key Vault Secret

Key Vault secrets written with write-only values, so the plaintext never lands in Terraform state.

[![CI](https://github.com/libre-devops/terraform-azurerm-keyvault-secret/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-keyvault-secret/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-keyvault-secret?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-keyvault-secret/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-keyvault-secret)](./LICENSE)

---

## Overview

Secrets keyed by name, written into a vault you pass by id. The point of this module is that a secret
value is **never stored in Terraform state**: it is written through the provider's write-only `value_wo`
argument, and it comes from an ephemeral source, so the plaintext exists only in transit and in the
vault.

- **Two value sources, both ephemeral.** Set `generate = true` and the module generates the value with
  an `ephemeral "random_password"` (opened during apply, never persisted); otherwise the value is read
  from the ephemeral `secret_values` variable, keyed by the same secret name. Supply that from your own
  ephemeral variable or resource.
- **Rotation is explicit.** A write-only value is not tracked in state, so Terraform cannot detect a
  change to it on its own. Bump a secret's `value_wo_version` to rotate it (for a generated secret this
  writes a freshly generated value). Leaving the version alone leaves the vault untouched.
- **No secret ever leaves in an output.** The module exports ids, names, versions, and metadata only,
  because there is no value in state to export. Outputs are not marked sensitive, because none of them
  are.
- **Generation controls and metadata.** `length`, `special`, `override_special`, and the `min_*` counts
  drive generation; `content_type`, `not_before_date`, `expiration_date`, and per-secret `tags` are
  passed through.

Requires Terraform >= 1.11 (write-only arguments), azurerm >= 4.23 (`value_wo` on
`azurerm_key_vault_secret`), and the random provider >= 3.7 (the ephemeral `random_password`). Pairs
with the `keyvault` module, which creates the vault and grants the writer access.

## Usage

```hcl
module "keyvault_secret" {
  source  = "libre-devops/keyvault-secret/azurerm"
  version = "~> 4.0"

  key_vault_id = module.keyvault.ids["kv-ldo-uks-prd-001"]
  tags         = module.tags.tags

  # An ephemeral value the caller supplies (never written to state).
  secret_values = {
    "db-connection-string" = ephemeral.random_password.db.result
  }

  secrets = {
    # Value supplied above.
    "db-connection-string" = { content_type = "text/plain" }

    # Value generated inside the module, never seen by Terraform state.
    "app-signing-key" = {
      generate = true
      length   = 48
    }
  }
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - a single generated secret in a fresh vault.
- [`examples/complete`](./examples/complete) - every feature: a caller-supplied ephemeral value, several
  generated secrets exercising the generation controls, a rotated secret, content type, not-before and
  expiration dates, and per-secret tags.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in a table
here so the reason is auditable.

There are currently **no exceptions**: the module and its examples scan clean. The module's whole
purpose is to keep secret values out of state, so there is nothing to waive.

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here recording the reason. Both the file and
the table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
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

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault_secret.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_key_vault_id"></a> [key\_vault\_id](#input\_key\_vault\_id) | The id of the Key Vault the secrets are written into. Parsed for the vault name in outputs. | `string` | n/a | yes |
| <a name="input_secret_values"></a> [secret\_values](#input\_secret\_values) | The values for non-generated secrets, keyed by the same secret name used in `secrets`. This variable is<br/>ephemeral: its values are used only during the run and are never written to plan or state. Supply it<br/>from an ephemeral source (an ephemeral variable or resource) so the plaintext never touches disk. | `map(string)` | `{}` | no |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | The secrets to write, keyed by secret name. This map holds only non-sensitive metadata: the actual<br/>secret value is never taken here and never stored in state. A value comes from one of two write-only<br/>(never persisted) sources:<br/><br/>- `generate = true`: the module generates the value with an ephemeral random\_password (never stored).<br/>- `generate = false` (default): the value is taken from the ephemeral `secret_values` variable, keyed<br/>  by the same secret name.<br/><br/>Either way the value is written through the provider's write-only `value_wo` argument. Because a<br/>write-only value is not tracked in state, Terraform cannot detect a change to it on its own: bump<br/>`value_wo_version` to rotate the secret (for a generated secret this writes a freshly generated value). | <pre>map(object({<br/>    value_wo_version = optional(number, 1)<br/>    content_type     = optional(string)<br/>    expiration_date  = optional(string)<br/>    not_before_date  = optional(string)<br/>    tags             = optional(map(string))<br/><br/>    # Generation controls (used only when generate = true).<br/>    generate         = optional(bool, false)<br/>    length           = optional(number, 32)<br/>    special          = optional(bool, true)<br/>    override_special = optional(string)<br/>    min_lower        = optional(number, 0)<br/>    min_upper        = optional(number, 0)<br/>    min_numeric      = optional(number, 0)<br/>    min_special      = optional(number, 0)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every secret (merged with any per-secret tags). | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | The name of the Key Vault the secrets were written into, parsed from key\_vault\_id. |
| <a name="output_secret_ids"></a> [secret\_ids](#output\_secret\_ids) | Map of secret name to its versioned id. |
| <a name="output_secret_ids_zipmap"></a> [secret\_ids\_zipmap](#output\_secret\_ids\_zipmap) | Map of secret name to { name, id }, for easy composition with other modules. |
| <a name="output_secret_versionless_ids"></a> [secret\_versionless\_ids](#output\_secret\_versionless\_ids) | Map of secret name to its versionless id (always resolves to the latest version). |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Map of secret name to its metadata and ids (no value; value\_wo is never stored). |
<!-- END_TF_DOCS -->
