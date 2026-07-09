# ignore-rule
#
# Opinionated wrapper over `wiz-v2_ignore_rule`. It hides the sharp edges of
# ignore rules:
#   1. Non-threat ignore rules require >= 2 `conditions`; we pad automatically.
#   2. "Ignore" vs "downgrade severity" is a preset, not a hand-built action set.
#   3. The 11 rule-ID scope arguments collapse into one `scoped_rule_ids` bundle.
# `conditions` are native HCL attributes here (NOT a JSON string), so — unlike
# automation-rule filters — there is nothing to jsonencode.

locals {
  # A rule whose finding_types are exclusively THREAT_DETECTION_ISSUE is exempt
  # from the >= 2 conditions requirement.
  threat_only = (
    var.finding_types != null &&
    length(var.finding_types) > 0 &&
    length(setsubtract(var.finding_types, ["THREAT_DETECTION_ISSUE"])) == 0
  )

  condition_keys = var.conditions == null ? [] : keys(var.conditions)

  need_pad = (
    var.pad_conditions &&
    !local.threat_only &&
    var.conditions != null &&
    length(local.condition_keys) < 2
  )

  # Append a bare match on a bucket not already present, so we never clobber a
  # caller-supplied condition.
  pad_key = contains(local.condition_keys, "resource") ? "environment" : "resource"

  effective_conditions = local.need_pad ? merge(var.conditions, { (local.pad_key) = {} }) : var.conditions

  # Downgrade preset -> modify severity action; otherwise a plain ignore.
  built_actions = var.downgrade_severity_to == null ? null : [
    {
      modify_finding_severity_ignore_rule_action = {
        severity = var.downgrade_severity_to
      }
    }
  ]

  effective_actions = var.actions_override != null ? var.actions_override : local.built_actions
}

resource "wiz-v2_ignore_rule" "this" {
  name                  = var.name
  description           = var.description
  enabled               = var.enabled
  finding_ignore_reason = var.finding_ignore_reason
  finding_types         = var.finding_types
  project               = var.project
  expired_at            = var.expired_at
  vulnerabilities       = var.vulnerabilities
  targets               = var.targets

  conditions = local.effective_conditions
  actions    = local.effective_actions
  tags       = var.tags

  attack_surface_rules          = var.scoped_rule_ids.attack_surface
  cloud_configuration_rules     = var.scoped_rule_ids.cloud_configuration
  cloud_cost_optimization_rules = var.scoped_rule_ids.cloud_cost_optimization
  data_classification_rules     = var.scoped_rule_ids.data_classification
  host_configuration_rules      = var.scoped_rule_ids.host_configuration
  image_integrity_validators    = var.scoped_rule_ids.image_integrity_validators
  inventory_finding_rules       = var.scoped_rule_ids.inventory_finding
  sast_finding_rules            = var.scoped_rule_ids.sast_finding
  secret_detection_rules        = var.scoped_rule_ids.secret_detection
  software_supply_chain_rules   = var.scoped_rule_ids.software_supply_chain
  threat_detection_rules        = var.scoped_rule_ids.threat_detection
}
