terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "devsecops-dev-admin"
}

# -------------------------------------------------------------------
# Terraform state bucket
# -------------------------------------------------------------------

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "secure-software-supply-chain"
    Purpose   = "terraform-state"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "retain-state-history"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.terraform_state
  ]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

# -------------------------------------------------------------------
# S3 server access logging destination bucket
# -------------------------------------------------------------------

resource "aws_s3_bucket" "logging" {
  bucket = "${var.state_bucket_name}-access-logs"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "secure-software-supply-chain"
    Purpose   = "terraform-state-access-logs"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "logging" {
  bucket = aws_s3_bucket.logging.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "logging" {
  statement {
    sid    = "S3ServerAccessLogsPolicy"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.logging.arn}/state-access/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.terraform_state.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}


resource "aws_s3_bucket_policy" "logging" {
  bucket = aws_s3_bucket.logging.id
  policy = data.aws_iam_policy_document.logging.json
}


resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "state-access/"

  depends_on = [
    aws_s3_bucket_policy.logging
  ]
}

resource "aws_s3_bucket_versioning" "logging" {
  bucket = aws_s3_bucket.logging.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.logging
  ]
}

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Project   = "secure-software-supply-chain"
    Purpose   = "terraform-state-encryption"
    ManagedBy = "Terraform"
  }
}

