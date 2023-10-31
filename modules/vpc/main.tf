locals {
  subnet_cidrs = cidrsubnets(aws_vpc.vpc.cidr_block, 8, 8, 8, 8, 8, 8)
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_cidrs[each.key]

  tags = {
    "Name"        = format("%s-%s-public%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_cidrs[each.key + 3]

  tags = {
    "Name"        = format("%s-%s-private%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }

}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.ig]

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_nat_gateway" "ng" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "public_rt" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  route {
    cidr_block = var.vpc_cidr_block
    gateway_id = "local" 
  }

  tags = {
    "Name"        = format("%s-%s/%s%s", "${var.owner}", "${var.environment}", "public", each.key + 1)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "private_rt" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ng.id
  }

  route {
    cidr_block = var.vpc_cidr_block
    nat_gateway_id = "local" 
  }

  tags = {
    "Name"        = format("%s-%s/%s%s", "${var.owner}", "${var.environment}", "private", each.key + 1)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table_association" "public_association" {
  for_each       = { for idx in range(3) : idx => true }
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_rt[each.key].id
}

resource "aws_route_table_association" "private_association" {
  for_each       = { for idx in range(3) : idx => true }
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.private_rt[each.key].id
}

output "aws_subnets" {
  value = [aws_subnet.private_subnets[0].id, aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
}

output "aws_vpc_id" {
  value = aws_vpc.vpc.id
}