# BYU 590R Monorepo - Terraform Infrastructure

This Terraform configuration replicates the functionality of `devops/bash/setup-ec2-server.sh`.

## What This Creates

- **Security Group**: `byu-590r-sg` with ingress rules for:
  - SSH (port 22)
  - HTTP (port 80)
  - HTTPS (port 443)
  - Backend API (port 4444)

- **EC2 Instance**: `t2.micro` instance with:
  - Node.js 18
  - PHP 8.3.36 with required extensions
  - Composer
  - MySQL
  - Apache with virtual hosts configured
  - Application directories created
  - Database and user configured

- **Elastic IP**: Static IP address associated with the EC2 instance

- **S3 Buckets**: Two buckets created:
  - Dev bucket: `${project_name}-dev-{timestamp}`
  - Prod bucket: `${project_name}-prod-{timestamp}-{random_id}`
  - Both buckets have book images uploaded to `images/` prefix

## Prerequisites

1. **Terraform**: Install Terraform >= 1.0

   ```bash
   # macOS
   brew install terraform

   # Or download from https://www.terraform.io/downloads
   ```

2. **AWS CLI**: Configured with appropriate credentials

   ```bash
   aws configure
   ```

3. **AWS Key Pair**: Ensure you have the EC2 key pair (`byu-590r` by default) created in AWS

4. **Book Images**: Ensure book images exist in `backend/public/assets/books/`

## Setup from a clean clone

After cloning the repo, set up Terraform and create infrastructure as follows.

1. **Go to the Terraform directory**

   ```bash
   cd devops/terraform
   ```

2. **(Optional) Edit `terraform.tfvars`** with your values if needed. The file is committed to the repo with non-sensitive defaults. You can override values for your environment.

3. **Initialize Terraform** — downloads providers; uses the committed `.terraform.lock.hcl` so everyone gets the same provider versions.

   ```bash
   terraform init
   ```

4. **Review the plan**

   ```bash
   terraform plan
   ```

5. **Apply the configuration**

   ```bash
   terraform apply
   ```

**Notes:**

- **`terraform.tfvars` is committed** — it contains non-sensitive infrastructure configuration (region, instance type, etc.). Modify it as needed for your environment.
- **Do commit `.terraform.lock.hcl`** — keeping it in the repo ensures consistent provider versions for everyone and for CI.
- **For sensitive values** (like GitHub tokens), use environment variables or create a `secrets.tfvars` file (gitignored).

## Usage

1. **Go to the Terraform directory**:

   ```bash
   cd devops/terraform
   ```

2. **(Optional) Edit `terraform.tfvars`** if you need to customize values for your environment

3. **Initialize Terraform**:

   ```bash
   terraform init
   ```

4. **Review the plan**:

   ```bash
   terraform plan
   ```

5. **Apply the configuration**:

   ```bash
   terraform apply
   ```

6. **View outputs**:

   ```bash
   terraform output
   ```

   Or view specific outputs:

   ```bash
   terraform output ec2_host
   terraform output s3_bucket_prod
   terraform output summary
   ```

## Variables

See `variables.tf` for all available variables. Key variables:

- `aws_region`: AWS region (default: `us-west-1`)
- `key_name`: EC2 key pair name (default: `byu-590r`)
- `project_name`: Project name for resource naming (default: `byu-590r`)
- `instance_type`: EC2 instance type (default: `t2.micro`)
- `ami_id`: AMI ID for EC2 instance (default: `ami-04f34746e5e1ec0fe`)
- `github_token`: (optional) GitHub PAT with repo Secrets write; used only when `manage_github_secrets` is true to update GitHub Actions secrets from Terraform outputs.
- `github_repository`: (optional) Repository for GitHub Actions secrets, e.g. `owner/repo` (default: this repo).
- `manage_github_secrets`: (optional) When true and `github_token` is set, Terraform creates/updates GitHub Actions repository secrets for EC2_HOST, S3_BUCKET, etc. (default: false).

## Outputs

After applying, use these to fill GitHub Actions secrets (Settings → Secrets and variables → Actions). See [.github/README.md](../../.github/README.md) for where each GitHub Actions secret comes from (A: Terraform, B: backend/.env, C: AWS credentials, Manual).

**All values in one place (copy-paste or script):**

```bash
terraform output github_actions_secrets
```

or as JSON:

```bash
terraform output -json github_actions_secrets
```

**Single block for manual copy:**

```bash
terraform output github_actions_copy_paste
```

