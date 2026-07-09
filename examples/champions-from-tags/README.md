# Example: champions-from-tags

End-to-end, single-provider (Wiz only): discover cloud accounts, read the owner
tag off each subscription in the Wiz Security Graph, and build one project per
account with the owner email set as **security champion**.

Everything is variable-driven — retarget it to your tenant, tag convention, and
project conventions without editing `main.tf`.

## Run

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit
# set the provider `source` + credentials per the Wiz provider docs
terraform init
terraform apply
```

## Key variables

| Variable | Purpose |
|----------|---------|
| `cloud_providers` | Which providers to discover accounts for (e.g. `["Azure"]`). |
| `owner_tag_keys` | **The tag your org stamps owner emails with.** Without it, nobody becomes a champion. |
| `email_domain_allowlist` | Restrict champions to corporate domains. |
| `risk_profile_preset` | `regulated` \| `customer_facing` \| `internal` \| `none`. |
| `project_name_template` | Tokens `${name}`, `${external_id}`, `${env}`. |

## Outputs

- `projects` — `slug => project id`
- `resolved_owners` — who became a champion where
- `accounts_missing_owner_tag` — discovered accounts with no owner tag (got no champion)
