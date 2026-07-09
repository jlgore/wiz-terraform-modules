# Contributing

Thanks for your interest. This repo is a small, opinionated set of Terraform
modules for the Wiz v2 provider. Contributions that sharpen the existing modules
or add a well-shaped new one are welcome. A few conventions keep it coherent.

## Ground rule: nothing tenant-specific, ever

This is a public repository. **Do not commit anything tied to a real Wiz tenant
or cloud environment:**

- No real subscription / account / organization IDs, project IDs, or resource
  IDs.
- No employee or user emails, internal tag keys, or management-group / OU paths.
- No real registry host. The provider `source` is pinned to the neutral
  placeholder **`wizsec/wiz-v2`** everywhere; keep it that way (see below).
- No `terraform` state or plan files. `terraform apply` against a live tenant
  writes real data into state — don't run it here, and never commit state.

The [`.gitignore`](.gitignore) blocks `*.tfstate*`, `.terraform/`, and `*.tfvars`
(the tracked template is `*.tfvars.example`). Before committing, sweep your
change for your own tenant identifiers and registry host and make sure none of
them made it in.

## The provider `source` placeholder

Terraform treats two different `source` strings as two different providers, so
the placeholder must be **identical** across the root config and every module's
`versions.tf`:

```hcl
wiz-v2 = {
  source  = "wizsec/wiz-v2"
  version = ">= 0.1" # preview; adjust to the version you use
}
```

Never hardcode a real registry host. CI injects the real source at runtime from
the `WIZ_PROVIDER_SOURCE` repo variable (see
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)).

## Design conventions

Every module follows the same shape — match it:

- **Presets + escape hatch.** Named presets for the common case, plus a raw
  passthrough (`*_override`, `raw_actions`, `params_override`, …) for anything
  the presets don't cover. A caller should never be *stuck*.
- **Hide the footguns.** If the provider makes you `jsonencode()` a field,
  hand-satisfy an API constraint (e.g. the ignore-rule two-condition minimum),
  or pick between many differently-shaped blocks — that's the module's job, not
  the caller's.
- **Surface the gaps.** Output what *didn't* resolve (e.g.
  `accounts_without_owners`) so silent misses are visible.
- **Validate enums.** Use `variable` `validation` blocks for closed sets
  (severities, reasons, lifecycle stages) so mistakes fail at plan, not apply.
- **One file per concern.** `versions.tf`, `variables.tf`, `main.tf`,
  `outputs.tf`, and a `README.md` per module, in the same style as the others.

## Validating a change

Before opening a PR, format and lint (no provider needed):

```sh
terraform fmt -recursive .
tflint --recursive --minimum-failure-severity=error
```

CI runs `terraform validate` against the provider on every push. The full
provider-dependent job runs only when the maintainer has set the
`WIZ_PROVIDER_SOURCE` repo variable, so forks are never failed by it. `validate`
checks your config against the provider *schema* only — it needs no credentials
and no tenant data. If you have the provider installed locally, you can run
`terraform init -backend=false` + `terraform validate` per module the same way,
against your own provider source.

> The bundled `wiz-v2-*.md` provider docs are a helpful reference but don't
> always match the current provider exactly — when in doubt, trust
> `terraform providers schema -json`.

## Pull requests

- Keep a PR to one module or one concern.
- Update the module's `README.md` and the root [`README.md`](README.md) table
  when you add or change a module's surface.
- If you add a module, add its directory to the CI `validate` loop in
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml).
- Add a `*.tfvars.example` (not `*.tfvars`) if the module ships an example.

## License

By contributing, you agree your contributions are licensed under the repo's
[MIT License](LICENSE).
