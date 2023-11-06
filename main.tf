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

module "vpc" {
  source = "./modules/vpc"
  owner          = var.owner
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
}

module "role" {
  source         = "./modules/role"
  for_each = {for project in var.projects:  project.name => project}

  project        = each.value.name
  owner          = var.owner
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
  region         = var.region
 }
 
module "codebuild" {
  source                    = "./modules/codebuild"
  for_each = {for project in var.projects:  project.name => project}

  project                   = each.value.name
  owner                     = var.owner
  environment               = var.environment
  repository_branch         = each.value.repository_branch
  code_provider             = each.value.code_provider
  repository_url            = each.value.repository_url
  maestro_image             = var.maestro_image
  aws_iam_role              = module.role[each.key].role_arn
  aws_public_subnets        = module.vpc.aws_public_subnets
  aws_private_subnets       = module.vpc.aws_public_subnets
  aws_vpc_id                = module.vpc.aws_vpc_id
}

module "redis" {
  count = var.create_redis == "true" ? 1 : 0
  source                    = "./modules/redis"
  project                   = var.project
  owner                     = var.owner
  environment               = var.environment
  engine                    = var.engine
  engine_version            = element(split("@", var.engine), 1)
  node_type                 = var.node_type
  num_cache_nodes           = var.num_cache_nodes
  parameter_group           = var.parameter_group
  port                      = var.port
  subnet_ids                = module.vpc.aws_subnets
}