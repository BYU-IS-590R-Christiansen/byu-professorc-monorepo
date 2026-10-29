# GitHub Actions CI/CD Setup

This repository uses GitHub Actions for automated testing and deployment to AWS EC2.

## Prerequisites

1. **EC2 Server Setup**: Run the server setup script first:

   ```bash
   cd devops
   chmod +x setup-server-only.sh
   ./setup-server-only.sh
   ```

2. **GitHub Secrets**: Add the secrets listed below. Each secret has a **source**: **A) Terraform**, **B) backend/.env**, **C) AWS credentials**, or **Manual**. Go to Settings → Secrets and variables → Actions and add each one as described.

### GitHub Actions secrets: where each value comes from

| Secret                                                                                       | Source | How to populate                                                                                                                                                                                                                                                    |
| -------------------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **A) Terraform (IaC)**                                                                       |        |                                                                                                                                                                                                                                                                    |
| `EC2_HOST`                                                                                   | A      | After `terraform apply`, these can be updated automatically if you set `manage_github_secrets = true` and `github_token` (PAT with repo Secrets write) in Terraform. Otherwise copy from `terraform output github_actions_secrets` or `terraform output ec2_host`. |
| `S3_BUCKET`                                                                                  | A      | Same as above; value is the prod bucket name from Terraform.                                                                                                                                                                                                       |
| `S3_BUCKET_DEV`                                                                              | A      | Same as above; value is the dev bucket name from Terraform.                                                                                                                                                                                                        |
| `S3_BUCKET_PROD`                                                                             | A      | Same as above; value is the prod bucket name from Terraform.                                                                                                                                                                                                       |
| `INSTANCE_ID`                                                                                | A      | Optional; same as above; value is the EC2 instance ID from Terraform.                                                                                                                                                                                              |
| **B) backend/.env (make start)**                                                             |        |                                                                                                                                                                                                                                                                    |
| `DB_DATABASE`                                                                                | B      | Copy from `backend/.env`: `app_db`. Same value locally and on EC2.                                                                                                                                                                                                 |
| `DB_USERNAME`                                                                                | B      | Copy from `backend/.env`: `app_user`. Same value locally and on EC2.                                                                                                                                                                                               |
| `DB_PASSWORD`                                                                                | B      | Copy from `backend/.env`: `app_password`. Same value locally and on EC2.                                                                                                                                                                                           |
| `APP_DEBUG`                                                                                  | B      | Copy from `backend/.env` (e.g. `true` or `false`).                                                                                                                                                                                                                 |
| `OPENAI_API_KEY`                                                                             | B      | Copy from `backend/.env` if you use OpenAI.                                                                                                                                                                                                                        |
| `MAIL_MAILER`                                                                                | B      | `mailgun`                                                                                                                                                                                                                                                          |
| `MAIL_FROM_ADDRESS`                                                                          | B      | Sender on the Mailgun domain, e.g. `noreply@your-domain.mailgun.org`. Sandbox must use the sandbox domain.                                                                                                                                                         |
| `MAIL_FROM_NAME`                                                                             | B      | Optional display name, e.g. `BYU 590R Monorepo`.                                                                                                                                                                                                                   |
| `MAILGUN_DOMAIN`                                                                             | B      | Mailgun sending domain. Use the sandbox domain locally; use the verified prod domain on EC2.                                                                                                                                                                       |
| `MAILGUN_SECRET`                                                                             | B      | Mailgun private API key from Sending → Domain settings → API keys.                                                                                                                                                                                                 |
| `MAILGUN_ENDPOINT`                                                                           | B      | `api.mailgun.net` (host only; Laravel adds `https://`).                                                                                                                                                                                                            |
| **C) AWS credentials**                                                                       |        |                                                                                                                                                                                                                                                                    |
| `AWS_ACCESS_KEY_ID`                                                                          | C      | Use your AWS IAM credentials (e.g. from `aws configure` or AWS Console). Same as used for Terraform or a deploy-only IAM user.                                                                                                                                     |
| `AWS_SECRET_ACCESS_KEY`                                                                      | C      | Same as above.                                                                                                                                                                                                                                                     |
| `AWS_REGION` or `AWS_DEFAULT_REGION`                                                         | C      | Region (e.g. `us-west-1`). Can match Terraform `aws_region`.                                                                                                                                                                                                       |
| **Manual (not A/B/C)**                                                                       |        |                                                                                                                                                                                                                                                                    |
| `EC2_SSH_PRIVATE_KEY`                                                                        | Manual | Copy the contents of `~/.ssh/<key_name>.pem` (e.g. `byu-590r.pem`) **after** the EC2 instance exists. Do not commit or put in Terraform/backend .env.                                                                                                              |

**How to get the SSH private key (Manual):**

```bash
cat ~/.ssh/byu-590r.pem
```

Copy the entire output (including the `-----BEGIN` and `-----END` lines) and paste it as the value for `EC2_SSH_PRIVATE_KEY` in GitHub secrets.

## Workflows

### Backend Workflow (`backend-deploy.yml`)

- **Triggers**: Push/PR to main branch when files in `backend/` change
- **Jobs**:
  1. **Test**: Runs PHP tests using PHPUnit
  2. **Deploy**: Deploys to EC2 (only on main branch)

### Frontend Workflow (`frontend-deploy.yml`)

- **Triggers**: Push/PR to main branch when files in `web-app/` change
- **Jobs**:
  1. **Test**: Runs Angular tests and linting
  2. **Deploy**: Builds and deploys to EC2 (only on main branch)

## Deployment Process

1. **Backend Deployment**:
   - Copies backend files to EC2
   - Installs PHP dependencies via Composer
   - Configures environment variables
   - Runs database migrations
   - Restarts Laravel service

2. **Frontend Deployment**:
   - Builds Angular application
   - Copies built files to EC2
   - Updates Nginx configuration
   - Restarts Nginx service

## Manual Deployment

If you need to deploy manually:

```bash
# Backend
cd devops
chmod +x deploy-real-apps.sh
./deploy-real-apps.sh

# Or use the individual deployment scripts
```

## Troubleshooting

### Check Deployment Status

```bash
# SSH into your EC2 instance
ssh -i ~/.ssh/byu-590r.pem ubuntu@YOUR_EC2_IP

# Check Laravel service status
sudo systemctl status byu-590r-laravel

# Check Nginx status
sudo systemctl status nginx

# Check application logs
tail -f /var/www/byu-590r/backend/storage/logs/laravel.log
```

### View GitHub Actions Logs

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Click on the workflow run you want to inspect
4. Click on the job to see detailed logs

## Security Notes

- The EC2 instance is configured with a security group that only allows:
  - SSH (port 22) from anywhere
  - HTTP (port 80) from anywhere
  - HTTPS (port 443) from anywhere
- All outbound traffic is allowed for dependency downloads
- Database is only accessible from localhost
- SSH key authentication is used instead of passwords
