# Wiz Terraform Modules

Opinionated, composable Terraform modules for the **Wiz v2 provider** — built to
smooth the platform's sharpest edges so you can express intent, not boilerplate.

> **Provider status:** the Wiz v2 provider is in **preview** (local name
> `wiz-v2`, to be renamed `wizsec` on release). These modules pin the provider
> `source` to a neutral placeholder (`wizsec/wiz-v2`); set it to whatever
> registry you pull the provider from, and keep it identical across the root
> config and every module.

## The idea

The provider faithfully exposes Wiz's API — which means it also exposes its rough
spots: fields that must be hand-`jsonencode()`d, an action type with ~50
differently-shaped parameter blocks, and a lot of ceremony to stand up projects.
These modules encode the *correct* patterns once, so callers can't hold them
wrong. Every module ships **opinionated presets with a full escape hatch** — easy
by default, never boxed in.

The flagship pattern: **your project graph builds itself from cloud data.**

```
 wiz-v2_cloud_accounts        resolvers/wiz-graph  (or cloud-tags)
   discover subscriptions  ──►  read owner tag off each account
            │                            │
            │                     owner_map: external_id => [emails]
            ▼                            ▼
        account-project-factory  ──►  one wiz-v2_project per account
            │                          security_champions = [owner@…]
            ▼
        automation-rule  ──►  ticket / alert on that project's issues
```

## Modules

| Module | What it does |
|--------|--------------|
| [`account-project-factory`](modules/account-project-factory) | One Wiz project per cloud account, owner emails wired in as **security champions**; risk-profile presets. |
| [`resolvers/wiz-graph`](modules/resolvers/wiz-graph) | Derives `owner_map` from the **Wiz Security Graph** (`graphql_query`). Single-provider — no cloud creds. |
| [`resolvers/cloud-tags`](modules/resolvers/cloud-tags) | Derives `owner_map` from **cloud provider tags** (AWS/Azure data blocks). Pure transformer. |
| [`automation-rule`](modules/automation-rule) | Wraps `wiz-v2_automation_rule`; typed presets for Slack/Jira/ServiceNow/webhook/email/SNS/Google Chat, hides the `jsonencode` footguns. |

The two `resolvers/*` modules are interchangeable — both output the same
`owner_map` contract, so you can swap owner-derivation strategy without touching
the factory.

## Quickstart

```hcl
# 1. Discover
data "wiz-v2_cloud_accounts" "azure" {
  cloud_provider = ["Azure"]
}

# 2. Resolve owners from the Wiz graph
module "owners" {
  source         = "./modules/resolvers/wiz-graph"
  owner_tag_keys = ["team_owner"]        # your org's owner tag
  external_ids   = [for a in data.wiz-v2_cloud_accounts.azure.cloud_accounts : a.external_id]
}

# 3. Build a project per account, owners as champions
module "projects" {
  source = "./modules/account-project-factory"
  accounts = {
    for a in data.wiz-v2_cloud_accounts.azure.cloud_accounts :
    a.external_id => {
      cloud_account_id = a.id
      external_id      = a.external_id
      name             = a.name
      environment      = "PRODUCTION"
    }
  }
  owner_map           = module.owners.owner_map
  risk_profile_preset = "internal"
}
```

## Examples

| Example | Shows |
|---------|-------|
| [`champions-from-tags`](examples/champions-from-tags) | End-to-end, fully variable-driven: discover → resolve owners → projects with champions. |
| [`automation-rule-slack-jira`](examples/automation-rule-slack-jira) | Notify Slack + open a Jira ticket on new critical issues. |
| [`probe-owner-query`](examples/probe-owner-query) | Inspect the raw `graphql_query` result envelope when tuning `wiz-graph`. |

## Design principles

- **Presets + escape hatch.** Named presets for the common case; a raw
  passthrough (`*_override`, `raw_actions`, `filters_json`) for everything else.
- **Hide the footguns.** `jsonencode()` for `filters` and ServiceNow
  `custom_fields`, action-shape selection, and edge-wiring are the module's job,
  not yours.
- **Surface the gaps.** Modules output what *didn't* resolve
  (`accounts_without_owners`) so silent misses become visible.
- **One contract, swappable parts.** Resolvers share the `owner_map` shape.

## Provider setup

Configure the `wiz-v2` provider per the
[Wiz Terraform provider docs](https://docs.wiz.io/docs/wiz-terraform-provider-v2)
(a service account with the relevant `read:*` permissions). Nothing
tenant-specific is committed here — you supply the registry source and
credentials.

## Safety

`terraform` state and plans can contain real account IDs, emails, and tags. The
[`.gitignore`](.gitignore) blocks `*.tfstate*`, `.terraform/`, and `*.tfvars`
(the tracked template is `*.tfvars.example`). Never commit state.

## License

[MIT](LICENSE).
