terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.49"
    }
  }
  cloud {
    organization = "cloudruler"
    workspaces {
      name = "sandbox"
    }
  }
  required_version = ">= 0.14.8"
}