# Tests for the module. azurerm is mocked (no credentials, no cloud); the random provider runs for real
# to open the ephemeral generator. command = apply is used so the ephemeral resource and the write-only
# value_wo path actually execute:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-001/providers/Microsoft.KeyVault/vaults/kv-ldo-uks-tst-001"
}

# A supplied secret (value from the ephemeral secret_values) and a generated secret in one call.
run "supplied_and_generated" {
  command = apply

  variables {
    tags = { Environment = "tst" }
    secrets = {
      supplied = { content_type = "text/plain" }
      generated = {
        generate = true
        length   = 24
      }
    }
    secret_values = {
      supplied = "s3cr3t-value"
    }
  }

  assert {
    condition     = length(azurerm_key_vault_secret.this) == 2
    error_message = "Both the supplied and the generated secret should be created."
  }

  assert {
    condition     = azurerm_key_vault_secret.this["supplied"].name == "supplied"
    error_message = "The secret name should be the map key."
  }

  assert {
    condition     = azurerm_key_vault_secret.this["supplied"].content_type == "text/plain"
    error_message = "content_type should pass through."
  }

  assert {
    condition     = azurerm_key_vault_secret.this["generated"].value_wo_version == 1
    error_message = "value_wo_version should default to 1."
  }
}

# Per-secret tags are merged over the module-level tags.
run "tags_are_merged" {
  command = apply

  variables {
    tags = { Environment = "tst", Owner = "platform" }
    secrets = {
      db = { tags = { Component = "database" } }
    }
    secret_values = { db = "connstring" }
  }

  assert {
    condition     = azurerm_key_vault_secret.this["db"].tags["Environment"] == "tst" && azurerm_key_vault_secret.this["db"].tags["Component"] == "database"
    error_message = "Module tags and per-secret tags should be merged."
  }
}

# A custom value_wo_version passes through (the caller bumps this to rotate).
run "version_passthrough" {
  command = apply

  variables {
    secrets = {
      rotated = { generate = true, value_wo_version = 3 }
    }
    secret_values = {}
  }

  assert {
    condition     = azurerm_key_vault_secret.this["rotated"].value_wo_version == 3
    error_message = "A custom value_wo_version should pass through."
  }
}

# Both dates set: exercises the date-ordering check (a good date pair should apply cleanly).
run "dated_secret" {
  command = apply

  variables {
    secrets = {
      dated = {
        generate        = true
        not_before_date = "2026-01-01T00:00:00Z"
        expiration_date = "2027-01-01T00:00:00Z"
      }
    }
    secret_values = {}
  }

  assert {
    condition     = azurerm_key_vault_secret.this["dated"].not_before_date == "2026-01-01T00:00:00Z"
    error_message = "not_before_date should pass through."
  }

  assert {
    condition     = azurerm_key_vault_secret.this["dated"].expiration_date == "2027-01-01T00:00:00Z"
    error_message = "expiration_date should pass through."
  }
}

# An invalid secret name is rejected by variable validation.
run "rejects_invalid_secret_name" {
  command = plan

  variables {
    secrets = {
      "not a valid name!" = { generate = true }
    }
  }

  expect_failures = [var.secrets]
}
