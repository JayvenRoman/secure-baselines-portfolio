############################
# Terraform + Providers
############################
terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

############################
# Minimal secure bits
############################

# 1. VPC with one public subnet
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "demo-sec-vpc"
  cidr = "172.31.0.0/16"

  # Use a real AZ name in the chosen region
  azs            = ["us-east-2a"]
  public_subnets = ["172.31.1.0/24"]

  enable_dns_hostnames = true
  single_nat_gateway   = true

  tags = {
    Project = "secure-demo"
  }
}

# 2. Random suffix so S3 bucket name is globally unique
resource "random_string" "sfx" {
  length  = 6
  special = false
  upper   = false # ensures only lowercase letters & digits
}

resource "aws_s3_bucket" "trail_logs" {
  bucket        = "demo-sec-trail-${random_string.sfx.result}"
  force_destroy = true
}

resource "aws_cloudtrail" "trail" {
  name                  = "demo-sec-trail"
  s3_bucket_name        = aws_s3_bucket.trail_logs.id
  is_multi_region_trail = true

  depends_on = [
    aws_s3_bucket_policy.trail_logs
  ]
}


############################
# 3. Bucket policy for CloudTrail
############################
data "aws_iam_policy_document" "trail_logs" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail_logs.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = data.aws_iam_policy_document.trail_logs.json
}

# 4. GuardDuty detector
resource "aws_guardduty_detector" "gd" {
  enable = true
}

############################
# Helpful outputs
############################
output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "trail_arn" {
  value = aws_cloudtrail.trail.arn
}

