variable "key_vault_id" {
  description = "The id of the Key Vault the secrets are written into. Parsed for the vault name in outputs."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("/providers/Microsoft.KeyVault/vaults/", var.key_vault_id))
    error_message = "key_vault_id must be an azurerm_key_vault resource id (/.../providers/Microsoft.KeyVault/vaults/<name>)."
  }
}

variable "tags" {
  description = "Tags applied to every secret (merged with any per-secret tags)."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<DESC
The secrets to write, keyed by secret name. This map holds only non-sensitive metadata: the actual
secret value is never taken here and never stored in state. A value comes from one of two write-only
(never persisted) sources:

- `generate = true`: the module generates the value with an ephemeral random_password (never stored).
- `generate = false` (default): the value is taken from the ephemeral `secret_values` variable, keyed
  by the same secret name.

Either way the value is written through the provider's write-only `value_wo` argument. Because a
write-only value is not tracked in state, Terraform cannot detect a change to it on its own: bump
`value_wo_version` to rotate the secret (for a generated secret this writes a freshly generated value).
DESC

  type = map(object({
    value_wo_version = optional(number, 1)
    content_type     = optional(string)
    expiration_date  = optional(string)
    not_before_date  = optional(string)
    tags             = optional(map(string))

    # Generation controls (used only when generate = true).
    generate         = optional(bool, false)
    length           = optional(number, 32)
    special          = optional(bool, true)
    override_special = optional(string)
    min_lower        = optional(number, 0)
    min_upper        = optional(number, 0)
    min_numeric      = optional(number, 0)
    min_special      = optional(number, 0)
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.secrets) : can(regex("^[0-9a-zA-Z-]{1,127}$", name))])
    error_message = "Each secret name (map key) must be 1 to 127 characters of letters, digits, and dashes only."
  }

  validation {
    condition     = alltrue([for s in values(var.secrets) : s.value_wo_version >= 1])
    error_message = "value_wo_version must be a positive integer (start at 1 and increment to rotate)."
  }

  validation {
    condition     = alltrue([for s in values(var.secrets) : !s.generate || s.length >= 1])
    error_message = "A generated secret needs length >= 1."
  }

  validation {
    condition     = alltrue([for s in values(var.secrets) : !s.generate || (s.min_lower + s.min_upper + s.min_numeric + s.min_special) <= s.length])
    error_message = "For a generated secret, min_lower + min_upper + min_numeric + min_special must not exceed length."
  }
}

variable "secret_values" {
  description = <<DESC
The values for non-generated secrets, keyed by the same secret name used in `secrets`. This variable is
ephemeral: its values are used only during the run and are never written to plan or state. Supply it
from an ephemeral source (an ephemeral variable or resource) so the plaintext never touches disk.
DESC

  type      = map(string)
  default   = {}
  ephemeral = true
}
