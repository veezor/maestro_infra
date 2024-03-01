variable projects {
  type = list(object({
    project_name = string
    code_provider = string
    task_processes = string
    repository_url = string
    repository_branch = string
    databases = list(object({
      identifier = string
      engine = string
      engine_version = string
      instance_class = string
      master_username = string
      master_password = string
      skip_final_snapshot = bool
      apply_immediately = bool
      snapshot_identifier = string
    }))
    elasticsearch = list(object({
      name = string
      elasticsearch_version = string
      cluster_config = object({
        instance_count = number 
        instance_type = string
      })
      ebs_options = object({
        ebs_enabled = bool 
        volume_size = number 
      })
    }))
    redis = list(object({
      identifier = string
      engine = string
      engine_version = string
      node_type = string
      num_cache_nodes = number
      parameter_group = string 
      apply_immediately = bool
    }))
  }))
}

variable "owner" {
  type = string
}

variable "environment" {
  default = "staging"
  type = string
}

variable "region" {
  default = "us-east-1"
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "maestro_image" {
  type = string
}

variable "peering" {
  type = object({
    accepter_vpc_id = string
    private_route_tables_id = list(string)
    public_route_tables_id = list(string)
})
}