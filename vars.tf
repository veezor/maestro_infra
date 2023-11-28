variable projects {
  type = list(object({
    project_name = string
    code_provider = string
    repository_url = string
    repository_branch = string
    databases = list(object({
      identifier = string
      engine = string
      engine_version = string
      instance_class = string
      master_username = string
      master_password = string
      skip_final_snapshot = bool
    }))
    s3 = object({
      create_s3 = bool
      number_of_buckets = number
      static_site = object({
        is_static_site = bool
        index_document = string
        error_document = string
        routing_rule_condition = string
        routing_rule_redirect = string
      })
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