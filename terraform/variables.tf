variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "AWS shared-credentials profile. Default is the class account (user/byu), not neuronova."
  type        = string
  default     = "default"
}

variable "key_name" {
  description = "Name of the AWS EC2 Key Pair"
  type        = string
  default     = "byu-590r"
}

variable "project_name" {
  description = "Project name for resource naming and tagging"
  type        = string
  default     = "byu-590r"
}

variable "environment" {
  description = "Environment name (development, local, or production)"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-04f34746e5e1ec0fe"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed for security group ingress rules"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "book_images_path" {
  description = "Path to book images directory relative to project root"
  type        = string
  default     = "backend/public/assets/books"
}

variable "book_images" {
  description = "List of book image files to upload to S3"
  type        = list(string)
  default = [
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
}

# GitHub Actions secrets (optional): when set, Terraform will create/update these repo secrets from AWS outputs
variable "github_token" {
  description = "GitHub PAT with repo Secrets write; used only to update GitHub Actions secrets (EC2_HOST, S3_BUCKET, etc.). Leave empty to skip."
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_repository" {
  description = "Repository for GitHub Actions secrets (owner/repo)"
  type        = string
  default     = "BYU-IS-590R-Christiansen/byu-590r-monorepo"
}

variable "manage_github_secrets" {
  description = "When true and github_token is set, create/update GitHub Actions repository secrets from Terraform outputs."
  type        = bool
  default     = false
}
