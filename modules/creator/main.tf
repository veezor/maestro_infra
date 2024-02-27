resource "aws_vpc" "vpc" {
  count                = var.vpc_id != "" ? 0 : 1
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

output "aws_vpc_id" {
  value = var.vpc_id != "" ? var.vpc_id : aws_vpc.vpc[0].id
}