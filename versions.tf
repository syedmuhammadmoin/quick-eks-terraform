terraform {
  required_version = ">= 1.10" # S3 native state locking (use_lockfile)

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # EKS module v20 caps the provider at < 6.0. Moving to 6.x needs
      # EKS module v21 and VPC module v6, which rename many inputs.
      version = "~> 5.95"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.cluster_name
      ManagedBy = "terraform"
      Ephemeral = "true"
    }
  }
}
