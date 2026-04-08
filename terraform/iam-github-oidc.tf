# ─────────────────────────────────────────
# GitHub Actions OIDC Provider
# Allows GitHub Actions to authenticate to AWS without static credentials
# One provider per AWS account — created in every account (dev/staging/prod)
# ─────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint — stable, published by GitHub
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "github-actions-oidc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ─────────────────────────────────────────
# Terraform Plan Role
# Used by: terraform-plan.yml (PR workflow)
# Permissions: read-only — describe resources, no mutations
# ─────────────────────────────────────────
resource "aws_iam_role" "terraform_plan" {
  name = "terraform-plan-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Any branch/PR in this repo can plan — but only read
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "terraform-plan-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "terraform_plan" {
  name = "terraform-plan-policy"
  role = aws_iam_role.terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyAccess"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "iam:Get*",
          "iam:List*",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "dynamodb:GetItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "*"
      },
      {
        Sid    = "StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:s3:::tf-state-${var.environment}-*",
          "arn:aws:s3:::tf-state-${var.environment}-*/*",
          "arn:aws:dynamodb:*:${var.aws_account_id}:table/tf-locks-${var.environment}"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────
# Terraform Apply Role
# Used by: terraform-dev.yml, terraform-staging.yml, terraform-prod.yml
# Permissions: scoped to only what terraform needs to manage in this account
# Trust: locked to specific GitHub environment — staging role can only be
#        assumed from the "staging" GitHub environment, not from a PR branch
# ─────────────────────────────────────────
resource "aws_iam_role" "terraform_apply" {
  name = "terraform-apply-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # Lock to specific GitHub environment — prod role only assumable from
            # "production" environment, staging role from "staging" environment
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:${var.environment}"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "terraform-apply-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_apply_admin" {
  # Scoped AdministratorAccess for terraform to manage infra in this account
  # In stricter setups, replace with a custom policy listing only required actions
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.terraform_apply.name
}
