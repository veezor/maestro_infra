terraform {
  backend "s3" {}
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

module "creator" {
  source = "./modules/creator"

  # Common
  owner              = var.owner
  environment        = var.environment
  vpc_cidr_block     = var.vpc_cidr_block
  vpc_id             = var.vpc_id
}

module "vpc" {
  source = "./modules/vpc"

  # Common
  owner              = var.owner
  environment        = var.environment
  vpc_cidr_block     = var.vpc_cidr_block
  subnets_cidr_block = local.subnet_cidrs
  vpc_id             = module.creator.aws_vpc_id
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
  elasticsearch       = each.value.elasticsearch
  
  # Common
  owner               = var.owner
  environment         = var.environment
  maestro_image       = var.maestro_image
  aws_public_subnets  = module.vpc.aws_public_subnets
  aws_private_subnets = module.vpc.aws_private_subnets
  aws_vpc_id          = module.creator.aws_vpc_id
  vpc_cidr_block      = var.vpc_cidr_block
  region              = var.region
}