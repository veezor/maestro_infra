locals {
  snapshot_date = element(split(":", timestamp()), 0)
  map_app_id    = tomap(var.app_id)
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
  source_security_group_id = local.map_app_id[var.project].app_security_group_id.id
}

resource "aws_rds_cluster_instance" "instances" {
  count              = var.number_of_instances
  identifier         = format("%s-%s-%s-instance%s", "${var.owner}", "${var.project}", "${var.environment}", "${count.index}")
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version
}

resource "aws_rds_cluster" "cluster" {
  cluster_identifier        = format("%s-%s-%s-cluster", "${var.owner}", "${var.project}", "${var.environment}")
  engine                    = var.engine
  engine_version            = var.engine_version
  availability_zones        = var.availability_zones
  database_name             = var.project
  master_username           = var.master_username
  master_password           = var.master_password
  backup_retention_period   = var.backup_retention_period
  preferred_backup_window   = var.preferred_backup_window
  final_snapshot_identifier = format("%s-%s-%s-cluster-%s", "${var.owner}", "${var.project}", "${var.environment}", "${local.snapshot_date}")
}