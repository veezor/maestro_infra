variable projects {
  type = list(object({
    name = string
    code_provider = string
    repository_url = string
    repository_branch = string
    create_rds = bool
    rds_engine = string
    rds_engine_version = string
    rds_availability_zones = list(string)
    rds_master_username = string
    rds_master_password = string
    rds_backup_retention_period = string
    rds_preferred_backup_window = string
    number_of_instances = number
  }))
}

variable "owner" {
  type = string
}

variable "environment" {
  default = "staging"
  type = string
}

variable "region" {
  default = "us-east-1"
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "maestro_image" {
  type = string
}