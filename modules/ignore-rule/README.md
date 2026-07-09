# ignore-rule

An opinionated wrapper over `wiz-v2_ignore_rule` that hides the ignore-rule
sharp edges: the two-condition minimum, the ignore-vs-downgrade choice, and the
eleven separate rule-ID scope arguments.

## Why

The raw resource has sharp edges:

- **Non-threat rules need ≥ 2 `conditions`.** A rule with a single condition is
  rejected by the API with a non-obvious error. This module appends a bare match
  condition automatically (toggle with `pad_conditions`).
- **Ignore vs downgrade** is expressed through the `actions` set. Instead of
  hand-building `modify_finding_severity_ignore_rule_action`, set
  `downgrade_severity_to`.
- **Eleven `*_rules` scope arguments** (`attack_surface_rules`,
  `cloud_configuration_rules`, …) collapse into one `scoped_rule_ids` bundle.

Unlike `automation-rule` filters, **`conditions` are native HCL attributes** —
there is nothing to `jsonencode`.

## Usage — ignore a low-risk CVE on Python packages

```hcl
module "ignore_python_cve" {
  source = "../../modules/ignore-rule"

  name                  = "Ignore low-risk Python vuln"
  description           = "False positive for CVE-2025-13836 on Python packages"
  finding_ignore_reason = "FALSE_POSITIVE"
  finding_types         = ["VULNERABILITY"]
  vulnerabilities       = ["CVE-2025-13836"]

  conditions = {
    vulnerability_finding = {
      severity      = ["LOW", "MEDIUM"]
      detailed_name = { contains = ["Python"] }
    }
    # Only one condition given — the module appends a bare `resource = {}` so the
    # API's two-condition rule is satisfied.
  }
}
```

## Usage — downgrade instead of suppress

```hcl
module "downgrade_dev_secrets" {
  source = "../../modules/ignore-rule"

  name                  = "Downgrade secrets in dev"
  description           = "Dev-only secrets are lower priority, not ignored"
  finding_ignore_reason = "RISK_ACCEPTED"
  finding_types         = ["SECRET_INSTANCE"]
  downgrade_severity_to = "LOW"

  conditions = {
    secret_instance = { severity = ["HIGH", "CRITICAL"] }
    resource        = { environment = { equals = ["DEVELOPMENT"] } }
  }
}
```

## Inputs

| Input | Purpose |
|-------|---------|
| `name`, `description` | Both required by the API — `description` should say *why*. |
| `finding_ignore_reason` | Validated enum (`FALSE_POSITIVE`, `RISK_ACCEPTED`, …). |
| `finding_types` | Validated set of finding types the rule applies to. |
| `conditions` | Native HCL match object; auto-padded to ≥ 2 conditions. |
| `downgrade_severity_to` | Preset: downgrade matched findings instead of ignoring. |
| `vulnerabilities`, `targets`, `expired_at`, `project`, `tags` | Common passthroughs. |
| `scoped_rule_ids` | Advanced: bundle of the eleven rule-ID scope arguments. |

## Escape hatches

| Need | Input |
|------|-------|
| Pass conditions through verbatim (no padding) | `pad_conditions = false` |
| A hand-built `actions` set | `actions_override` (verbatim provider `actions` value) |

## Outputs

- `id` — the created rule's ID
- `name` — the created rule's name
