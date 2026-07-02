# The vault name is parsed from the id for the outputs (see pass-ids convention).
locals {
  kv = provider::azurerm::parse_resource_id(var.key_vault_id)
}

# Ephemeral random values for the secrets that ask to be generated. An ephemeral resource is opened
# during apply and its result is never written to state, so the generated secret only ever exists in
# the vault, not in Terraform's state.
ephemeral "random_password" "this" {
  for_each = { for name, s in var.secrets : name => s if s.generate }

  length           = each.value.length
  special          = each.value.special
  override_special = each.value.override_special
  min_lower        = each.value.min_lower
  min_upper        = each.value.min_upper
  min_numeric      = each.value.min_numeric
  min_special      = each.value.min_special
}

# The secret value is supplied through value_wo (write-only): it is sent to Azure on apply but never
# stored in state or shown in the plan. The value comes from the ephemeral generator for generated
# secrets, otherwise from the ephemeral secret_values map. The conditional only evaluates the branch it
# takes, so a missing key on the other side is never read.
resource "azurerm_key_vault_secret" "this" {
  for_each = var.secrets

  key_vault_id = var.key_vault_id
  tags         = merge(var.tags, coalesce(each.value.tags, {}))
  name         = each.key

  value_wo         = each.value.generate ? ephemeral.random_password.this[each.key].result : lookup(var.secret_values, each.key, null)
  value_wo_version = each.value.value_wo_version

  content_type    = each.value.content_type
  expiration_date = each.value.expiration_date
  not_before_date = each.value.not_before_date
}
