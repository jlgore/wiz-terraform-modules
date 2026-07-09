# automation-rule
#
# Opinionated wrapper over `wiz-v2_automation_rule`. It hides two footguns:
#   1. `filters` must be a JSON string — pass a plain HCL object, we jsonencode.
#   2. ServiceNow `custom_fields` is ALSO a nested JSON string — same treatment.
# And it collapses the provider's ~50 action_template_params shapes into a
# handful of typed presets, with `raw_actions` as the escape hatch.

locals {
  # Build a uniform action object per spec. Every param sub-block key is present
  # on every element (null when unused) so the Set unifies to one object type.
  built_actions = [
    for a in var.actions : {
      action_template_type = (
        a.webhook != null ? "WEBHOOK" :
        a.email != null ? "EMAIL" :
        a.slack != null ? "SLACK" :
        a.google_chat != null ? "GOOGLE_CHAT" :
        a.aws_sns != null ? "AWS_SNS" :
        a.jira_create != null ? "JIRA_CREATE_TICKET" :
        "SERVICE_NOW_CREATE_TICKET"
      )
      integration = a.integration

      action_template_params = {
        webhook_action_template_params = a.webhook == null ? null : {
          body    = a.webhook.body
          headers = [for k, v in coalesce(a.webhook.headers, {}) : { key = k, value = v }]
        }

        email_action_template_params = a.email == null ? null : {
          to                  = a.email.to
          cc                  = a.email.cc
          subject             = a.email.subject
          note                = a.email.note
          attach_evidence_csv = a.email.attach_evidence_csv
        }

        slack_action_template_params = a.slack == null ? null : {
          note = a.slack.note
        }

        google_chat_action_template_params = a.google_chat == null ? null : {
          note = a.google_chat.note
        }

        aws_sns_action_template_params = a.aws_sns == null ? null : {
          body            = a.aws_sns.body
          attach_evidence = a.aws_sns.attach_evidence
        }

        jira_action_create_ticket_template_params = a.jira_create == null ? null : {
          fields = {
            project     = a.jira_create.project
            issue_type  = a.jira_create.issue_type
            summary     = a.jira_create.summary
            description = a.jira_create.description
          }
        }

        service_now_action_create_ticket_template_params = a.servicenow_create == null ? null : {
          fields = {
            table_name    = a.servicenow_create.table_name
            summary       = a.servicenow_create.summary
            description   = a.servicenow_create.description
            custom_fields = a.servicenow_create.custom_fields == null ? null : jsonencode(a.servicenow_create.custom_fields)
          }
        }
      }
    }
  ]

  effective_actions = var.raw_actions != null ? var.raw_actions : local.built_actions

  effective_filters = var.filters_json != null ? var.filters_json : (
    var.filters != null ? jsonencode(var.filters) : null
  )
}

resource "wiz-v2_automation_rule" "this" {
  name        = var.name
  description = var.description
  enabled     = var.enabled
  project     = var.project

  trigger_source = var.trigger_source
  trigger_type   = var.trigger_type

  filters = local.effective_filters
  actions = local.effective_actions

  trigger_parameters = var.trigger_parameters
  auto_remediation   = var.auto_remediation
}
