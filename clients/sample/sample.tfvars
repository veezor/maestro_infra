owner = "owner-name"
region = "us-east-1"
environment = "staging"
vpc_cidr_block = "10.4.0.0/16"
maestro_image = "public.ecr.aws/h4u2q3r3/maestro:1.4.0"
projects = [
    {
        name = "backend"
        code_provider = "GITHUB"
        repository_url = "https://github.com/owner/backend"
        repository_branch = "staging"
    },
    {
        name = "frontend"
        code_provider = "BITBUCKET"
        repository_url = "https://bitbucket.org/owner/frontend"
        repository_branch = "staging"
    }
]