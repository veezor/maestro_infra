locals {
  subnet_cidrs = cidrsubnets(aws_vpc.vpc.cidr_block, 8, 8, 8, 8, 8, 8)

  subnet_ipv6_cidrs = var.ip_type == "ipv6" ? cidrsubnets(aws_vpc.vpc.ipv6_cidr_block, 8, 8, 8, 8, 8, 8) : null
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  assign_generated_ipv6_cidr_block = var.ip_type == "ipv6" ? true : false


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
  ipv6_cidr_block = var.ip_type == "ipv6" ? local.subnet_ipv6_cidrs[each.key] : null
  assign_ipv6_address_on_creation = var.ip_type == "ipv6" ? true : false

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
  ipv6_cidr_block = var.ip_type == "ipv6" ? local.subnet_ipv6_cidrs[each.key + 3] : null
  assign_ipv6_address_on_creation = var.ip_type == "ipv6" ? true : false

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
    ipv6_cidr_block = "::/0"
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
    ipv6_cidr_block = "::/0"
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

resource "aws_security_group" "app" {
  name   = format("%s-%s-%s-app", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "lb" {
  name   = format("%s-%s-%s-lb", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "codebuild" {
  name   = format("%s-%s-%s-codebuild", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "app_inbound_lb_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "app_outbound_all_traffic" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  security_group_id        = aws_security_group.app.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "app_outbound_ipv6_all_traffic" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  security_group_id        = aws_security_group.app.id
  ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "lb_inbound_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "lb_inbound_ipv6_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "lb_inbound_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "lb_inbound_ipv6_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "lb_outbound_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.lb.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "lb_outbound_ipv6_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.lb.id
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "codebuild_outbound_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.codebuild.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "codebuild_outbound_ipv6_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.codebuild.id
  ipv6_cidr_blocks  = ["::/0"]
}

output "sg_lb_id" {
  value = aws_security_group.lb.id
}

output "sg_app_id" {
  value = aws_security_group.app.id
}

output "sg_codebuild_id" {
  value = aws_security_group.codebuild.id
}

output "aws_subnets" {
  value = [aws_subnet.private_subnets[0].id, aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
}

output "aws_vpc_id" {
  value = aws_vpc.vpc.id
}