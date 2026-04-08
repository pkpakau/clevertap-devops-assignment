# Partial backend config — values passed via -backend-config flags at init time
# Example:
#   terraform init \
#     -backend-config="bucket=tf-state-prod-us-east-1" \
#     -backend-config="key=clevertap/terraform.tfstate" \
#     -backend-config="region=us-east-1" \
#     -backend-config="dynamodb_table=tf-locks-prod"

terraform {
  backend "s3" {
    encrypt = true
    # bucket, key, region, dynamodb_table passed via CLI flags
    # so the same code works for dev/staging/prod without modification
  }
}
