# MAESTRO_INFRA IN TERRAFORM

This branch allow you to create your AWS's infrastructure with Maestro_Infra using [Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs). 


### What is the benefits to use Terraform?
- More speed in services creation.
- More simple to customization.
- More community support and updates.

## Available modules
AWS services that you can create:

- **VPC** (VPCs, Subnets, Internet and Nat Gateways, Route Tables and Security Groups)
- **IAM** (Roles and Policies)
- **Codebuild**
- **ECR**
- **SecretsManager**

## Steps to init a new project 

### Var File example
This is an example for your environment variables file:

```bash
owner = "owner"
region = "us-east-1"
environment = "staging"
vpc_cidr_block = "10.0.0.0/16"
maestro_image = "public.ecr.aws/h4u2q3r3/maestro:1.4.1"
projects = [
    {
        name = "project1"
        code_provider = "GITHUB"
        repository_url = "https://github.com/veezor/foo"
        repository_branch = "staging"
    },
    {
        name = "project2"
        code_provider = "GITHUB"
        repository_url = "https://github.com/veezor/bar"
        repository_branch = "main"
    }
]

```

### 1- Export AWS credentials 
Export the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

```bash
$ export AWS_ACCESS_KEY_ID=your_key_id
$ export AWS_SECRET_ACCESS_KEY=your_secret_access_key
```

### 2- Init a Terraform project
Initialize the terraform project, creating the **main.tf** and **var.tf** files.

```bash
$ terraform init -var-file=path/project-vars.tfvars
```

### 3- Plan your project
Plan and show all changes in your project.

```bash
$ terraform plan -var-file=path/project-vars.tfvars -out path/project.bin
```

### 4- Apply your project 
Apply all the changes made to your project on AWS. 

```bash
$ terraform apply path/project.bin
```

### 5- How to destroy your project in AWS 
If you want to destroy you project, this command will remove all the changes that you made.

```bash
$ terraform destroy -var-file=path/project-vars.tfvars
```
