terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "aws-multi-vpc-hub-spoke"
      ManagedBy = "terraform"
      Owner     = "jack-salamone"
    }
  }
}
