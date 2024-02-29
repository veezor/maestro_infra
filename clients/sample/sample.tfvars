owner                   = "owner-name"
region                  = "us-east-1"
environment             = "staging"
vpc_cidr_block          = "10.4.0.0/16"
maestro_image           = "public.ecr.aws/h4u2q3r3/maestro:1.4.0"
peering     = {
    accepter_vpc_id = "vpc-0328c58230dd96100"
    private_route_tables_id = ["rtb-0adde7d5ac2991522", "rtb-03feca6be7bf2d319", "rtb-0d5a9f504968b53a9", "rtb-04e8f767151cc13bb"]
    public_route_tables_id = ["rtb-03aaf57fc3dd28bc6", "rtb-0d5bca2877d5c548f", "rtb-06ef39012e98c0a2c"]
}
projects = [
    {
        project_name        = "backend"
        code_provider       = "GITHUB"
        task_processes      = "web{1024;2048}:1-2"
        repository_url      = "https://github.com/veezor/static-site"
        repository_branch   = "staging",
        databases           = [
            {
                identifier          = "backend"
                engine              = "aurora-mysql"
                engine_version      = "5.7"
                instance_class      = "db.t4g.medium"
                master_username     = "Us35n4m3"
                master_password     = "P4ssw05d"
                skip_final_snapshot = false
                apply_immediately   = true
                snapshot_identifier = ""
            }
        ]
        redis               = []
        elasticsearch       = []
    }
    {
        project_name        = "frontend"
        code_provider       = "BITBUCKET"
        task_processes      = "web{1024;2048}:1-2"
        repository_url      = "https://bitbucket.org/owner/frontend"
        repository_branch   = "staging"
        databases           = []
        elasticsearch       = [
             {
              name = "frontend-site"
              elasticsearch_version = "7.10"
              cluster_config = {
                  instance_type = "t3.small.elasticsearch"
                  instance_count = 1
              }
              ebs_options = {
                  ebs_enabled = true
                  volume_size = 40
              }
             }
        ]
        redis               = [
            {
                identifier          = "frontend-cluster"
                engine              = "redis"
                engine_version      = "7.0"
                node_type           = "cache.t4g.micro"
                num_cache_nodes     = 1
                parameter_group     = "default.redis7"
                apply_immediately   = true
                prevent_destroy     = true
            }
        ]
    }
]
