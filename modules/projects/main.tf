locals {
  snapshot_date = element(split(":", timestamp()), 0)
}

resource "aws_security_group" "app" {
  name   = format("%s-%s-%s-app", "${var.owner}", "${var.project_name}", "${var.environment}")
  vpc_id = var.aws_vpc_id
}

resource "aws_security_group" "lb" {
  name   = format("%s-%s-%s-lb", "${var.owner}", "${var.project_name}", "${var.environment}")
  vpc_id = var.aws_vpc_id
}

resource "aws_security_group" "codebuild" {
  name   = format("%s-%s-%s-codebuild", "${var.owner}", "${var.project_name}", "${var.environment}")
  vpc_id = var.aws_vpc_id
}

resource "aws_security_group_rule" "app_inbound_lb_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "app_outbound_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.app.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "lb_inbound_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "lb_inbound_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.lb.id
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "lb_outbound_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.lb.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "codebuild_outbound_all_traffic" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.codebuild.id
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = format("/aws/codebuild/%s-%s-%s", "${var.owner}", "${var.project_name}", "${var.environment}")
  retention_in_days = 7
}

module "role" {
  source         = "../../modules/role"
 
  project_name   = var.project_name
  owner          = var.owner
  environment    = var.environment
  vpc_cidr_block = var.vpc_cidr_block
  region         = var.region
 }

resource "aws_codebuild_project" "cb" {
  name           = format("%s-%s-%s", "${var.owner}", "${var.project_name}", "${var.environment}")
  description    = "Maestro"
  service_role   = module.role.codebuild_role_arn
  source_version = var.repository_branch
  source {
    type     = var.code_provider
    location = var.repository_url
    buildspec = <<EOF
version: 0.2
phases:
  build:
    on-failure: ABORT
    commands:
      - dockerd-entrypoint.sh main.sh
EOF
  }
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "${var.maestro_image}"
    type         = "LINUX_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "ALB_SCHEME"
      value = "internet-facing"
    }

    environment_variable {
      name  = "ALB_SECURITY_GROUPS"
      value = aws_security_group.lb.id
    }
    environment_variable {
      name  = "ALB_SUBNETS"
      value = format("%s,%s,%s", var.aws_public_subnets[0], var.aws_public_subnets[1], var.aws_public_subnets[2])
    }
    environment_variable {
      name  = "ECS_EFS_VOLUMES"
      value = ""
    }
    environment_variable {
      name  = "ECS_EXECUTION_ROLE_ARN"
      value = module.role.ecs_role_arn
    }
    environment_variable {
      name  = "ECS_SERVICE_SECURITY_GROUPS"
      value = aws_security_group.app.id
    }
    environment_variable {
      name  = "ECS_SERVICE_SUBNETS"
      value = format("%s,%s,%s", var.aws_private_subnets[0], var.aws_private_subnets[1], var.aws_private_subnets[2])
    }
    environment_variable {
      name  = "ECS_SERVICE_TASK_PROCESSES"
      value = "web{1024;2048}:1-2"
    }
    environment_variable {
      name  = "ECS_TASK_ROLE_ARN"
      value = module.role.ecs_role_arn
    }
    environment_variable {
      name  = "MAESTRO_BRANCH_OVERRIDE"
      value = "${var.environment}"
    }
    environment_variable {
      name  = "MAESTRO_DEBUG"
      value = false
    }
    environment_variable {
      name  = "MAESTRO_NO_CACHE"
      value = false
    }
    environment_variable {
      name  = "MAESTRO_ONLY_BUILD"
      value = ""
    }
    environment_variable {
      name  = "MAESTRO_SKIP_BUILD"
      value = ""
    }
    environment_variable {
      name  = "WORKLOAD_RESOURCE_TAGS"
      value = format("Owner=%s,Project=%s,Environment=%s", var.owner, var.project_name, var.environment)
    }
    environment_variable {
      name  = "WORKLOAD_VPC_ID"
      value = var.aws_vpc_id
    }
    environment_variable {
      name  = "MAESTRO_REPO_OVERRIDE"
      value = format("%s/%s", var.owner, var.project_name)
    }    

  }
  vpc_config {
    vpc_id = var.aws_vpc_id

    subnets = [
      var.aws_private_subnets[0],
      var.aws_private_subnets[1],
      var.aws_private_subnets[2]
    ]

    security_group_ids = [
      aws_security_group.codebuild.id
    ]
  }
}

resource "aws_secretsmanager_secret" "secret" {
  name = format("%s/%s-%s", "${var.environment}", "${var.owner}", "${var.project_name}")
}

resource "aws_secretsmanager_secret_version" "content" {
  secret_id = aws_secretsmanager_secret.secret.id

  secret_string = jsonencode({
    PORT = "3000",
    TASK_ROLE_ARN = module.role.ecs_role_arn,
    EXECUTION_ROLE_ARN = module.role.ecs_role_arn
  })
}

resource "aws_ecr_repository" "ecr_repository" {
  name = format("%s-%s-%s", "${var.owner}", "${var.project_name}", "${var.environment}")
}


module "rds" {
  source                    = "../../modules/rds"
  for_each = {for database in var.databases: database.identifier => database}

  identifier            = each.value.identifier
  instance_class        = each.value.instance_class
  engine                = each.value.engine
  engine_version        = each.value.engine_version
  project               = var.project_name
  owner                 = var.owner
  aws_vpc_id            = var.aws_vpc_id
  environment           = var.environment
  app_security_group_id = aws_security_group.app.id
  private_subnet_ids    = var.aws_private_subnets
  master_username       = each.value.master_username
  master_password       = each.value.master_password
  skip_final_snapshot   = each.value.skip_final_snapshot
  apply_immediately     = each.value.apply_immediately
}

module "elasticsearch" {
  source                    = "../../modules/elasticsearch"
  for_each = {for domain in var.elasticsearch: domain.name => domain}

  name                      = each.value.name
  elasticsearch_version     = each.value.elasticsearch_version
  cluster_config            = each.value.cluster_config
  ebs_options               = each.value.ebs_options
  environment               = var.environment
  project                   = var.project_name
  owner                     = var.owner
}
module "s3" {
  source                    = "../../modules/s3"
  for_each = {for bucket in var.s3: bucket.name => bucket}

  name                      = each.value.name
  environment               = var.environment
  project                   = var.project_name
  owner                     = var.owner
}