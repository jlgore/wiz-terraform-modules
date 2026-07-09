variable "name" {
  description = "Automation rule name."
  type        = string
}

variable "description" {
  description = "Automation rule description."
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether the rule is enabled."
  type        = bool
  default     = true
}

variable "project" {
  description = "Project ID this rule is scoped to (e.g. a project built by account-project-factory)."
  type        = string
  default     = null
}

# --- Trigger ------------------------------------------------------------------

variable "trigger_source" {
  description = <<-EOT
    What fires the rule. One of: ISSUES, CLOUD_EVENTS, CONTROL,
    CONFIGURATION_FINDING, AUDIT_LOGS, SYSTEM_HEALTH_ISSUES, CI_CD_SCANS,
    DATA_FINDINGS, SYSTEM_ACTIVITIES, ADMISSION_REVIEWS, DETECTIONS,
    CLOUD_COST_OPPORTUNITIES, SERVICE_ISSUES, POSTURE_ISSUES, RUNTIME_EVENTS,
    THREATS, POLICY_UPDATES, CLOUD_COST_MONITOR_FINDINGS, ACCESS_FINDINGS,
    INVENTORY_FINDINGS.
  EOT
  type        = string
  default     = "ISSUES"
}

variable "trigger_type" {
  description = "When it fires: subset of CREATED, UPDATED, RESOLVED, REOPENED, DETECTED, DUE, STATUS_CHANGED, ANALYZED."
  type        = set(string)
  default     = ["CREATED"]
}

variable "trigger_parameters" {
  description = "Optional trigger parameters passthrough (provider-typed object)."
  type        = any
  default     = null
}

# --- Filters (jsonencode hidden) ----------------------------------------------

variable "filters" {
  description = <<-EOT
    Filters as a plain HCL object — the module `jsonencode()`s it for you (the
    provider's `filters` field is a JSON string; this removes that footgun).
    The exact shape depends on `trigger_source`. Mutually exclusive with
    `filters_json`.
  EOT
  type        = any
  default     = null
}

variable "filters_json" {
  description = "Pre-encoded filters JSON string. Escape hatch; overrides `filters` when set."
  type        = string
  default     = null
}

# --- Actions ------------------------------------------------------------------

variable "actions" {
  description = <<-EOT
    Actions to run when the rule fires. Set exactly ONE preset block per action.
    `integration` is the integration ID the action uses (required for all
    presets below). Supported presets: webhook, email, slack, google_chat,
    aws_sns, jira_create, servicenow_create. For anything else, use `raw_actions`.
  EOT
  type = list(object({
    integration = optional(string)

    webhook = optional(object({
      body    = string
      headers = optional(map(string), {})
    }))

    email = optional(object({
      to                  = optional(set(string))
      cc                  = optional(set(string))
      subject             = optional(string)
      note                = optional(string)
      attach_evidence_csv = optional(bool)
    }))

    slack = optional(object({
      note = optional(string)
    }))

    google_chat = optional(object({
      note = optional(string)
    }))

    aws_sns = optional(object({
      body            = string
      attach_evidence = optional(bool)
    }))

    jira_create = optional(object({
      project     = string
      issue_type  = string
      summary     = string
      description = string
    }))

    servicenow_create = optional(object({
      table_name  = string
      summary     = string
      description = string
      # Provided as a plain HCL map; module jsonencode()s it into custom_fields.
      custom_fields = optional(map(string))
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for a in var.actions : (
        (a.webhook != null ? 1 : 0) +
        (a.email != null ? 1 : 0) +
        (a.slack != null ? 1 : 0) +
        (a.google_chat != null ? 1 : 0) +
        (a.aws_sns != null ? 1 : 0) +
        (a.jira_create != null ? 1 : 0) +
        (a.servicenow_create != null ? 1 : 0)
      ) == 1
    ])
    error_message = "Each action must set exactly one preset block (webhook/email/slack/google_chat/aws_sns/jira_create/servicenow_create)."
  }
}

variable "raw_actions" {
  description = <<-EOT
    Full escape hatch. When set, this value is used as the resource's `actions`
    verbatim and the `actions` preset list is ignored — use for integrations the
    presets don't cover. Must match the provider's action object shape.
  EOT
  type        = any
  default     = null
}

variable "auto_remediation" {
  description = "Optional auto_remediation passthrough (provider-typed object)."
  type        = any
  default     = null
}
