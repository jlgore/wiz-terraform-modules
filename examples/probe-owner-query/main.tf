# Probe: run ONE Wiz graph query and dump the raw result envelope.
#
# A small helper for inspecting exactly what `wiz-v2_graphql_query` returns for a
# SUBSCRIPTION lookup — useful when tuning the wiz-graph resolver's parser to a
# tenant whose graph shape differs from the default.
#
# Usage:
#   1. Put real subscription external IDs in var.external_ids (or pass -var).
#   2. Configure the wiz-v2 provider the way you do (creds/endpoint).
#   3. terraform init && terraform apply
#   4. terraform output -json decoded_result   # inspect the shape

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

# Configure per the Wiz Terraform provider docs. Left unconfigured on purpose.
provider "wiz-v2" {}

variable "external_ids" {
  description = "Subscription external IDs to look up (AWS account IDs / Azure sub IDs / GCP project IDs)."
  type        = list(string)
  default     = ["00000000-0000-0000-0000-000000000000"]
}

# GraphEntityQueryInput wrapped in a graphSearch operation. `properties` is
# requested so tags come back in the result.
data "wiz-v2_graphql_query" "probe" {
  query = <<-GQL
    query GraphSearch($query: GraphEntityQueryInput, $first: Int, $after: String) {
      graphSearch(query: $query, first: $first, quick: false, after: $after) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          entities {
            id
            name
            type
            properties
          }
        }
      }
    }
  GQL

  query_variables = jsonencode({
    query = {
      type   = ["SUBSCRIPTION"]
      select = true
      where = {
        externalId = { EQUALS = var.external_ids }
      }
    }
    first = 50
  })
}

# Raw string, exactly as the provider returns it.
output "raw_result" {
  value = data.wiz-v2_graphql_query.probe.result
}

# Decoded — easier to eyeball the envelope and property names.
output "decoded_result" {
  value = jsondecode(data.wiz-v2_graphql_query.probe.result)
}
