# check blocks run after every plan and apply and warn (without blocking) on configuration that would
# quietly misbehave.

# not_before_date must precede expiration_date. RFC3339 UTC timestamps sort correctly as strings.
check "dates_are_ordered" {
  assert {
    condition = alltrue([
      for s in values(var.secrets) :
      (s.not_before_date == null || s.expiration_date == null) ? true : s.not_before_date < s.expiration_date
    ])
    error_message = "One or more secrets have not_before_date on or after expiration_date."
  }
}

# A rotate needs a version bump: warn when the same version is likely being reused after a value change
# cannot be flagged. This is informational, reminding callers that value_wo changes need a version bump.
check "generated_secrets_have_length" {
  assert {
    condition     = alltrue([for s in values(var.secrets) : !s.generate || s.length >= 16])
    error_message = "A generated secret has length < 16; consider a longer length for a stronger secret."
  }
}
