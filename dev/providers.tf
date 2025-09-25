terraform {
  required_version = ">= 1.13.0"

  cloud {
    organization = "piotrsacharuk"

    workspaces {
      name = "learning-terraform"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}
