# account-project-factory

Turns a set of discovered cloud accounts into one Wiz **project each**, with the
account's owner emails wired in as **security champions** (and, optionally,
project owners). This is the core of the "projects build themselves from cloud
data" pattern.

```
cloud accounts  ──►  for_each  ──►  wiz-v2_project {
   (+ owner_map)                       security_champions = [owner@…]
                                       cloud_account_links = [{ id, env }]
                                       risk_profile        = <preset|override>
                                    }
```

## Usage

```hcl
module "projects" {
  source = "../../modules/account-project-factory"

  # Feed straight from the cloud_accounts data source.
  accounts = {
    for a in data.wiz-v2_cloud_accounts.this.cloud_accounts :
    a.external_id => {
      cloud_account_id = a.id
      external_id      = a.external_id
      name             = a.name
      environment      = "PRODUCTION"
    }
  }

  # external_id => [emails], from a resolver module (wiz-graph / cloud-tags).
  owner_map = module.owners.owner_map

  risk_profile_preset = "internal"
}
```

## Inputs (highlights)

| Input | Purpose |
|-------|---------|
| `accounts` | Map (keyed by your slug) of accounts to build projects for. `cloud_account_id` is the internal Wiz ID used for the link; `external_id` is the owner-map join key. |
| `owner_map` | `external_id => [emails]`. Per-account `owner_emails` overrides it. |
| `champions_from_owners` | Set `security_champions` from owners (default `true`). |
| `owners_as_project_owners` | Also set `project_owners` (default `true`). |
| `risk_profile_preset` | `regulated` \| `customer_facing` \| `internal` \| `none`. |
| `risk_profile_override` | Full risk-profile object — bypasses the preset (escape hatch). |
| `name_template` | Project name; tokens `${name}`, `${external_id}`, `${env}`. |
| `parent_project`, `business_unit` | Applied to every created project. |

## Risk profile presets

| Preset | Shape |
|--------|-------|
| `regulated` | HBI, customer-facing, internet-facing, regulated, stores data |
| `customer_facing` | HBI, customer-facing, internet-facing |
| `internal` | MBI, not customer/internet-facing |
| `none` | no risk-profile block |

Need something bespoke? Set `risk_profile_override` and the preset is ignored.

## Outputs

| Output | Purpose |
|--------|---------|
| `projects` | Full per-account project detail (id, name, champions, owners). |
| `project_ids` | `slug => project id` — handy for scoping automation rules. |
| `resolved_owners` | `slug => [emails]` actually applied. |
| `accounts_without_owners` | Accounts that resolved to **no** owner — surface these; they got no champion. |
