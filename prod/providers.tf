terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "piotrsacharuk"

    workspaces {
      name = "learning-terraform-prod"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.14.1"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}
