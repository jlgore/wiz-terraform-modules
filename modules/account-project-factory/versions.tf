terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Preview provider. Keep this `source` identical across the root config and
    # every module (Terraform treats differing sources as different providers).
    # Set it to whatever registry you pull the provider from.
    wiz-v2 = {
      source  = "wizsec/wiz-v2"
      version = ">= 0.1" # preview; adjust to the provider version you use
    }
  }
}
