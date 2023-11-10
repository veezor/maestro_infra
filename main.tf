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
  aws_iam_role              = module.role[each.key].codebuild_role_arn
  aws_public_subnets        = module.vpc.aws_public_subnets
  aws_private_subnets       = module.vpc.aws_public_subnets
  aws_vpc_id                = module.vpc.aws_vpc_id
}

module "rds" {
  source                    = "./modules/rds"
  for_each = {
    for project in var.projects:  project.name => project
    if project.create_rds == true
  }

  project                       = each.value.name
  owner                         = var.owner
  environment                   = var.environment
  rds_engine                    = each.value.rds_engine
  rds_engine_version            = each.value.rds_engine_version
  rds_availability_zones        = each.value.rds_availability_zones
  rds_master_username           = each.value.rds_master_username
  rds_master_password           = each.value.rds_master_password
  rds_backup_retention_period   = each.value.rds_backup_retention_period
  rds_preferred_backup_window   = each.value.rds_preferred_backup_window
  number_of_instances           = each.value.number_of_instances
  aws_vpc_id                    = module.vpc.aws_vpc_id
  app_id                        = module.codebuild.security_group_id
}