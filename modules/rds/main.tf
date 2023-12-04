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

resource "aws_rds_cluster_instance" "instances" {
  count              = 1
  identifier         = format("%s-%s-%s-instance%s", "${var.owner}", "${var.project}", "${var.environment}", "${count.index}")
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = "db.t4g.medium"
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version
}

resource "aws_rds_cluster" "cluster" {
  cluster_identifier        = format("%s-%s-%s-cluster", "${var.owner}", "${var.project}", "${var.environment}")
  engine                    = var.engine
  engine_version            = var.engine_version
  database_name             = var.project
}

output "db-password" {
  value = aws_rds_cluster.cluster.master_password
}