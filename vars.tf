variable projects {
  type = list(object({
    name = string
    code_provider = string
    repository_url = string
    repository_branch = string
    elasticsearch = object({
      create_elasticsearch = bool
      domain_name = string
      version = string
      instance_type = string
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