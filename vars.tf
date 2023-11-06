variable projects {
  type = list(object({
    name = string
    code_provider = string
    repository_url = string
    repository_branch = string
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

variable "engine" {
  type = string
}

variable "engine_version" {
  type = string
}

variable "node_type" {
  type = string
}

variable "num_cache_nodes" {
  type = string
}

variable "parameter_group" {
  type = string
}

variable "port" {
  type = string
}

variable "maestro_image" {
  type = string
}

variable "create_redis" {
  type = string
}