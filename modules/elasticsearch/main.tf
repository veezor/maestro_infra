resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = var.name
  elasticsearch_version = var.elasticsearch_version

  cluster_config {
    instance_type = var.cluster_config.instance_type
    instance_count = var.cluster_config.instance_count
  }

  ebs_options {
    ebs_enabled = var.ebs_options.ebs_enabled
    volume_size = var.ebs_options.volume_size
  }

  tags = {
    Domain = var.name
    Environment = var.environment
    Project = var.project
  }
}