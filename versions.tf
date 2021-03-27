terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.49"
    }
  }
  backend "remote" {
    organization = "cloudruler"
    workspaces {
      name = "sandbox"
    }
  }
  required_version = ">= 0.14.8"
}