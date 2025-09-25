terraform {
  cloud {
    organization = "piotrsacharuk"

    workspaces {
      name = "learning-terraform"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}
