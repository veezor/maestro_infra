owner           = "owner-name"
region          = "us-east-1"
environment     = "staging"
vpc_cidr_block  = "10.6.0.0/16"
vpc_id          = "vpc-039f602c7f79c31d8"
maestro_image   = "public.ecr.aws/h4u2q3r3/maestro:1.4.0"
projects        = [
    {
        project_name        = "backend"
        code_provider       = "GITHUB"
        repository_url      = "https://github.com/owner/backend"
        repository_branch   = "staging",
        databases           = [
            //{
            //    identifier          = "backend",
            //    engine              =  "aurora-mysql",
            //    engine_version      = "5.7"
            //    instance_class      = "db.t3.medium"
            //    master_username     = ""
            //    master_password     = ""
            //    skip_final_snapshot = false
            //    apply_immediately   = true
            //}
        ]
        elasticsearch       = []
    },
    {
        project_name        = "frontend"
        code_provider       = "BITBUCKET"
        repository_url      = "https://bitbucket.org/owner/frontend"
        repository_branch   = "staging",
        databases           = []
        elasticsearch       = [
            //{
            //    name = "frontend-site"
            //    elasticsearch_version = "7.10"
            //    cluster_config = {
            //        instance_type = "t3.small.elasticsearch"
            //        instance_count = 1
            //    }
            //    ebs_options = {
            //        ebs_enabled = true
            //        volume_size = 40
            //    }
            //}
        ]
    }]