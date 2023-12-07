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

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnets" {
  for_each          = { for idx in range(3) : idx => true }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnets_cidr_block[each.key]
  availability_zone = data.aws_availability_zones.available.names[each.key]

  tags = {
    "Name"        = format("%s-%s-public%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each          = { for idx in range(3) : idx => true }
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.subnets_cidr_block[each.key + 3]
  availability_zone = data.aws_availability_zones.available.names[each.key]

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
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "public_rt_1" {
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
    "Name"        = format("%s-%s/%s1", "${var.owner}", "${var.environment}", "public")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "public_rt_2" {
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
    "Name"        = format("%s-%s/%s2", "${var.owner}", "${var.environment}", "public")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "public_rt_3" {
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
    "Name"        = format("%s-%s/%s3", "${var.owner}", "${var.environment}", "public")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "private_rt_1" {
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
    "Name"        = format("%s-%s/%s1", "${var.owner}", "${var.environment}", "private")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "private_rt_2" {
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
    "Name"        = format("%s-%s/%s2", "${var.owner}", "${var.environment}", "private")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "private_rt_3" {
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
    "Name"        = format("%s-%s/%s3", "${var.owner}", "${var.environment}", "private")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table_association" "public_association1" {
  count = 1
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt_1.id
}

resource "aws_route_table_association" "public_association2" {
  count = 1
  subnet_id      = aws_subnet.public_subnets[count.index + 1].id
  route_table_id = aws_route_table.public_rt_2.id
}

resource "aws_route_table_association" "public_association3" {
  count = 1
  subnet_id      = aws_subnet.public_subnets[count.index + 2].id
  route_table_id = aws_route_table.public_rt_3.id
}

resource "aws_route_table_association" "private_association1" {
  count = 1
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt_1.id
}

resource "aws_route_table_association" "private_association2" {
  count = 1
  subnet_id      = aws_subnet.private_subnets[count.index + 1].id
  route_table_id = aws_route_table.private_rt_2.id
}

resource "aws_route_table_association" "private_association3" {
  count = 1
  subnet_id      = aws_subnet.private_subnets[count.index + 2].id
  route_table_id = aws_route_table.private_rt_3.id
}

output "aws_public_subnets" {
  value = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
}

output "aws_private_subnets" {
  value = [aws_subnet.private_subnets[0].id, aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
}

output "aws_vpc_id" {
  value = aws_vpc.vpc.id
}