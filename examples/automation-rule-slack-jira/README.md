# Example: automation-rule-slack-jira

On new **CRITICAL** issues in a project, notify Slack and open a Jira ticket —
using the [`automation-rule`](../../modules/automation-rule) module's typed
presets (no hand-written `jsonencode` for `filters`).

## Run

```bash
terraform init
terraform apply \
  -var 'project_id=<project-id>' \
  -var 'slack_integration_id=<slack-integration-id>' \
  -var 'jira_integration_id=<jira-integration-id>'
```

Pair it with [`champions-from-tags`](../champions-from-tags): scope the rule to a
project that factory built, and the alert reaches the account's owner.

## Variables

| Variable | Purpose |
|----------|---------|
| `project_id` | Project the rule is scoped to. |
| `slack_integration_id` | Slack integration the alert uses. |
| `jira_integration_id` | Jira integration the ticket uses. |
| `jira_project_key` | Jira project new tickets land in (default `SEC`). |
