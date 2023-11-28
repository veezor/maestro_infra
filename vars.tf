variable projects {
  type = list(object({
    name = string
    code_provider = string
    repository_url = string
    repository_branch = string
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