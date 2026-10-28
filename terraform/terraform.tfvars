# BYU 590R Monorepo Terraform Variables
# This file contains non-sensitive infrastructure configuration and is committed to the repository

# AWS Configuration
aws_region  = "us-west-1"
aws_profile = "default" # class account 728053034151 (user/byu), not neuronova
key_name    = "byu-590r"
project_name = "byu-590r"

# Environment
environment = "production"  # Can be 'development', 'local', or 'production'

# EC2 Configuration
instance_type = "t2.micro"
ami_id        = "ami-04f34746e5e1ec0fe"

# Security Group Configuration
allowed_cidr_blocks = ["0.0.0.0/0"]

# Book Images Configuration
book_images_path = "backend/public/assets/books"
book_images = [
  "hp1.jpeg",
  "hp2.jpeg",
  "hp3.jpeg",
  "hp4.jpeg",
  "hp5.jpeg",
  "hp6.jpeg",
  "hp7.jpeg",
  "mb1.jpg",
  "mb2.jpg",
  "mb3.jpg",
  "bom.jpg"
]

# Optional: update GitHub Actions secrets from Terraform (EC2_HOST, S3_BUCKET, etc.)
# Only used when manage_github_secrets = true. Do not commit real tokens.
# github_token       = ""   # GitHub PAT with repo Secrets write
# github_repository  = "BYU-IS-590R-Christiansen/byu-590r-monorepo"
# manage_github_secrets = false
