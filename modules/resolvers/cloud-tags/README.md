# resolvers/cloud-tags

Turns per-account cloud tags into an `owner_map` (`external_id => [emails]`) for
[`account-project-factory`](../../account-project-factory). Use this when the
owner tag is easiest to read from the **cloud provider** (AWS Organizations,
Azure subscriptions) rather than the Wiz graph.

It is a **pure transformer** — it reads no cloud provider itself. You wire the
discovery data blocks in your root module and pass their tags in via
`account_tags`, which keeps this module provider-agnostic and unit-testable.

> Prefer a single-provider setup? Use [`../wiz-graph`](../wiz-graph) instead —
> it reads the owner tag straight from the Wiz Security Graph.

## Usage

```hcl
# You gather tags however you like — e.g. Azure subscriptions:
locals {
  account_tags = {
    for s in data.azurerm_subscriptions.all.subscriptions :
    s.subscription_id => s.tags
  }
}

module "owners" {
  source         = "../../modules/resolvers/cloud-tags"
  account_tags   = local.account_tags
  owner_tag_keys = ["team_owner", "Owner"] # first match wins, case-insensitive
}

# module.owners.owner_map => { "<sub-id>" = ["owner@example.com"] }
```

## Inputs

| Input | Purpose |
|-------|---------|
| `account_tags` | `external_id => { tag_key = tag_value }`. |
| `owner_tag_keys` | Ordered keys to check; first non-empty match wins (case-insensitive). |
| `email_token_regex` | RE2 token pattern to split multi-owner values (default splits on space/comma/semicolon). |
| `email_domain_allowlist` | If set, keep only emails in these domains. |

## Outputs

| Output | Purpose |
|--------|---------|
| `owner_map` | `external_id => [emails]`. Feed into `account-project-factory.owner_map`. |
| `accounts_without_owner_tag` | Accounts with no usable owner tag — surface these. |
