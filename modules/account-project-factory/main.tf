locals {
  # Opinionated risk-profile presets. Override wholesale with risk_profile_override.
  risk_presets = {
    regulated = {
      business_impact    = "HBI"
      is_customer_facing = "YES"
      is_internet_facing = "YES"
      is_regulated       = "YES"
      stores_data        = "YES"
    }
    customer_facing = {
      business_impact    = "HBI"
      is_customer_facing = "YES"
      is_internet_facing = "YES"
    }
    internal = {
      business_impact    = "MBI"
      is_customer_facing = "NO"
      is_internet_facing = "NO"
    }
    none = null
  }

  risk_profile = var.risk_profile_override != null ? var.risk_profile_override : local.risk_presets[var.risk_profile_preset]

  # Resolve owners per account: per-account override wins over the owner_map.
  owners = {
    for key, acct in var.accounts :
    key => acct.owner_emails != null ? acct.owner_emails : lookup(var.owner_map, acct.external_id, [])
  }

  # Rendered project name per account.
  project_names = {
    for key, acct in var.accounts :
    key => replace(replace(replace(
      var.name_template,
      "$${name}", coalesce(acct.name, acct.external_id)),
      "$${external_id}", acct.external_id),
    "$${env}", acct.environment)
  }
}

resource "wiz-v2_project" "this" {
  for_each = var.accounts

  name           = local.project_names[each.key]
  business_unit  = var.business_unit
  parent_project = var.parent_project

  security_champions = var.champions_from_owners && length(local.owners[each.key]) > 0 ? local.owners[each.key] : null
  project_owners     = var.owners_as_project_owners && length(local.owners[each.key]) > 0 ? local.owners[each.key] : null

  cloud_account_links = [{
    cloud_account = each.value.cloud_account_id
    environment   = each.value.environment
  }]

  # risk_profile is a nested-object ATTRIBUTE (not a block) in the provider, and
  # every field is a string. Build one complete object so the shape is uniform
  # whether it came from a partial preset or the override; try() fills the gaps.
  risk_profile = local.risk_profile == null ? null : {
    business_impact       = try(local.risk_profile.business_impact, null)
    has_authentication    = try(local.risk_profile.has_authentication, null)
    has_exposed_api       = try(local.risk_profile.has_exposed_api, null)
    is_actively_developed = try(local.risk_profile.is_actively_developed, null)
    is_customer_facing    = try(local.risk_profile.is_customer_facing, null)
    is_internet_facing    = try(local.risk_profile.is_internet_facing, null)
    is_regulated          = try(local.risk_profile.is_regulated, null)
    regulatory_standards  = try(local.risk_profile.regulatory_standards, null)
    sensitive_data_types  = try(local.risk_profile.sensitive_data_types, null)
    stores_data           = try(local.risk_profile.stores_data, null)
  }
}
