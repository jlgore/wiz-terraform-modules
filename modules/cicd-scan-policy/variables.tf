variable "name" {
  description = "Display name of the scan policy."
  type        = string
}

variable "description" {
  description = "Description of the scan policy."
  type        = string
  default     = null
}

variable "is_default" {
  description = <<-EOT
    Make this the org's DEFAULT scan policy. Footgun: only one default per scan
    type should exist, and flipping this reassigns which policy CI/CD scans use
    when none is named. Left false unless you mean it. Maps to the provider's
    `default` argument.
  EOT
  type        = bool
  default     = false
}

variable "lifecycle_targets" {
  description = "Stages in which the policy is enforced. Subset of: DEPLOY, BUILD, CODE."
  type        = set(string)
  default     = null

  validation {
    condition = var.lifecycle_targets == null ? true : alltrue([
      for t in var.lifecycle_targets : contains(["DEPLOY", "BUILD", "CODE"], t)
    ])
    error_message = "lifecycle_targets must be a subset of DEPLOY, BUILD, CODE."
  }
}

variable "projects" {
  description = "Optional set of project IDs the policy is associated with."
  type        = set(string)
  default     = null
}

variable "ignore_rules" {
  description = "Optional set of ignore-rule IDs associated with the policy (e.g. outputs from the ignore-rule module)."
  type        = set(string)
  default     = null
}

# --- Gate presets (build `params`) --------------------------------------------
# Set one or more gates for the common scan types. For scan types not covered
# here (host configuration, SAST, malware, sensitive data, software supply
# chain, image integrity), use `params_override`.

variable "vulnerability_gate" {
  description = <<-EOT
    Fail on vulnerabilities at/above `severity`. `package_count_threshold` is
    the max findings allowed per package; `ignore_unfixed` skips vulns with no
    fix available.
  EOT
  type = object({
    severity                = string
    package_count_threshold = number
    ignore_unfixed          = bool
  })
  default = null

  validation {
    condition = var.vulnerability_gate == null ? true : contains(
      ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.vulnerability_gate.severity
    )
    error_message = "vulnerability_gate.severity must be one of INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

variable "secrets_gate" {
  description = <<-EOT
    Fail when more than `count_threshold` secrets are found (inclusive).
    Optionally set a minimum `severity_threshold`.
  EOT
  type = object({
    count_threshold    = number
    severity_threshold = optional(string)
  })
  default = null

  validation {
    condition = try(var.secrets_gate.severity_threshold, null) == null ? true : contains(
      ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.secrets_gate.severity_threshold
    )
    error_message = "secrets_gate.severity_threshold must be one of INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

variable "iac_gate" {
  description = "Fail on IaC misconfigurations at/above `severity_threshold`, allowing at most `count_threshold` matches."
  type = object({
    severity_threshold = string
    count_threshold    = number
  })
  default = null

  validation {
    condition = var.iac_gate == null ? true : contains(
      ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"], var.iac_gate.severity_threshold
    )
    error_message = "iac_gate.severity_threshold must be one of INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL."
  }
}

variable "params_override" {
  description = <<-EOT
    Full escape hatch for `params`. When set, used verbatim and the gate presets
    above are ignored. Use for scan types the presets don't cover. Native HCL —
    no jsonencode. Keys are `cicd_scan_policy_params_*` (see provider docs).
  EOT
  type        = any
  default     = null
}

# --- Enforcement preset -------------------------------------------------------

variable "enforcement" {
  description = <<-EOT
    How the policy is enforced per lifecycle. `method` is BLOCK or AUDIT;
    `lifecycles` is a subset of ADMISSION_CONTROLLER, CLI, CODE — the module
    expands one enforcement entry per lifecycle with the same method. Set
    `admission_enforce_on_scope` to also enforce on all in-scope resources when
    ADMISSION_CONTROLLER is included.
  EOT
  type = object({
    method                     = string
    lifecycles                 = set(string)
    admission_enforce_on_scope = optional(bool)
  })
  default = null

  validation {
    condition     = var.enforcement == null ? true : contains(["BLOCK", "AUDIT"], var.enforcement.method)
    error_message = "enforcement.method must be BLOCK or AUDIT."
  }

  validation {
    condition = var.enforcement == null ? true : alltrue([
      for l in var.enforcement.lifecycles : contains(["ADMISSION_CONTROLLER", "CLI", "CODE"], l)
    ])
    error_message = "enforcement.lifecycles must be a subset of ADMISSION_CONTROLLER, CLI, CODE."
  }
}

variable "policy_lifecycle_enforcements_override" {
  description = "Full escape hatch for `policy_lifecycle_enforcements`. When set, used verbatim and `enforcement` is ignored."
  type        = any
  default     = null
}
