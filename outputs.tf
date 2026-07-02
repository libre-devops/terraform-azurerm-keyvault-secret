# No secret value is ever exported: value_wo is write-only and never enters state, so there is nothing
# sensitive to output. Everything here is metadata and ids.

output "secrets" {
  description = "Map of secret name to its metadata and ids (no value; value_wo is never stored)."
  value = {
    for k, s in azurerm_key_vault_secret.this : k => {
      id                      = s.id
      name                    = s.name
      version                 = s.version
      versionless_id          = s.versionless_id
      resource_id             = s.resource_id
      resource_versionless_id = s.resource_versionless_id
      content_type            = s.content_type
      expiration_date         = s.expiration_date
      not_before_date         = s.not_before_date
      value_wo_version        = s.value_wo_version
    }
  }
}

output "secret_ids" {
  description = "Map of secret name to its versioned id."
  value       = { for k, s in azurerm_key_vault_secret.this : k => s.id }
}

output "secret_ids_zipmap" {
  description = "Map of secret name to { name, id }, for easy composition with other modules."
  value       = { for k, s in azurerm_key_vault_secret.this : k => { name = s.name, id = s.id } }
}

output "secret_versionless_ids" {
  description = "Map of secret name to its versionless id (always resolves to the latest version)."
  value       = { for k, s in azurerm_key_vault_secret.this : k => s.versionless_id }
}

output "key_vault_name" {
  description = "The name of the Key Vault the secrets were written into, parsed from key_vault_id."
  value       = local.kv.resource_name
}
