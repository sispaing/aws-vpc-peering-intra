terraform {
  required_version = ">= 1.12"

  cloud {
    organization = "nickcloud4t-master" # change to your HCP Terraform org

    workspaces {
      project = "aws-vpc-peering-infra"
      name    = "fe-security-ws"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}
