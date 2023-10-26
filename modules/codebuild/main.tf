resource "aws_cloudwatch_log_group" "lg" {
  name              = format("/aws/codebuild/%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  retention_in_days = 7
}

resource "aws_codebuild_project" "cb" {
  name           = format("%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  description    = "Maestro"
  service_role   = var.aws_iam_role
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
      value = var.aws_security_group_lb
    }
    environment_variable {
      name  = "ALB_SUBNETS"
      value = format("%s,%s,%s", var.aws_subnets[0], var.aws_subnets[1], var.aws_subnets[2])
    }
    environment_variable {
      name  = "ECS_EFS_VOLUMES"
      value = ""
    }
    environment_variable {
      name  = "ECS_EXECUTION_ROLE_ARN"
      value = var.aws_iam_role
    }
    environment_variable {
      name  = "ECS_SERVICE_SECURITY_GROUPS"
      value = var.aws_security_group_app
    }
    environment_variable {
      name  = "ECS_SERVICE_SUBNETS"
      value = format("%s,%s,%s", var.aws_subnets[0], var.aws_subnets[1], var.aws_subnets[2])
    }
    environment_variable {
      name  = "ECS_SERVICE_TASK_PROCESSES"
      value = "web{1024;2048}:1-2"
    }
    environment_variable {
      name  = "ECS_TASK_ROLE_ARN"
      value = var.aws_iam_role
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
      value = format("Owner=%s,Project=%s,Environment=%s", var.owner, var.project, var.environment)
    }
    environment_variable {
      name  = "WORKLOAD_VPC_ID"
      value = var.aws_vpc_id
    }
    environment_variable {
      name  = "MAESTRO_REPO_OVERRIDE"
      value = format("%s/%s", var.owner, var.project)
    }    

  }
  vpc_config {
    vpc_id = var.aws_vpc_id

    subnets = [
      var.aws_subnets[0],
      var.aws_subnets[1],
      var.aws_subnets[2]
    ]

    security_group_ids = [
      var.aws_security_group_cb
    ]
  }
}

resource "aws_secretsmanager_secret" "secret" {
  name = format("%s/%s-%s", "${var.environment}", "${var.owner}", "${var.project}")
}

resource "aws_secretsmanager_secret_version" "content" {
  secret_id = aws_secretsmanager_secret.secret.id

  secret_string = jsonencode({
    PORT = "3000",
    TASK_ROLE_ARN = var.aws_iam_role,
    EXECUTION_ROLE_ARN = var.aws_iam_role
  })
}

resource "aws_ecr_repository" "ecr_repository" {
  name = format("%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
}