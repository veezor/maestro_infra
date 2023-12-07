variable projects {
  type = list(object({
    name = string
    code_provider = string
    repository_url = string
    repository_branch = string
    rds = object({
      create_rds = bool
      engine = string
      engine_version = string
      availability_zones = list(string)
      master_username = string
      master_password = string
      backup_retention_period = string
      preferred_backup_window = string
      instance_class = string
      number_of_instances = number 
    })
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