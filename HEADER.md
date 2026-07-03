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

| ID | Scope | Reason |
| --- | --- | --- |
| AVD-AZU-0013 (vault network ACL default action) | `examples/complete/main.tf` | The disposable example vault opts out of the keyvault module's deny-by-default firewall so the CI self-test runner can reach the data plane; real deployments keep the secure default, and the firewalled shape plus the terraform-azure action's key vault dance are documented alongside. |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here recording the reason. Both the file and
the table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.
