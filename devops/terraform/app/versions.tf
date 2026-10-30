terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  # Partial config: bucket/key/region are passed at init time, e.g.
  #   terraform init -backend-config=bucket=<state bucket> \
  #                  -backend-config=key=app/dev.tfstate -backend-config=region=<region>
  # (scripts/tf.sh does this for you.)
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = var.project, Environment = var.env, ManagedBy = "terraform" }
  }
}
