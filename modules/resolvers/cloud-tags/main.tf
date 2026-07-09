# resolvers/cloud-tags
#
# Pure transformer: turns a map of per-account tags into an `owner_map`
# (external_id => [emails]) consumable by account-project-factory.
#
# It intentionally does NOT read from any cloud provider itself — you wire the
# discovery data blocks (aws_organizations_*, azurerm_subscription, etc.) in
# your root module and pass their tags in via `account_tags`. This keeps the
# resolver provider-agnostic and testable. See examples/champions-from-tags.

variable "account_tags" {
  description = "Map of account external_id => { tag_key = tag_value }."
  type        = map(map(string))
}

variable "owner_tag_keys" {
  description = <<-EOT
    Ordered list of tag keys to check for an owner email. First match wins per
    account. Comparison is case-insensitive on the key.
  EOT
  type        = list(string)
  default     = ["SecurityChampion", "Owner", "owner", "TechnicalOwner"]
}

variable "email_token_regex" {
  description = "RE2 pattern matching a single email token; used to split multi-owner tag values."
  type        = string
  default     = "[^\\s,;]+"
}

variable "email_domain_allowlist" {
  description = "If non-empty, only emails whose domain is in this list are kept."
  type        = list(string)
  default     = []
}

locals {
  lower_keys = [for k in var.owner_tag_keys : lower(k)]

  # Case-insensitive view of each account's tags.
  lc_tags = {
    for ext_id, tags in var.account_tags :
    ext_id => { for k, v in tags : lower(k) => v }
  }

  # First owner tag value, honoring owner_tag_keys preference order.
  raw_owner_value = {
    for ext_id, tags in local.lc_tags :
    ext_id => try(
      [for k in local.lower_keys : tags[k] if contains(keys(tags), k) && trimspace(tags[k]) != ""][0],
      null,
    )
  }

  # Split, trim, lower, de-dupe emails per account.
  split_emails = {
    for ext_id, val in local.raw_owner_value :
    ext_id => distinct([
      for e in regexall(var.email_token_regex, val) :
      lower(trimspace(e)) if trimspace(e) != ""
    ])
    if val != null
  }

  owner_map = {
    for ext_id, emails in local.split_emails :
    ext_id => (
      length(var.email_domain_allowlist) == 0
      ? emails
      : [for e in emails : e if contains(var.email_domain_allowlist, element(split("@", e), length(split("@", e)) - 1))]
    )
  }
}

output "owner_map" {
  description = "external_id => [owner emails]. Feed directly into account-project-factory.owner_map."
  value       = { for k, v in local.owner_map : k => v if length(v) > 0 }
}

output "accounts_without_owner_tag" {
  description = "external_ids present in account_tags but with no matching/valid owner tag."
  value       = [for k in keys(var.account_tags) : k if !contains(keys(local.owner_map), k) || length(local.owner_map[k]) == 0]
}
