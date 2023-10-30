variable "code_provider" {
  type = string
}
variable "repository_url" {
  type = string
}
variable "repository_branch" {
  type = string
}
variable "owner" {
  type = string
}

variable "project" {
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

variable "ip_type" {
  type = string
}

variable "maestro_image" {
  type = string
}