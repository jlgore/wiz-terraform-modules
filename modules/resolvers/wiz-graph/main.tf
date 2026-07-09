# resolvers/wiz-graph
#
# Derives owner emails from the Wiz Security Graph via `wiz-v2_graphql_query`,
# reducing them to an `owner_map` (external_id => [emails]) for
# account-project-factory. Single-provider: Wiz already ingested the cloud tags,
# so we ask Wiz for them — no AWS/Azure credentials required.
#
# Opinionated defaults + escape hatches:
#   * By default the module BUILDS a `graphSearch` query from `entity_types` +
#     `external_ids`. You only pick the owner tag key(s).
#   * Override `graphql_query`/`query_variables` to run any query you want.
#   * Or bypass Wiz entirely with a pre-built `owner_records` list.
#
# Result envelope (subscription example):
#   jsondecode(result) = [ { entities = [ {
#       properties = {
#         externalId = "<subscription-id>", subscriptionExternalId = "<subscription-id>",
#         tags = { <your_owner_tag> = "owner@example.com", ... }
#       } } ] } ]

# --- What to read -------------------------------------------------------------

variable "owner_tag_keys" {
  description = <<-EOT
    Ordered list of tag keys that may hold an owner email. First non-empty match
    wins per entity; comparison is case-insensitive. THERE IS NO UNIVERSAL
    DEFAULT — set this to your org's convention (e.g. ["team_owner"]).
  EOT
  type        = list(string)
  default     = ["owner", "Owner", "SecurityChampion", "security_champion", "TechnicalOwner"]
}

variable "external_id_property_keys" {
  description = "Ordered entity.properties keys to read the account external ID from."
  type        = list(string)
  default     = ["externalId", "subscriptionExternalId"]
}

variable "tags_property_key" {
  description = "The entity.properties key under which the tag map lives."
  type        = string
  default     = "tags"
}

# --- Built-in query knobs (used unless graphql_query is overridden) -----------

variable "entity_types" {
  description = "Wiz graph entity types to query (GraphEntityQueryInput.type)."
  type        = list(string)
  default     = ["SUBSCRIPTION"]
}

variable "external_ids" {
  description = "Optional external-id allowlist for the built query. Empty = all entities of the given type."
  type        = list(string)
  default     = []
}

variable "page_size" {
  description = "graphSearch `first` page size."
  type        = number
  default     = 500
}

# --- Escape hatches -----------------------------------------------------------

variable "graphql_query" {
  description = "Raw GraphQL query string. Overrides the built-in graphSearch query when set."
  type        = string
  default     = ""
}

variable "query_variables" {
  description = "Raw GraphQL variables JSON string. Overrides the built variables when set."
  type        = string
  default     = ""
}

variable "owner_records" {
  description = "Ultimate escape hatch: pre-built [{external_id, email}]. When set, no query runs."
  type = list(object({
    external_id = string
    email       = string
  }))
  default = null
}

# --- Normalization knobs ------------------------------------------------------

variable "email_token_regex" {
  description = "RE2 pattern matching a single email token; used to split multi-owner tag values."
  type        = string
  default     = "[^\\s,;]+"
}

variable "email_domain_allowlist" {
  description = "If non-empty, only emails whose domain is in this list are kept."
  type        = list(string)
  default     = []
}

# --- Query construction -------------------------------------------------------

locals {
  default_query = <<-GQL
    query GraphSearch($query: GraphEntityQueryInput, $first: Int, $after: String) {
      graphSearch(query: $query, first: $first, quick: false, after: $after) {
        nodes { entities { id name type properties } }
        pageInfo { hasNextPage endCursor }
      }
    }
  GQL

  built_query_obj = merge(
    { type = var.entity_types, select = true },
    length(var.external_ids) > 0 ? { where = { externalId = { EQUALS = var.external_ids } } } : {},
  )

  effective_query = trimspace(var.graphql_query) != "" ? var.graphql_query : local.default_query
  effective_vars  = trimspace(var.query_variables) != "" ? var.query_variables : jsonencode({ query = local.built_query_obj, first = var.page_size })
}

data "wiz-v2_graphql_query" "owners" {
  count           = var.owner_records == null ? 1 : 0
  query           = local.effective_query
  query_variables = local.effective_vars
}

# --- Parsing ------------------------------------------------------------------

locals {
  decoded = length(data.wiz-v2_graphql_query.owners) > 0 ? jsondecode(data.wiz-v2_graphql_query.owners[0].result) : null

  # The result is a list of nodes; each node has an `entities` list. Some
  # envelopes wrap nodes under data.graphSearch.nodes — handle both.
  raw_nodes = local.decoded == null ? [] : try(local.decoded.data.graphSearch.nodes, local.decoded)
  entities  = flatten([for node in local.raw_nodes : try(node.entities, [])])

  lower_owner_keys = [for k in var.owner_tag_keys : lower(k)]

  # Normalize each entity to { external_id, tags(lowercased) }.
  norm = [
    for e in local.entities : {
      external_id = try(coalesce([for k in var.external_id_property_keys : try(tostring(e.properties[k]), null)]...), null)
      tags        = { for k, v in try(e.properties[var.tags_property_key], {}) : lower(k) => tostring(v) }
    }
  ]

  parsed_records = [
    for n in local.norm : {
      external_id = n.external_id
      email       = try([for k in local.lower_owner_keys : n.tags[k] if contains(keys(n.tags), k) && trimspace(n.tags[k]) != ""][0], null)
    }
    if n.external_id != null
  ]

  # Records to reduce: explicit escape hatch wins, else parsed query output.
  records = [
    for r in coalesce(var.owner_records, local.parsed_records) : r
    if try(r.external_id, null) != null && try(r.email, null) != null && trimspace(r.email) != ""
  ]

  # Group emails by external_id, split/normalize, de-dupe.
  by_account = {
    for ext_id in distinct([for r in local.records : r.external_id]) :
    ext_id => distinct(flatten([
      for r in local.records : [
        for e in regexall(var.email_token_regex, r.email) :
        lower(trimspace(e)) if trimspace(e) != ""
      ]
      if r.external_id == ext_id
    ]))
  }

  owner_map = {
    for ext_id, emails in local.by_account :
    ext_id => (
      length(var.email_domain_allowlist) == 0
      ? emails
      : [for e in emails : e if contains(var.email_domain_allowlist, element(split("@", e), length(split("@", e)) - 1))]
    )
  }
}

output "owner_map" {
  description = "external_id => [owner emails]. Feed directly into account-project-factory.owner_map."
  value       = { for k, v in local.owner_map : k => v if length(v) > 0 }
}

output "accounts_without_owner" {
  description = "external_ids seen in the graph result but with no usable owner tag."
  value       = [for n in local.norm : n.external_id if !contains(keys(local.owner_map), n.external_id)]
}

output "decoded_result" {
  description = "The decoded GraphQL result — inspect to tune parsing or your query."
  value       = local.decoded
}
