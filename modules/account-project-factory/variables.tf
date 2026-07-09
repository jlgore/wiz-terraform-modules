variable "accounts" {
  description = <<-EOT
    Cloud accounts to build projects for, keyed by a stable slug you choose
    (used as the Terraform resource key, so keep it deterministic).

    Feed this directly from the `wiz-v2_cloud_accounts` data source, e.g.:

      accounts = {
        for a in data.wiz-v2_cloud_accounts.this.cloud_accounts :
        a.external_id => {
          cloud_account_id = a.id            # Wiz internal ID for the link
          external_id      = a.external_id   # subscription/account ID (join key)
          name             = a.name
          environment      = "PRODUCTION"
        }
      }
  EOT
  type = map(object({
    cloud_account_id = string
    external_id      = string
    name             = optional(string)
    environment      = optional(string, "PRODUCTION")
    # Per-account escape hatch: override the derived owners for this one account.
    owner_emails = optional(list(string))
  }))

  validation {
    condition = alltrue([
      for a in values(var.accounts) :
      contains(["PRODUCTION", "STAGING", "DEVELOPMENT", "TESTING", "OTHER"], a.environment)
    ])
    error_message = "environment must be one of PRODUCTION, STAGING, DEVELOPMENT, TESTING, OTHER."
  }
}

variable "owner_map" {
  description = <<-EOT
    Resolved owners keyed by account `external_id` => list of emails.
    Produce this with one of the resolver modules (resolvers/cloud-tags or
    resolvers/wiz-graph), or hand-roll it. Per-account `owner_emails` on
    `accounts` overrides this map for that account.
  EOT
  type        = map(list(string))
  default     = {}
}

variable "champions_from_owners" {
  description = "Set each project's security_champions to its resolved owner emails."
  type        = bool
  default     = true
}

variable "owners_as_project_owners" {
  description = "Also set project_owners to the resolved owner emails."
  type        = bool
  default     = true
}

variable "name_template" {
  description = "Project name template. Available tokens: $${name}, $${external_id}, $${env}."
  type        = string
  default     = "$${name}"
}

variable "parent_project" {
  description = "Optional parent project (folder) ID to nest all created projects under."
  type        = string
  default     = null
}

variable "business_unit" {
  description = "Business unit applied to every created project."
  type        = string
  default     = null
}

# --- Risk profile: opinionated presets + full escape hatch --------------------

variable "risk_profile_preset" {
  description = <<-EOT
    Named risk-profile preset applied to every project. One of:
      - "regulated"       HBI, customer-facing, regulated, stores data
      - "customer_facing" HBI, customer/internet-facing
      - "internal"        MBI, internal, not customer-facing
      - "none"            no risk profile block
    Ignored when `risk_profile_override` is set.
  EOT
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["regulated", "customer_facing", "internal", "none"], var.risk_profile_preset)
    error_message = "risk_profile_preset must be one of: regulated, customer_facing, internal, none."
  }
}

variable "risk_profile_override" {
  description = "Full risk_profile object. When set, bypasses the preset entirely (escape hatch)."
  type = object({
    business_impact       = optional(string)
    has_authentication    = optional(string)
    has_exposed_api       = optional(string)
    is_actively_developed = optional(string)
    is_customer_facing    = optional(string)
    is_internet_facing    = optional(string)
    is_regulated          = optional(string)
    regulatory_standards  = optional(list(string))
    sensitive_data_types  = optional(list(string))
    stores_data           = optional(string)
  })
  default = null
}
