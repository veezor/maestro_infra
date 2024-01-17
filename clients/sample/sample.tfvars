owner                   = "owner-name"
region                  = "us-east-1"
environment             = "staging"
vpc_cidr_block          = "10.4.0.0/16"
maestro_image           = "public.ecr.aws/h4u2q3r3/maestro:1.4.0"
peering     = {
    accepter_vpc_id = ""
    private_route_tables_id = []
    public_route_tables_id = []
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
                identifier          = "backend",
                engine              =  "aurora-mysql",
                engine_version      = "5.7"
                instance_class      = "db.t3.medium"
                master_username     = ""
                master_password     = ""
                skip_final_snapshot = false
                apply_immediately   = true
            }
        ]
        s3                  = [
            {
                name  = "trasfinal"
            },
            {
                name  = "middleend"
            }
        ]
        redis               = []
        elasticsearch       = []
    },
    {
        project_name        = "frontend"
        code_provider       = "BITBUCKET"
        task_processes      = "web{1024;2048}:1-2"
        repository_url      = "https://bitbucket.org/owner/frontend"
        repository_branch   = "staging"
        databases           = []
        s3                  = []
        redis               = []
        elasticsearch       = []
    }
]