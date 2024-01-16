locals {
  snapshot_date = element(split(":", timestamp()), 0)
}

resource "aws_security_group" "db" {
  name   = format("%s-%s-%s-db", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = var.aws_vpc_id
}

resource "aws_security_group_rule" "db_inbound" {
  type                     = "ingress"
  from_port                = aws_rds_cluster_instance.instances[0].port
  to_port                  = aws_rds_cluster_instance.instances[0].port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.app_security_group_id
}

resource "aws_db_subnet_group" "sg" {
  name       = format("%s-%s-%s-subnet-group", "${var.owner}", "${var.project}", "${var.environment}")
  subnet_ids = var.private_subnet_ids
}

resource "aws_rds_cluster_instance" "instances" {
  count              = 1
  identifier         = format("%s-%s", "${var.identifier}", "${count.index}")
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version
  apply_immediately  = var.apply_immediately
}

resource "aws_rds_cluster" "cluster" {
  cluster_identifier        = var.identifier
  engine                    = var.engine
  engine_version            = var.engine_version
  database_name             = var.project
  db_subnet_group_name      = aws_db_subnet_group.sg.name
  master_username           = var.master_username
  master_password           = var.master_password
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = format("%s-%s-%s-cluster-%s", "${var.owner}", "${var.project}", "${var.environment}", "${local.snapshot_date}")
}

output "db-password" {
  value = aws_rds_cluster.cluster.master_password
}