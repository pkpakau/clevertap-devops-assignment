# ─────────────────────────────────────────
# IRSA Role — GitHub Actions App Deploy
# Used by: app-pr.yml, app-staging.yml, app-prod.yml
# Allows GitHub Actions to push ECR images and deploy to EKS
# ─────────────────────────────────────────
resource "aws_iam_role" "app_deploy" {
  name = "app-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github_actions.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # PRs deploy to dev, staging/prod locked to their GitHub environments
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = {
    Name      = "app-deploy-role"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name = "app-deploy-policy"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:*:${var.aws_account_id}:repository/event-ingestion"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:*:${var.aws_account_id}:cluster/clevertap-*"
      }
    ]
  })
}

# ECR repository for the app
resource "aws_ecr_repository" "event_ingestion" {
  name                 = "event-ingestion"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true   # ECR native scan as extra layer alongside Trivy
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "event-ingestion"
  }
}

# Lifecycle policy — keep last 20 tagged images, expire untagged after 7 days
resource "aws_ecr_lifecycle_policy" "event_ingestion" {
  repository = aws_ecr_repository.event_ingestion.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ─────────────────────────────────────────
# IRSA Role — Event Ingestion Service (pod identity)
# Used by: event-ingestion pods running in EKS
# Least-privilege: only what the service actually needs
# ─────────────────────────────────────────
resource "aws_iam_role" "event_ingestion" {
  name = "event-ingestion-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider_url}:sub" = "system:serviceaccount:${var.environment}:event-ingestion-sa"
          "${module.eks.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name        = "event-ingestion-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "event_ingestion" {
  name = "event-ingestion-${var.environment}-policy"
  role = aws_iam_role.event_ingestion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3EventsWrite"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject"]
        # Scoped to events bucket for this environment only
        Resource = "arn:aws:s3:::clevertap-events-${var.environment}/*"
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Only secrets for this service in this environment
        Resource = "arn:aws:secretsmanager:${var.region}:${var.aws_account_id}:secret:/clevertap/${var.environment}/*"
      }
    ]
  })
}
