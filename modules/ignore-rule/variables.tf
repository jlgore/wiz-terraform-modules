variable "name" {
  description = "Ignore rule name."
  type        = string
}

variable "description" {
  description = "Ignore rule description (required by the API — say why the finding is being ignored)."
  type        = string
}

variable "enabled" {
  description = "Whether the rule is enabled."
  type        = bool
  default     = true
}

variable "finding_ignore_reason" {
  description = <<-EOT
    Why the finding is ignored. One of: OBJECT_DELETED, FINDING_FIXED,
    FALSE_POSITIVE, EXCEPTION, WONT_FIX, BY_DESIGN, RISK_ACCEPTED,
    UNDER_REVIEW, CUSTOM.
  EOT
  type        = string

  validation {
    condition = contains([
      "OBJECT_DELETED", "FINDING_FIXED", "FALSE_POSITIVE", "EXCEPTION",
      "WONT_FIX", "BY_DESIGN", "RISK_ACCEPTED", "UNDER_REVIEW", "CUSTOM",
    ], var.finding_ignore_reason)
    error_message = "finding_ignore_reason must be one of OBJECT_DELETED, FINDING_FIXED, FALSE_POSITIVE, EXCEPTION, WONT_FIX, BY_DESIGN, RISK_ACCEPTED, UNDER_REVIEW, CUSTOM."
  }
}

variable "finding_types" {
  description = <<-EOT
    Finding types this rule applies to. Subset of: ANY, CLOUD_CONFIGURATION,
    HOST_CONFIGURATION, VULNERABILITY, THREAT_DETECTION_ISSUE, DATA_FINDING,
    SECRET_INSTANCE, IMAGE_INTEGRITY, CLOUD_COST_OPPORTUNITY,
    SOFTWARE_SUPPLY_CHAIN, EXCESSIVE_ACCESS, SAST_FINDING,
    ATTACK_SURFACE_FINDING, INVENTORY_FINDING, ACCESS_FINDING.
  EOT
  type        = set(string)
  default     = null

  validation {
    condition = var.finding_types == null ? true : alltrue([
      for t in var.finding_types : contains([
        "ANY", "CLOUD_CONFIGURATION", "HOST_CONFIGURATION", "VULNERABILITY",
        "THREAT_DETECTION_ISSUE", "DATA_FINDING", "SECRET_INSTANCE",
        "IMAGE_INTEGRITY", "CLOUD_COST_OPPORTUNITY", "SOFTWARE_SUPPLY_CHAIN",
        "EXCESSIVE_ACCESS", "SAST_FINDING", "ATTACK_SURFACE_FINDING",
        "INVENTORY_FINDING", "ACCESS_FINDING",
      ], t)
    ])
    error_message = "finding_types contains an unsupported value."
  }
}

variable "project" {
  description = "Optional project ID to scope the rule to (e.g. a project built by account-project-factory)."
  type        = string
  default     = null
}

variable "expired_at" {
  description = "Optional expiry timestamp (RFC 3339, e.g. 2026-12-31T00:00:00Z). Wiz stops honouring the rule after this."
  type        = string
  default     = null
}

variable "vulnerabilities" {
  description = "Optional set of external CVE identifiers this rule targets (e.g. [\"CVE-2025-13836\"])."
  type        = set(string)
  default     = null
}

variable "targets" {
  description = "Optional pipeline stages the rule applies to. Subset of: RUNTIME, DEPLOY, BUILD, CODE."
  type        = set(string)
  default     = null

  validation {
    condition = var.targets == null ? true : alltrue([
      for t in var.targets : contains(["RUNTIME", "DEPLOY", "BUILD", "CODE"], t)
    ])
    error_message = "targets must be a subset of RUNTIME, DEPLOY, BUILD, CODE."
  }
}

# --- Conditions (native HCL — NO jsonencode) ----------------------------------

variable "conditions" {
  description = <<-EOT
    Match conditions as a plain HCL object. Unlike automation-rule filters, the
    provider takes these as native nested attributes — do NOT jsonencode. Keys
    are finding-type buckets: vulnerability_finding, resource, secret_instance,
    cloud_configuration_finding, data_finding, environment, sast_finding, etc.
    See the provider docs for each bucket's shape.

    Example:
      conditions = {
        vulnerability_finding = {
          severity      = ["LOW", "MEDIUM"]
          detailed_name = { contains = ["Python"] }
        }
      }

    Footgun handled for you: non-threat ignore rules require at least TWO
    conditions. If you pass fewer and `pad_conditions` is true (default), the
    module appends a bare match condition so the API accepts the rule.
  EOT
  type        = any
  default     = null
}

variable "pad_conditions" {
  description = <<-EOT
    When true (default), auto-satisfy the API rule that non-threat ignore rules
    need >= 2 conditions by appending a bare `resource = {}` (or `environment =
    {}`) condition when you supply fewer. Set false to pass conditions through
    verbatim.
  EOT
  type        = bool
  default     = true
}

# --- Action preset: downgrade instead of suppress -----------------------------

variable "downgrade_severity_to" {
  description = <<-EOT
    If set, the rule DOWNGRADES matched findings to this severity instead of
    suppressing them (modify_finding_severity_ignore_rule_action). One of:
    INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL. Leave null for a normal ignore.
  EOT
  type        = string
  default     = null

  validation {
    condition = var.downgrade_severity_to == null ? true : contains(
      ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.downgrade_severity_to
    )
    error_message = "downgrade_severity_to must be one of INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

variable "actions_override" {
  description = "Full escape hatch for the `actions` set. When set, used verbatim and `downgrade_severity_to` is ignored."
  type        = any
  default     = null
}

# --- Advanced: scope the rule to specific rule IDs ----------------------------

variable "scoped_rule_ids" {
  description = <<-EOT
    Optional bundle of rule-ID scopes (advanced). Each key maps to the
    correspondingly named provider argument; omit any you don't need.
  EOT
  type = object({
    attack_surface             = optional(set(string))
    cloud_configuration        = optional(set(string))
    cloud_cost_optimization    = optional(set(string))
    data_classification        = optional(set(string))
    host_configuration         = optional(set(string))
    image_integrity_validators = optional(set(string))
    inventory_finding          = optional(set(string))
    sast_finding               = optional(set(string))
    secret_detection           = optional(set(string))
    software_supply_chain      = optional(set(string))
    threat_detection           = optional(set(string))
  })
  default = {}
}

variable "tags" {
  description = "Optional provider-native tag object set, passed through verbatim."
  type        = any
  default     = null
}
