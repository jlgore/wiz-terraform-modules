# cicd-scan-policy

An opinionated wrapper over `wiz-v2_cicd_scan_policy` that turns the eight-way
`params` union and the per-lifecycle enforcement set into a few typed presets.

## Why

The raw resource has sharp edges:

- **`params` is a union of eight `cicd_scan_policy_params_*` blocks**, each with
  its own required nested fields. This module exposes typed gates for the three
  common scan types — `vulnerability_gate`, `secrets_gate`, `iac_gate` — and
  builds the right block. (`sensitive_data` even uses `INFO` instead of
  `INFORMATIONAL`; leave that kind of thing to `params_override`.)
- **`policy_lifecycle_enforcements` is a set** of `{deployment_lifecycle,
  enforcement_method, …}`. Set one `enforcement` preset and the module expands
  one entry per lifecycle.
- **`default` silently reassigns the org default policy.** It's surfaced as the
  deliberately-named `is_default`, defaulting to `false`.

Everything is native HCL — nothing here needs `jsonencode`.

## Usage — block builds on high-severity vulns and any secret

```hcl
module "build_gate" {
  source = "../../modules/cicd-scan-policy"

  name              = "Build gate — vulns + secrets"
  lifecycle_targets = ["BUILD"]
  projects          = [module.projects.project_ids["<account-slug>"]]

  vulnerability_gate = {
    severity                = "HIGH"
    package_count_threshold = 0
    ignore_unfixed          = true
  }

  secrets_gate = {
    count_threshold = 0
  }

  enforcement = {
    method     = "BLOCK"
    lifecycles = ["CLI"]
  }
}
```

## Gate presets

| Gate | Builds | Required fields |
|------|--------|-----------------|
| `vulnerability_gate` | `cicd_scan_policy_params_vulnerabilities` | `severity`, `package_count_threshold`, `ignore_unfixed` |
| `secrets_gate` | `cicd_scan_policy_params_secrets` | `count_threshold` (opt. `severity_threshold`) |
| `iac_gate` | `cicd_scan_policy_params_iac` | `severity_threshold`, `count_threshold` |

Set one or more. For the scan types the presets don't cover (host configuration,
SAST, malware, sensitive data, software supply chain, image integrity), use
`params_override`.

## Enforcement preset

`enforcement = { method, lifecycles, admission_enforce_on_scope? }` expands to
one `policy_lifecycle_enforcements` entry per lifecycle:

- `method` — `BLOCK` or `AUDIT`
- `lifecycles` — subset of `ADMISSION_CONTROLLER`, `CLI`, `CODE`
- `admission_enforce_on_scope` — when `ADMISSION_CONTROLLER` is included, also
  enforce on all in-scope resources

## Escape hatches

| Need | Input |
|------|-------|
| A scan type the gates don't cover | `params_override` (verbatim `params`) |
| Mixed methods per lifecycle, or admission config beyond the preset | `policy_lifecycle_enforcements_override` |
| Make this the org default | `is_default = true` |

## Outputs

- `id` — the created policy's ID
- `name` — the created policy's name
