variable "region" {
  description = "Region of your Kiro profile. The report bucket must be in this Region."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix for resource names."
  type        = string
  default     = "kiro-adoption"
}

variable "report_prefix" {
  description = "Prefix (subfolder) Kiro writes under. Kiro cannot write to the bucket root."
  type        = string
  default     = "kiro-reports"
}

variable "glue_database_name" {
  type    = string
  default = "kiro_usage"
}

variable "crawler_schedule" {
  description = "Daily, after Kiro's 02:00 UTC report cycle."
  type        = string
  default     = "cron(30 3 * * ? *)"
}

variable "athena_results_retention_days" {
  type    = number
  default = 30
}
