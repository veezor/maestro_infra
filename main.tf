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
  source        = "./modules/vpc"
  project       = var.project
  owner         = var.owner
  environment   = var.environment
  vpc_cidr_block        = var.vpc_cidr_block
}

module "role" {
  source        = "./modules/role"
  project       = var.project
  owner         = var.owner
  environment   = var.environment
  vpc_cidr_block        = var.vpc_cidr_block
  region        = var.region
}

module "codebuild" {
  source        = "./modules/codebuild"
  project       = var.project
  owner         = var.owner
  environment   = var.environment
  repository_branch = var.repository_branch
  code_provider = var.code_provider
  repository_url = var.repository_url
  maestro_image = var.maestro_image
}