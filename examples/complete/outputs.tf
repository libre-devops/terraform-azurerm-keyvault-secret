output "secret_ids" {
  description = "Map of secret name to versioned id."
  value       = module.keyvault_secret.secret_ids
}

output "secret_ids_zipmap" {
  description = "Map of secret name to { name, id }."
  value       = module.keyvault_secret.secret_ids_zipmap
}

output "secret_versionless_ids" {
  description = "Map of secret name to versionless id."
  value       = module.keyvault_secret.secret_versionless_ids
}

output "secrets" {
  description = "Full secret metadata map (no values; value_wo is never stored)."
  value       = module.keyvault_secret.secrets
}
