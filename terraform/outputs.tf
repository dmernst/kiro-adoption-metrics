output "kiro_report_s3_uri" {
  description = "Paste into Kiro console > Settings > Kiro user activity report > Manage > S3 URI"
  value       = "s3://${aws_s3_bucket.report.bucket}/${var.report_prefix}/"
}

output "crawler_name" {
  description = "Run once after the first report lands, or wait for the schedule"
  value       = aws_glue_crawler.report.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.kiro.name
}

output "glue_database" {
  value = aws_glue_catalog_database.kiro.name
}
