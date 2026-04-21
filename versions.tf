terraform {
  required_version = ">= 1.5.0"

  required_providers {
    civo = {
      source  = "civo/civo"
      version = "~> 1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
