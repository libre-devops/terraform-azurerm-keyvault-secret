output "secret_ids" {
  description = "Map of secret name to id."
  value       = module.keyvault_secret.secret_ids
}

output "secret_ids_zipmap" {
  description = "Map of secret name to { name, id }."
  value       = module.keyvault_secret.secret_ids_zipmap
}
