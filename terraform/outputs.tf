# -----------------------------------------------------------------------------
# GitHub Actions – copy these into repo Settings → Secrets and variables → Actions
# Run: terraform output github_actions_secrets
# Or:  terraform output -json github_actions_secrets
# -----------------------------------------------------------------------------
output "github_actions_secrets" {
  description = "Secret names and values for GitHub Actions (Settings → Secrets and variables → Actions)"
  value = {
    EC2_HOST      = aws_eip.byu_590r_eip.public_ip
    S3_BUCKET     = aws_s3_bucket.prod.id # Production bucket for deployments
    S3_BUCKET_DEV = aws_s3_bucket.dev.id  # Dev bucket (e.g. for local .env)
    INSTANCE_ID   = aws_instance.byu_590r_server.id
  }
}

# Same values as a single block for copy-paste
output "github_actions_copy_paste" {
  description = "One block to copy into GitHub Actions secrets"
  value       = <<-EOT
    EC2_HOST       = ${aws_eip.byu_590r_eip.public_ip}
    S3_BUCKET      = ${aws_s3_bucket.prod.id}
    S3_BUCKET_DEV  = ${aws_s3_bucket.dev.id}
    INSTANCE_ID    = ${aws_instance.byu_590r_server.id}
  EOT
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.byu_590r_server.id
}

output "instance_private_ip" {
  description = "EC2 instance private IP address"
  value       = aws_instance.byu_590r_server.private_ip
}

output "elastic_ip" {
  description = "Elastic IP address"
  value       = aws_eip.byu_590r_eip.public_ip
}

output "allocation_id" {
  description = "Elastic IP allocation ID"
  value       = aws_eip.byu_590r_eip.id
}

output "ec2_host" {
  description = "EC2 host (Elastic IP) - use this for GitHub Actions EC2_HOST secret"
  value       = aws_eip.byu_590r_eip.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.byu_590r_sg.id
}

output "s3_bucket_dev" {
  description = "S3 bucket name for development environment"
  value       = aws_s3_bucket.dev.id
}

output "s3_bucket_prod" {
  description = "S3 bucket name for production environment (use for GitHub Actions S3_BUCKET secret)"
  value       = aws_s3_bucket.prod.id
}

output "s3_bucket" {
  description = "S3 bucket name (defaults to prod for backward compatibility)"
  value       = aws_s3_bucket.prod.id
}

output "frontend_url" {
  description = "Frontend URL (Caddy HTTPS via sslip.io)"
  value       = "https://${aws_eip.byu_590r_eip.public_ip}.sslip.io"
}

output "frontend_url_http" {
  description = "Frontend URL over HTTP on the Elastic IP (Caddy :80)"
  value       = "http://${aws_eip.byu_590r_eip.public_ip}"
}

output "backend_api_url" {
  description = "Backend API URL (Caddy HTTPS via sslip.io)"
  value       = "https://${aws_eip.byu_590r_eip.public_ip}.sslip.io/api/hello"
}

output "backend_api_url_direct" {
  description = "Backend API URL on Apache :4444 (legacy HTTP)"
  value       = "http://${aws_eip.byu_590r_eip.public_ip}:4444/api/hello"
}

output "summary" {
  description = "Summary of created resources"
  value       = <<-EOT
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║                    🚀 INFRASTRUCTURE SETUP COMPLETE 🚀                    ║
    ║                                                                              ║
    ║  Your BYU 590R infrastructure is now ready for deployment!                ║
    ║  Both DEV and PROD S3 buckets have been created.                            ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    Server Details:
      Instance ID: ${aws_instance.byu_590r_server.id}
      Elastic IP: ${aws_eip.byu_590r_eip.public_ip}
      EC2 Host: ${aws_eip.byu_590r_eip.public_ip}
      S3 Bucket (DEV): ${aws_s3_bucket.dev.id}
      S3 Bucket (PROD): ${aws_s3_bucket.prod.id}
    
    📋 Next Steps - Update GitHub Actions Secrets:
    
      1. Go to your GitHub repository settings:
         https://github.com/BYU-IS-590R-Christiansen/byu-590r-monorepo/settings/secrets/actions
      
      2. Update the EC2_HOST secret with the new Elastic IP:
         Secret Name: EC2_HOST
         Secret Value: ${aws_eip.byu_590r_eip.public_ip}
      
      3. Update the S3 bucket secret in GitHub Actions (PRODUCTION ONLY):
         Secret Name: S3_BUCKET
         Secret Value: ${aws_s3_bucket.prod.id}
         (This is the PRODUCTION bucket for GitHub Actions deployment)
      
      4. For local development, add the DEV bucket to your backend/.env file:
         Add this line to backend/.env:
         S3_BUCKET=${aws_s3_bucket.dev.id}
         (This is the DEV bucket for local development only)
      
      5. If you don't have EC2_SSH_PRIVATE_KEY secret yet, add it:
         Secret Name: EC2_SSH_PRIVATE_KEY
         Secret Value: (Copy the contents of ~/.ssh/${var.key_name}.pem)
      
      6. To get your SSH private key content, run:
         cat ~/.ssh/${var.key_name}.pem
      
      7. Copy the entire output (including -----BEGIN and -----END lines)
         and paste it as the value for EC2_SSH_PRIVATE_KEY
      
      8. Once secrets are updated, push changes to main branch to trigger deployment
      
      🚀 Your application will be available at:
         Frontend (HTTPS): https://${aws_eip.byu_590r_eip.public_ip}.sslip.io
         Backend API (HTTPS): https://${aws_eip.byu_590r_eip.public_ip}.sslip.io/api/hello
         Legacy HTTP API: http://${aws_eip.byu_590r_eip.public_ip}:4444/api/hello
      
      📝 Generated Values Summary:
         EC2_HOST: ${aws_eip.byu_590r_eip.public_ip}
         S3_BUCKET (PROD - for GitHub Actions): ${aws_s3_bucket.prod.id}
         S3_BUCKET_DEV (for local .env file): ${aws_s3_bucket.dev.id}
         INSTANCE_ID: ${aws_instance.byu_590r_server.id}
  EOT
}
