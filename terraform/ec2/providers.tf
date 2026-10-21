provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# Authentication is read from the CLOUDFLARE_API_TOKEN environment variable.
provider "cloudflare" {}
