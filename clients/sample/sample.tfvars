owner           = "owner-name"
region          = "us-east-1"
environment     = "staging"
vpc_cidr_block  = "10.4.0.0/16"
maestro_image   = "public.ecr.aws/h4u2q3r3/maestro:1.4.0"
projects        = [
    {
        project_name        = "backend"
        code_provider       = "GITHUB"
        repository_url      = "https://github.com/owner/backend"
        repository_branch   = "staging",
        databases           = [
            {
                identifier      = "backend",
                engine          =  "aurora-mysql",
                engine_version  = "5.7"
                instance_class  = "db.t4g.medium"
                master_username = "test3334444"
                master_password = "t35t4nd0000"
            }
        ]
    }
    {
        project_name        = "frontend"
        code_provider       = "BITBUCKET"
        repository_url      = "https://bitbucket.org/owner/frontend"
        repository_branch   = "staging",
        databases           = []
    }
]