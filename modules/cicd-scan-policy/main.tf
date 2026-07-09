# cicd-scan-policy
#
# Opinionated wrapper over `wiz-v2_cicd_scan_policy`. It hides the sharp edges:
#   1. `params` is a union of eight `cicd_scan_policy_params_*` blocks, each with
#      its own required nested fields. We expose typed gate presets for the three
#      common scan types (vulnerabilities, secrets, IaC) and build the block.
#   2. `policy_lifecycle_enforcements` is a set of {lifecycle, method[, config]}.
#      We expand one entry per lifecycle from a single `enforcement` preset.
#   3. `default` silently reassigns the org default policy — surfaced as the
#      deliberately-named `is_default`.
# Everything is native HCL — nothing here needs jsonencode. `params_override`
# and `policy_lifecycle_enforcements_override` are the full escape hatches.

locals {
  gates_set = (
    var.vulnerability_gate != null ||
    var.secrets_gate != null ||
    var.iac_gate != null
  )

  built_params = local.gates_set ? {
    cicd_scan_policy_params_vulnerabilities = var.vulnerability_gate == null ? null : {
      severity                = var.vulnerability_gate.severity
      package_count_threshold = var.vulnerability_gate.package_count_threshold
      ignore_unfixed          = var.vulnerability_gate.ignore_unfixed
    }

    cicd_scan_policy_params_secrets = var.secrets_gate == null ? null : {
      count_threshold                   = var.secrets_gate.count_threshold
      secret_finding_severity_threshold = var.secrets_gate.severity_threshold
    }

    cicd_scan_policy_params_iac = var.iac_gate == null ? null : {
      severity_threshold = var.iac_gate.severity_threshold
      count_threshold    = var.iac_gate.count_threshold
    }
  } : null

  effective_params = var.params_override != null ? var.params_override : local.built_params

  built_enforcements = var.enforcement == null ? null : [
    for lc in var.enforcement.lifecycles : {
      deployment_lifecycle = lc
      enforcement_method   = var.enforcement.method
      enforcement_config = (
        lc == "ADMISSION_CONTROLLER" && var.enforcement.admission_enforce_on_scope != null
        ) ? {
        policy_lifecycle_enforcement_config_admission_controller = {
          enforce_on_scope = var.enforcement.admission_enforce_on_scope
        }
      } : null
    }
  ]

  effective_enforcements = var.policy_lifecycle_enforcements_override != null ? var.policy_lifecycle_enforcements_override : local.built_enforcements
}

resource "wiz-v2_cicd_scan_policy" "this" {
  name              = var.name
  description       = var.description
  default           = var.is_default
  lifecycle_targets = var.lifecycle_targets
  projects          = var.projects
  ignore_rules      = var.ignore_rules

  params                        = local.effective_params
  policy_lifecycle_enforcements = local.effective_enforcements
}
