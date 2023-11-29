terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.17"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  subnet_cidrs = cidrsubnets(var.vpc_cidr_block, 8, 8, 8, 8, 8, 8)
}

module "vpc" {
  source = "./modules/vpc"

  # Common
  owner              = var.owner
  environment        = var.environment
  vpc_cidr_block     = var.vpc_cidr_block
  subnets_cidr_block = local.subnet_cidrs
}
 
module "projects" {
  source              = "./modules/projects"
  for_each            = {for project in var.projects: project.project_name => project}

  # Project
  project_name        = each.value.project_name
  code_provider       = each.value.code_provider
  repository_url      = each.value.repository_url
  repository_branch   = each.value.repository_branch
  databases           = each.value.databases
  
  # Common
  owner               = var.owner
  environment         = var.environment
  maestro_image       = var.maestro_image
  aws_public_subnets  = module.vpc.aws_public_subnets
  aws_private_subnets = module.vpc.aws_private_subnets
  aws_vpc_id          = module.vpc.aws_vpc_id
  vpc_cidr_block      = var.vpc_cidr_block
  region              = var.region
}

module "s3" {
  source                    = "./modules/s3"
  for_each = {
    for project in var.projects:  project.name => project
    if project.s3.create_s3 == true
  }

  project                   = each.value.name
  owner                     = var.owner
  environment               = var.environment
  static_site               = each.value.s3.static_site
  number_of_buckets         = each.value.s3.number_of_buckets
  bucket_name               = each.value.s3.specify_name
}