resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = var.domain_name
  elasticsearch_version = var.version

  cluster_config {
    instance_type = var.instance_type
  }

  tags = {
    Domain = var.domain_name
    environment = var.environment
  }
}