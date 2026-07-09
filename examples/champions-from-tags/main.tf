# Example: Wiz-native "security champions from cloud tags"
#
# Flow (single provider — Wiz only):
#   discover cloud accounts  ->  read owner tag from the graph  ->  build one
#   project per account with the owner email set as security champion.
#
# Everything is driven by variables so you can retarget it to your own tenant,
# tag convention, and project conventions without editing this file.

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    wiz-v2 = {
      # Provider is in preview. Set `source` to whatever registry you pull it
      # from, and keep it identical across the root and every module's
      # versions.tf (Terraform treats differing sources as different providers).
      source  = "wizsec/wiz-v2"
      version = ">= 0.1" # preview; adjust to the provider version you use
    }
  }
}

# Configure the wiz-v2 provider per the Wiz Terraform provider docs
# (service-account credentials / endpoint). Left unconfigured on purpose —
# nothing tenant-specific is shipped in this repo.
provider "wiz-v2" {}

# 1. DISCOVER — cloud accounts Wiz knows about, filtered to the providers you want.
data "wiz-v2_cloud_accounts" "discovered" {
  cloud_provider      = var.cloud_providers
  assigned_to_project = var.only_unassigned ? false : null
  search              = length(var.account_search) > 0 ? var.account_search : null
}

locals {
  # Normalize discovery into the factory's `accounts` shape, keyed by external_id.
  accounts = {
    for a in data.wiz-v2_cloud_accounts.discovered.cloud_accounts :
    a.external_id => {
      cloud_account_id = a.id          # internal Wiz ID -> cloud_account_links
      external_id      = a.external_id # subscription/account ID -> owner join key
      name             = a.name
      environment      = var.environment
    }
  }
  external_ids = keys(local.accounts)
}

# 2. RESOLVE OWNERS — read the owner tag off each subscription in the Wiz graph.
module "owners" {
  source = "../../modules/resolvers/wiz-graph"

  entity_types           = var.entity_types
  external_ids           = local.external_ids
  owner_tag_keys         = var.owner_tag_keys
  email_domain_allowlist = var.email_domain_allowlist
}

# 3. BUILD PROJECTS — one per account, owner emails as security champions.
module "projects" {
  source = "../../modules/account-project-factory"

  accounts      = local.accounts
  owner_map     = module.owners.owner_map
  name_template = var.project_name_template

  risk_profile_preset      = var.risk_profile_preset
  champions_from_owners    = true
  owners_as_project_owners = var.owners_as_project_owners
  business_unit            = var.business_unit
}

# 4. VISIBILITY — see what happened, including gaps.
output "projects" {
  value = module.projects.project_ids
}

output "resolved_owners" {
  value = module.owners.owner_map
}

output "accounts_missing_owner_tag" {
  description = "Accounts discovered but with no owner tag — they got no champion."
  value       = module.projects.accounts_without_owners
}
