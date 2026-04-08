#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap — run ONCE per AWS account before terraform init
#
# Creates:
#   - S3 buckets for terraform state (one per region)
#   - DynamoDB table for state locking (one per account)
#
# Usage:
#   export AWS_PROFILE=dev   # or set credentials via env vars
#   ./bootstrap.sh dev
#   ./bootstrap.sh staging
#   ./bootstrap.sh prod
#
# Run us-east-1 first, then ap-south-1 — same account, same DynamoDB table
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENV=${1:?"Usage: ./bootstrap.sh <dev|staging|prod>"}

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo "ERROR: environment must be dev, staging, or prod"
  exit 1
fi

REGIONS=("us-east-1" "ap-south-1")
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Bootstrapping Terraform state backend for ENV=${ENV} ACCOUNT=${ACCOUNT_ID}"

# ─────────────────────────────────────────
# S3 Buckets — one per region
# ─────────────────────────────────────────
for REGION in "${REGIONS[@]}"; do
  BUCKET="tf-state-${ENV}-${REGION}"
  echo "Creating S3 bucket: ${BUCKET} in ${REGION}"

  if aws s3api head-bucket --bucket "${BUCKET}" --region "${REGION}" 2>/dev/null; then
    echo "  → already exists, skipping"
  else
    if [ "${REGION}" == "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${BUCKET}" \
        --region "${REGION}"
    else
      aws s3api create-bucket \
        --bucket "${BUCKET}" \
        --region "${REGION}" \
        --create-bucket-configuration LocationConstraint="${REGION}"
    fi

    # Enable versioning — so we can recover from bad applies
    aws s3api put-bucket-versioning \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --versioning-configuration Status=Enabled

    # Enable encryption at rest
    aws s3api put-bucket-encryption \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }]
      }'

    # Block all public access
    aws s3api put-public-access-block \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    echo "  → created and hardened"
  fi
done

# ─────────────────────────────────────────
# DynamoDB Table — one per account (used by both regions)
# ─────────────────────────────────────────
TABLE="tf-locks-${ENV}"
PRIMARY_REGION="us-east-1"

echo "Creating DynamoDB table: ${TABLE} in ${PRIMARY_REGION}"

if aws dynamodb describe-table --table-name "${TABLE}" --region "${PRIMARY_REGION}" 2>/dev/null; then
  echo "  → already exists, skipping"
else
  aws dynamodb create-table \
    --table-name "${TABLE}" \
    --region "${PRIMARY_REGION}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Environment,Value="${ENV}" Key=ManagedBy,Value=bootstrap

  aws dynamodb wait table-exists \
    --table-name "${TABLE}" \
    --region "${PRIMARY_REGION}"

  echo "  → created"
fi

echo ""
echo "Bootstrap complete for ENV=${ENV}"
echo ""
echo "Now run terraform init with:"
echo "  terraform init \\"
echo "    -backend-config=\"bucket=tf-state-${ENV}-us-east-1\" \\"
echo "    -backend-config=\"key=clevertap/terraform.tfstate\" \\"
echo "    -backend-config=\"region=us-east-1\" \\"
echo "    -backend-config=\"dynamodb_table=tf-locks-${ENV}\""
