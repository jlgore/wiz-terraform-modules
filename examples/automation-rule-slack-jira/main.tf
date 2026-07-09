# Example: on new CRITICAL issues in a project, notify Slack and open a Jira ticket.
#
# Demonstrates the automation-rule module hiding the jsonencode() footgun on
# `filters` and driving two integrations from clean typed presets.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    wiz-v2 = {
      # Preview provider — set to the registry source you pull it from.
      source  = "wizsec/wiz-v2"
      version = ">= 0.1" # preview; adjust to the provider version you use
    }
  }
}

provider "wiz-v2" {}

variable "project_id" {
  description = "Project the rule is scoped to."
  type        = string
}

variable "slack_integration_id" {
  description = "ID of the Slack integration the alert action uses."
  type        = string
}

variable "jira_integration_id" {
  description = "ID of the Jira integration the ticket action uses."
  type        = string
}

variable "jira_project_key" {
  description = "Jira project key new tickets are created in (e.g. SEC)."
  type        = string
  default     = "SEC"
}

module "critical_issue_rule" {
  source = "../../modules/automation-rule"

  name           = "Critical issues → Slack + Jira"
  description    = "Notify Slack and open a Jira ticket when a critical issue is created."
  project        = var.project_id
  trigger_source = "ISSUES"
  trigger_type   = ["CREATED"]

  # Plain HCL object — module jsonencode()s it into the provider's `filters`.
  filters = {
    severity = ["CRITICAL"]
  }

  actions = [
    {
      integration = var.slack_integration_id
      slack       = { note = "New critical issue in this project" }
    },
    {
      integration = var.jira_integration_id
      jira_create = {
        project     = var.jira_project_key
        issue_type  = "Bug"
        summary     = "Wiz: {{issue.name}}"
        description = "{{issue.description}}\n\nSeverity: {{issue.severity}}"
      }
    },
  ]
}

output "rule_id" {
  value = module.critical_issue_rule.id
}