| Secret / value  | Output / meaning                                                      |
| --------------- | --------------------------------------------------------------------- |
| `EC2_HOST`      | `terraform output ec2_host` – instance host (Elastic IP)              |
| `S3_BUCKET`     | `terraform output s3_bucket_prod` – production bucket for deployments |
| `S3_BUCKET_DEV` | `terraform output s3_bucket_dev` – dev bucket (e.g. for local `.env`) |
| `INSTANCE_ID`   | `terraform output instance_id` – EC2 instance ID                      |

Other outputs:

- `instance_id`: EC2 instance ID
- `elastic_ip`: Elastic IP address
- `ec2_host`: EC2 host (same as `EC2_HOST` above)
- `s3_bucket_dev`: Dev S3 bucket name
- `s3_bucket_prod`: Prod S3 bucket name
- `frontend_url`: Frontend URL
- `backend_api_url`: Backend API URL
- `summary`: Full summary and next steps

### Optional: update GitHub Actions secrets from Terraform

Terraform can create or update these repository secrets automatically after apply: `EC2_HOST`, `S3_BUCKET`, `S3_BUCKET_DEV`, `S3_BUCKET_PROD`, `INSTANCE_ID`. To enable:

1. Create a GitHub PAT with **repo** scope (or fine-grained with Secrets write).
2. In `terraform.tfvars` (or via `TF_VAR_*`), set:
   - `manage_github_secrets = true`
   - `github_token = "your_pat"` (do not commit; use env or gitignored tfvars)
   - `github_repository = "owner/repo"` (optional; default is this repo)
3. Run `terraform apply`. The GitHub provider will write the current Terraform outputs into the repo’s Actions secrets.

**Note:** Those secret values will appear in Terraform state. Restrict state access (e.g. remote backend). For the full list of secrets and sources (A/B/C/Manual), see [.github/README.md](../../.github/README.md).

## Teardown (Destroy All Resources)

Terraform can tear down **all** assets it created, matching the behavior of `devops/bash/teardown.sh`. This removes:

- EC2 instance
- Elastic IP (disassociated and released)
- Security group and all rules
- Both S3 buckets (dev and prod) and their contents (including uploaded book images)

**Destroy everything:**

```bash
terraform destroy
```

You will be prompted to confirm. To skip confirmation:

```bash
terraform destroy -auto-approve
```

After destroy, your state file will be updated and no AWS resources from this config will remain.

## Re-run: Teardown Then Apply

To tear down all assets and then create them again (clean re-run, equivalent to running teardown.sh then setup-ec2-server.sh):

**Option 1 – one-liner:**

```bash
terraform destroy -auto-approve && terraform apply -auto-approve
```

**Option 2 – script (with optional prompts):**

```bash
./teardown-and-apply.sh
```

For non-interactive use (e.g. CI):

```bash
./teardown-and-apply.sh --auto-approve
```

This destroys all Terraform-managed resources, then runs `terraform apply` so you get a fresh EC2 instance, new Elastic IP, new S3 buckets, and new security group.

## Differences from Bash Script

1. **S3 Bucket Naming**: Terraform uses timestamp-based naming instead of `date +%s` and `openssl rand`
2. **Book Image Upload**: Uses Terraform's `aws_s3_object` resource instead of AWS CLI
3. **User Data**: EC2 setup script is embedded in Terraform as `user_data` instead of being uploaded via SSH
4. **State Management**: Terraform maintains state file (`.tfstate`) to track resources
5. **Idempotency**: Terraform ensures resources are only created once and can be updated safely

## State File

Terraform creates a `terraform.tfstate` file that tracks all resources. **Do not delete this file** unless you want to lose track of your infrastructure.

For production use, consider using remote state backends (S3, Terraform Cloud, etc.):

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "byu-590r/terraform.tfstate"
    region = "us-west-1"
  }
}
```

## Troubleshooting

### Book Images Not Found

If Terraform fails to find book images, ensure:

- The `book_images_path` variable points to the correct directory
- All files listed in `book_images` exist in that directory
- Paths are relative to the Terraform module directory

### EC2 Instance Not Accessible

- Verify security group rules are applied
- Check that Elastic IP is associated
- Ensure key pair exists in AWS
- Verify instance is running: `aws ec2 describe-instances --instance-ids <instance-id>`

### S3 Bucket Creation Fails

- Ensure bucket names are globally unique
- Check AWS region configuration
- Verify IAM permissions for S3 bucket creation
