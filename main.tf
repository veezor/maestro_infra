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

module "elasticsearch" {
  source                    = "./modules/elasticsearch"
  for_each = {
    for project in var.projects:  project.name => project
    if project.elasticsearch.create_elasticsearch == true
  }

  project                   = each.value.name
  owner                     = var.owner
  environment               = var.environment
  domain_name               = each.value.elasticsearch.domain_name
  instance_type             = each.value.elasticsearch.instance_type
  elastichsearch_version    = each.value.elasticsearch.version
  ebs_enabled               = each.value.elasticsearch.ebs_enabled
  volume_size               = each.value.elasticsearch.volume_size
}