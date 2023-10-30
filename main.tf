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
  source         = "./modules/vpc"
  project        = var.project
  owner          = var.owner
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
  ip_type = var.ip_type
}

module "role" {
  source         = "./modules/role"
  project        = var.project
  owner          = var.owner
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
  region         = var.region
}

module "codebuild" {
  source                    = "./modules/codebuild"
  project                   = var.project
  owner                     = var.owner
  environment               = var.environment
  repository_branch         = var.repository_branch
  code_provider             = var.code_provider
  repository_url            = var.repository_url
  maestro_image             = var.maestro_image
  aws_iam_role              = module.role.role_arn
  aws_security_group_lb     = module.vpc.sg_lb_id
  aws_security_group_app    = module.vpc.sg_app_id
  aws_security_group_cb     = module.vpc.sg_codebuild_id
  aws_subnets               = module.vpc.aws_subnets
  aws_vpc_id                = module.vpc.aws_vpc_id
}