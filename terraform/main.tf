# Kiro adoption metrics: the same resources as cloudformation/kiro-adoption-metrics.yaml.
# Deploy in the account and Region where Kiro users are subscribed (the Region of your Kiro profile).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  report_path = "${var.report_prefix}/AWSLogs/${local.account_id}/KiroLogs/user_report/"
}

# ---------- Report bucket (Kiro writes here) ----------
resource "aws_s3_bucket" "report" {
  bucket_prefix = "${var.name}-report-"
  lifecycle { prevent_destroy = true } # holds your history
}

resource "aws_s3_bucket_public_access_block" "report" {
  bucket                  = aws_s3_bucket.report.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "report" {
  bucket = aws_s3_bucket.report.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "report" {
  bucket = aws_s3_bucket.report.id
  versioning_configuration { status = "Enabled" }
}

# SSE-S3. SSE-KMS would also need a key policy for the Kiro service principal.
resource "aws_s3_bucket_server_side_encryption_configuration" "report" {
  bucket = aws_s3_bucket.report.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

data "aws_iam_policy_document" "report" {
  statement {
    sid       = "KiroLogsWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.report.arn}/${var.report_prefix}/*"]
    principals {
      type        = "Service"
      identifiers = ["q.amazonaws.com"] # yes, still "q"
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:codewhisperer:${var.region}:${local.account_id}:*"] # and still "codewhisperer"
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.report.arn, "${aws_s3_bucket.report.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "report" {
  bucket     = aws_s3_bucket.report.id
  policy     = data.aws_iam_policy_document.report.json
  depends_on = [aws_s3_bucket_public_access_block.report]
}

# ---------- Athena results bucket ----------
resource "aws_s3_bucket" "athena_results" {
  bucket_prefix = "${var.name}-athena-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    id     = "ExpireQueryResults"
    status = "Enabled"
    filter {}
    expiration { days = var.athena_results_retention_days }
  }
}

# ---------- Glue catalog and crawler ----------
resource "aws_glue_catalog_database" "kiro" {
  name        = var.glue_database_name
  description = "Kiro per-user activity reports"
}

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "crawler" {
  name_prefix        = "${var.name}-crawler-"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "crawler_service" {
  role       = aws_iam_role.crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "crawler_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.report.arn}/${var.report_prefix}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.report.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.report_prefix}/*"]
    }
  }
}

resource "aws_iam_role_policy" "crawler_read" {
  name   = "ReadKiroReports"
  role   = aws_iam_role.crawler.id
  policy = data.aws_iam_policy_document.crawler_read.json
}

resource "aws_glue_crawler" "report" {
  name          = "${var.name}-report-crawler"
  role          = aws_iam_role.crawler.arn
  database_name = aws_glue_catalog_database.kiro.name
  description   = "Catalogs Kiro user_report CSVs. Model columns change daily, so the schema updates on every run."
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${aws_s3_bucket.report.bucket}/${local.report_path}"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy { recrawl_behavior = "CRAWL_EVERYTHING" }

  configuration = jsonencode({
    Version  = 1.0
    Grouping = { TableGroupingPolicy = "CombineCompatibleSchemas" }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
}

# ---------- Athena workgroup and saved queries ----------
resource "aws_athena_workgroup" "kiro" {
  name          = "${var.name}-workgroup"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
      encryption_configuration { encryption_option = "SSE_S3" }
    }
  }
}

locals {
  # Saved query name = first line of each file ("-- <name>"), the same names CloudFormation uses
  queries = {
    for f in fileset("${path.module}/../queries", "*.sql") :
    trimprefix(split("\n", file("${path.module}/../queries/${f}"))[0], "-- ") => file("${path.module}/../queries/${f}")
  }
}

resource "aws_athena_named_query" "kiro" {
  for_each  = local.queries
  name      = each.key
  database  = aws_glue_catalog_database.kiro.name
  workgroup = aws_athena_workgroup.kiro.id
  query     = each.value
}
