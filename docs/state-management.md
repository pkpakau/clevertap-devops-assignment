# Section 1b: State & Drift Management

Based on my experience this is how I'd structure it.

## Terraform State Structure

Mostly we create modules for components and import them in main.tf.
Single codebase, per-env tfvars. No separate directories per environment — that's just copy-paste waiting to drift.

State backend: S3 with DynamoDB locking.

```
S3 bucket per account (not per region)
  tf-state-dev-us-east-1
  tf-state-dev-ap-south-1
  tf-state-staging-us-east-1
  tf-state-prod-us-east-1
  tf-state-prod-ap-south-1

  dev/us-east-1/terraform.tfstate
  dev/ap-south-1/terraform.tfstate

DynamoDB lock table per account
  tf-locks-dev
  tf-locks-staging
  tf-locks-prod
```

Bucket hardening:
- Versioning enabled — so you can roll back a bad state file
- Encryption at rest (AES256)
- Block all public access
- Bucket policy: only the terraform-apply-role for that account can write

Dev and prod buckets managed by different IAM roles — dev engineer can't accidentally touch prod state.

## Multi-team Setup

For teams contributing to same codebase:
1. Subfolders per owning team inside state key if needed
2. DynamoDB locking prevents concurrent applies — if two people run apply simultaneously, second one waits
3. CODEOWNERS file — platform team reviews terraform/modules/, individual teams review their own tfvars

Never share state files across accounts. Each account is fully isolated.

## Drift Detection

Scheduled GitHub Actions workflow (`terraform-drift.yml`) runs every 6 hours.
Runs `terraform plan -detailed-exitcode` against all env/region combos.
Exit code 2 = drift detected → Slack alert to on-call channel.

On-call engineers own the decision — review CloudTrail first (who changed what), then either:
- Raise a PR to update terraform to match reality (if change was intentional)
- Raise a PR to revert the manual change (if it was accidental)
- Import the resource if it was created outside terraform and needs to stay

Never auto-apply drift remediation in prod. Always a human decision.

## Most Important — CloudTrail

Enable CloudTrail in every account. Without this, post-incident RCA is guesswork.
When drift is detected in prod you need to know: who made the change, from which IP, at what time.
CloudTrail gives you that. Ship logs to a separate security account so they can't be tampered with.
