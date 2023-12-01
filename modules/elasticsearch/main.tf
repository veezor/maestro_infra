resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = var.domain_name
  elasticsearch_version = var.elastichsearch_version

  cluster_config {
    instance_type = var.instance_type
  }

  ebs_options {
    ebs_enabled = var.ebs_enabled
    volume_size = var.volume_size
  }

  tags = {
    Domain = var.domain_name
    environment = var.environment
  }
}