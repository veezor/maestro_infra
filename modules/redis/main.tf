locals {
  map_app_id = tomap(var.sg_ids)
}

resource "aws_security_group" "redis" {
  name   = format("%s-%s-%s-redis", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = var.aws_vpc_id
}

resource "aws_security_group_rule" "app_inbound" {
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = local.map_app_id[var.project].app_security_group_id
}

resource "aws_security_group_rule" "codebuild_inbound" {
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = local.map_app_id[var.project].codebuild_security_group_id
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = format("%s-%s-redis-subnets", "${var.project}", "${var.environment}")
  subnet_ids = [var.subnet_ids[0], var.subnet_ids[1], var.subnet_ids[2]]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = format("%s-%s-%s-cluster", "${var.owner}", "${var.project}", "${var.environment}")
  engine               = var.engine
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  parameter_group_name = var.parameter_group
  engine_version       = var.engine_version
  port                 = var.port
  security_group_ids   = [ aws_security_group.redis.id ]
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
}