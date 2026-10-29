# BYU 590R Full Stack Development Monorepo

Laravel backend + Angular frontend with AWS EC2 deployment.

**Requirements:**

- AWS subscription required
- GitHub Teams subscription recommended for full functionality

**Local Development Requirements:**

- Docker & Docker Compose
- Node.js 18+ (for Angular development)
- Make (for running commands)
- AWS CLI (for EC2 deployment)

## Quick Start

### 1. Setup EC2 Server

```bash
cd devops/bash
chmod +x setup-ec2-server.sh
./setup-ec2-server.sh
```

**⚠️ Important**: After running the setup script, if you get a new EC2 IP address, you must update the production environment file:

1. Open `web-app/src/environments/environment.prod.ts`
2. Update the `apiUrl` to use your new EC2 IP address:
   ```typescript
   export const environment = {
   	production: true,
   apiUrl: "/api/",
   };
   ```
3. Commit and push the change - the frontend will be rebuilt and redeployed automatically

This is required because the production Angular app makes direct API calls (no proxy), so it needs the full URL with the correct IP address.

### 2. Configure GitHub Actions

**Copy the generated values from the setup script output** and add these secrets to your GitHub repository:

- `EC2_HOST`: Your EC2 public IP address (from setup script output)
- `S3_BUCKET`: Your unique S3 bucket name (from setup script output)
- `EC2_SSH_PRIVATE_KEY`: Contents of your SSH private key for server access
- `DB_DATABASE`: Database name for the Laravel application
- `DB_USERNAME`: Database username for MySQL connection
- `DB_PASSWORD`: Database password for MySQL connection
- `APP_DEBUG`: Laravel debug mode setting (true/false)
- `OPENAI_API_KEY`: OpenAI API key for AI features (optional)
- `AWS_ACCESS_KEY_ID`: AWS access key for AWS services
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for AWS services
- `AWS_REGION`: AWS region for AWS services
- `MAIL_MAILER`: `mailgun`
- `MAIL_FROM_ADDRESS`: Sender on the Mailgun domain (sandbox or verified prod domain)
- `MAIL_FROM_NAME`: Sender display name
- `MAILGUN_DOMAIN`: Mailgun sending domain
- `MAILGUN_SECRET`: Mailgun private API key
- `MAILGUN_ENDPOINT`: `api.mailgun.net`

#### AWS IAM Setup

1. **Create IAM User**:
   - Go to AWS Console → IAM → Users → Create User
   - Username: `byu-590r-deploy`
   - Attach policies directly

2. **Required Policies**:

   ```json
   {
   	"Version": "2012-10-17",
   	"Statement": [
   		{
   			"Effect": "Allow",
   			"Action": [
   				"ec2:RunInstances",
   				"ec2:TerminateInstances",
   				"ec2:DescribeInstances",
   				"ec2:DescribeImages",
   				"ec2:DescribeSecurityGroups",
   				"ec2:AuthorizeSecurityGroupIngress",
   				"ec2:AllocateAddress",
   				"ec2:AssociateAddress",
   				"ec2:DescribeAddresses",
   				"ec2:CreateTags",
   				"ec2:DescribeTags"
   			],
   			"Resource": "*"
   		},
   		{
   			"Effect": "Allow",
   			"Action": [
   				"s3:CreateBucket",
   				"s3:DeleteBucket",
   				"s3:ListBucket",
   				"s3:GetBucketLocation",
   				"s3:GetBucketAcl",
   				"s3:PutBucketAcl",
   				"s3:PutBucketPublicAccessBlock",
   				"s3:GetBucketPublicAccessBlock",
   				"s3:PutObject",
   				"s3:GetObject",
   				"s3:DeleteObject",
   				"s3:PutObjectAcl",
   				"s3:GetObjectAcl"
   			],
   			"Resource": ["arn:aws:s3:::byu-590r-*", "arn:aws:s3:::byu-590r-*/*"]
   		}
   	]
   }
   ```

3. **Generate Access Keys**:
   - Go to IAM → Users → `byu-590r-deploy` → Security credentials
   - Create access key → Command Line Interface (CLI)
   - Download CSV file

4. **Configure Local AWS CLI**:

   ```bash
   aws configure
   # Enter Access Key ID, Secret Access Key, Region (us-west-1), Output format (json)
   ```

5. **Add to GitHub Secrets**:
   - Repository → Settings → Secrets and variables → Actions
   - Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from CSV file
   - **Important**: Also add `EC2_HOST` and `S3_BUCKET` values from setup script output

#### OpenAI API Setup (Optional)

1. **Create OpenAI Account**:
   - Go to [platform.openai.com](https://platform.openai.com)
   - Sign up or log in to your account

2. **Add Credits/Billing**:
   - Go to Billing → Payment methods
   - Add a credit card or purchase credits
   - Minimum: $5 credit for testing
   - Recommended: $10-20 for development

3. **Generate API Key**:
   - Go to API Keys section in your OpenAI dashboard
   - Click "Create new secret key"
   - Name: `byu-590r-project`
   - Copy the key (starts with `sk-`)

4. **Add to GitHub Secrets**:
   - Repository → Settings → Secrets and variables → Actions
   - Add `OPENAI_API_KEY` with your generated key

5. **Add to Local Environment** (optional):
   ```bash
   # Add to backend/.env file
   OPENAI_API_KEY=sk-your-key-here
   ```

### 3. Deploy

Push to `main` branch - GitHub Actions will auto-deploy.

Production Angular uses same-origin `/api/` behind Caddy (`https://YOUR_EC2_IP.sslip.io`).

### 4. Verify Deployment

- **Frontend**: `https://YOUR_EC2_IP.sslip.io`
- **Backend API**: `https://YOUR_EC2_IP.sslip.io/api/hello`
- **Health Check**: `https://YOUR_EC2_IP.sslip.io/api/health`
- **S3 Test**: `https://YOUR_EC2_IP.sslip.io/api/test-s3`
- **Legacy HTTP API**: `http://YOUR_EC2_IP:4444/api/hello`

### 5. Cleanup

```bash
cd devops/bash
./teardown.sh
```

## Local Development

### Setup Environment

1. **Copy environment file**:

   ```bash
   cp backend/.env.example backend/.env
   ```

2. **Configure database settings** (optional - Docker handles this):

   ```bash
   # Edit backend/.env if needed
   DB_CONNECTION=mysql
   DB_HOST=mysql
   DB_PORT=3306
   DB_DATABASE=app_db
   DB_USERNAME=app_user
   DB_PASSWORD=app_password
   ```

3. **Start development environment**:
   ```bash
   make start
   ```

- Frontend: http://localhost:4200
- Backend API: http://localhost:8000

### Local S3 and demo book images

For local development you do **not** need AWS S3. The app uses `FILESYSTEM_DISK=local` (see `backend/.env.example`) and serves book cover images from local storage.

- **Demo images**: Place cover images in `backend/public/assets/books/` (e.g. `hp1.jpeg`, `bom.jpg` — see that directory’s README). During `make start`, `app:setup-demo-images` copies them into `storage/app/public/images/` and creates the storage link so seeded books show covers at `/storage/images/...`.
- To use real S3 locally, set `FILESYSTEM_DISK=s3` and add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `S3_BUCKET` (or `S3_BUCKET_DEV`) in `backend/.env`.

## Credits

This project was created for educational purposes for BYU IS 590R course - John Christiansen. 10/2025. All Rights Reserved
