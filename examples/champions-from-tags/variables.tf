# --- Discovery ----------------------------------------------------------------

variable "cloud_providers" {
  description = "Cloud providers to discover accounts for (e.g. [\"Azure\"], [\"AWS\"])."
  type        = list(string)
  default     = ["Azure"]
}

variable "account_search" {
  description = "Optional free-text search to narrow discovered accounts (name/tag/external-id)."
  type        = list(string)
  default     = []
}

variable "only_unassigned" {
  description = "If true, only build projects for accounts not already assigned to a project."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment to record on each project's cloud_account_link."
  type        = string
  default     = "PRODUCTION"
}

# --- Owner resolution (the customizable bit) ----------------------------------

variable "entity_types" {
  description = "Wiz graph entity types that carry the owner tag."
  type        = list(string)
  default     = ["SUBSCRIPTION"]
}

variable "owner_tag_keys" {
  description = "Ordered tag keys to read the owner email from. SET THIS to your convention (e.g. [\"team_owner\"])."
  type        = list(string)
  default     = ["owner", "Owner", "SecurityChampion"]
}

variable "email_domain_allowlist" {
  description = "If set, only owner emails in these domains become champions (e.g. [\"example.com\"])."
  type        = list(string)
  default     = []
}

# --- Project shaping ----------------------------------------------------------

variable "project_name_template" {
  description = "Project name template. Tokens: $${name}, $${external_id}, $${env}."
  type        = string
  default     = "$${name}"
}

variable "risk_profile_preset" {
  description = "Risk profile preset: regulated | customer_facing | internal | none."
  type        = string
  default     = "internal"
}

variable "owners_as_project_owners" {
  description = "Also set project_owners (not just security_champions) to the owner emails."
  type        = bool
  default     = true
}

variable "business_unit" {
  description = "Business unit applied to every created project."
  type        = string
  default     = null
}
