# automation-rule

An opinionated wrapper over `wiz-v2_automation_rule` that removes the two things
people get wrong, and collapses the provider's ~50 action shapes into a handful
of typed presets.

## Why

The raw resource has sharp edges:

- **`filters` is a JSON string** — you must `jsonencode()` it by hand.
- **ServiceNow `custom_fields` is *also* a nested JSON string** — a second,
  easy-to-miss `jsonencode()`.
- **Actions** are a set where each element carries exactly one of ~50
  differently-shaped `*_action_template_params` blocks.

This module hides all three: pass `filters` as a plain object, pass
`custom_fields` as a plain map, and pick a preset per action.

## Usage — notify Slack and open a Jira ticket on new critical issues

```hcl
module "critical_issue_rule" {
  source = "../../modules/automation-rule"

  name           = "Critical issues → Slack + Jira"
  project        = module.projects.project_ids["<account-slug>"] # scope to a project
  trigger_source = "ISSUES"
  trigger_type   = ["CREATED"]

  # Plain HCL — the module jsonencode()s it into `filters`.
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
        project     = "SEC"
        issue_type  = "Bug"
        summary     = "Wiz: {{issue.name}}"
        description = "{{issue.description}}"
      }
    },
  ]
}
```

## Presets

| Preset key | Action type | Key fields |
|------------|-------------|------------|
| `webhook` | `WEBHOOK` | `body`, `headers` (map) |
| `email` | `EMAIL` | `to`, `cc`, `subject`, `note`, `attach_evidence_csv` |
| `slack` | `SLACK` | `note` (destination comes from the integration) |
| `google_chat` | `GOOGLE_CHAT` | `note` |
| `aws_sns` | `AWS_SNS` | `body`, `attach_evidence` |
| `jira_create` | `JIRA_CREATE_TICKET` | `project`, `issue_type`, `summary`, `description` |
| `servicenow_create` | `SERVICE_NOW_CREATE_TICKET` | `table_name`, `summary`, `description`, `custom_fields` (map → auto-encoded) |

Set **exactly one** preset per action (validated). `integration` is the ID of
the integration the action drives.

## Escape hatches

| Need | Input |
|------|-------|
| Filters already encoded | `filters_json` (raw string) |
| An integration not in the presets | `raw_actions` (verbatim provider `actions` value) |
| Trigger params / auto-remediation | `trigger_parameters`, `auto_remediation` (passthrough) |

## Outputs

- `id` — the created rule's ID
- `name` — the created rule's name
