# resolvers/wiz-graph

Derives owner emails from the **Wiz Security Graph** and reduces them to an
`owner_map` (`external_id => [emails]`) for
[`account-project-factory`](../../account-project-factory). Single-provider —
Wiz already ingested your cloud tags, so no AWS/Azure credentials are needed.

## How it works

By default the module builds a `graphSearch` query for the entity types you
name (default `["SUBSCRIPTION"]`), optionally filtered to a set of
`external_ids`, runs it through `wiz-v2_graphql_query`, and reads the owner email
from a tag on each entity. **You pick the tag key(s)** — there is no universal
default (`owner_tag_keys`).

Result envelope (subscription):

```jsonc
[ { "entities": [ {
    "type": "SUBSCRIPTION",
    "properties": {
      "externalId": "<subscription-id>",
      "tags": { "<your_owner_tag>": "owner@example.com" }
    }
} ] } ]
```

## Usage

```hcl
module "owners" {
  source         = "../../modules/resolvers/wiz-graph"
  owner_tag_keys = ["team_owner"]                  # your org's owner tag
  external_ids   = ["<sub-a>", "<sub-b>"]          # optional; omit to scan all subs
}

# module.owners.owner_map => { "<sub-a>" = ["owner@example.com"] }
```

## Escape hatches (opinionated defaults, but never boxed in)

| Need | Input |
|------|-------|
| Query a different entity type | `entity_types` |
| Read a different id/tag location | `external_id_property_keys`, `tags_property_key` |
| Run a completely custom query | `graphql_query` + `query_variables` |
| Skip Wiz entirely | `owner_records = [{ external_id, email }]` |
| Restrict to corporate domains | `email_domain_allowlist` |
| Split multi-owner tag values | `email_token_regex` |

## Outputs

- `owner_map` — `external_id => [emails]`
- `accounts_without_owner` — external_ids with no usable owner tag (surface these)
- `decoded_result` — raw decoded graph result, for debugging/query tuning
