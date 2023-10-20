terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.17"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  subnet_cidrs = cidrsubnets(aws_vpc.vpc.cidr_block, 8, 8, 8, 8, 8, 8)
}
output "public" {
  value = local.subnet_cidrs
}


data "aws_caller_identity" "current" {}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_cidrs[each.key]

  tags = {
    "Name"        = format("%s-%s-public%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_cidrs[each.key + 3]

  tags = {
    "Name"        = format("%s-%s-private%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }

}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.ig]

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_nat_gateway" "ng" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "public_rt" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  route {
    cidr_block = var.vpc_cidr_block
    gateway_id = "local" 
  }

  tags = {
    "Name"        = format("%s-%s/%s%s", "${var.owner}", "${var.environment}", "public", each.key + 1)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table" "private_rt" {
  for_each   = { for idx in range(3) : idx => true }
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ng.id
  }

  route {
    cidr_block = var.vpc_cidr_block
    nat_gateway_id = "local" 
  }

  tags = {
    "Name"        = format("%s-%s/%s%s", "${var.owner}", "${var.environment}", "private", each.key + 1)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table_association" "public_association" {
  for_each       = { for idx in range(3) : idx => true }
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public_rt[each.key].id
}

resource "aws_route_table_association" "private_association" {
  for_each       = { for idx in range(3) : idx => true }
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private_rt[each.key].id
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions   = ["codebuild:StartBuild", "codebuild:StopBuild", "codebuild:CreateProject", "codebuild:DeleteProject", "codebuild:BatchGetBuilds", "codebuild:ListBuilds", "codebuild:GetBuild", "codebuild:DescribeProject", "codebuild:ListProjects"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = format("%s-%s-%s-codebuild", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.codebuild.json
}

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:TagResource"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "cloudwatch" {
  name   = format("%s-%s-%s-cloudwatch", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.cloudwatch.json
}

data "aws_iam_policy_document" "ecs" {
  statement {
    actions   = ["ecs:CreateService", "ecs:CreateCluster", "ecs:DescribeServices", "ecs:DescribeClusters", "ecs:ListServices", "ecs:RegisterTaskDefinition", "ecs:UpdateService"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "ecs" {
  name   = format("%s-%s-%s-ecs", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.ecs.json
}

data "aws_iam_policy_document" "ec2" {
  statement {
    actions   = ["ec2:CreateTags", "ec2:DescribeAccountAttributes", "ec2:DescribeDhcpOptions", "ec2:DescribeInternetGateways", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:CreateNetworkInterface", "ec2:CreateNetworkInterfacePermission", "ec2:DeleteNetworkInterface"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "ec2" {
  name   = format("%s-%s-%s-ec2", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.ec2.json
}

data "aws_iam_policy_document" "ecr" {
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:GetAuthorizationToken", "ecr:GetDownloadUrlForLayer", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:DescribeRepositories"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "ecr" {
  name   = format("%s-%s-%s-ecr", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.ecr.json
}

data "aws_iam_policy_document" "elb" {
  statement {
    actions   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:AddTags"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "elb" {
  name   = format("%s-%s-%s-elb", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.elb.json
}

 data "aws_iam_policy_document" "iam-pass-role" {
   statement {
     actions   = ["iam:PassRole"]
     resources = ["*"]
     effect    = "Allow"
   }
 }
 
resource "aws_iam_policy" "iam-pass-role" {
  name   = format("%s-%s-%s-iam-pass-role", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.iam-pass-role.json
}

data "aws_iam_policy_document" "iam-service-role" {
  statement {
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"]
    effect    = "Allow"
  }
}
 
resource "aws_iam_policy" "iam-service-role" {
  name   = format("%s-%s-%s-iam-service-role", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.iam-service-role.json
}

data "aws_iam_policy_document" "kms" {
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"]
    effect    = "Allow"
  }
}
 
resource "aws_iam_policy" "kms" {
  name   = format("%s-%s-%s-kms", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.kms.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    actions   = ["s3:GetBucketAcl", "s3:GetBucketLocation", "s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["arn:aws:s3:::*", "arn:aws:s3:::*/*"]
    effect    = "Allow"
  }
}
 
resource "aws_iam_policy" "s3" {
  name   = format("%s-%s-%s-s3", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "sm" {
  statement {
    actions   = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.environment}/${var.owner}-${var.project}*"]
    effect    = "Allow"
  }
}
 
resource "aws_iam_policy" "sm" {
  name   = format("%s-%s-%s-sm", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.sm.json
}

# data "aws_iam_policy_document" "ec2-network" {
#   statement {
#     actions   = ["ec2:CreateNetworkInterface", "ec2:CreateNetworkInterfacePermission", "ec2:DeleteNetworkInterface"]
#     resources = ["arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*", "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:subnet/*"]
#     condition {
#       test     = "ForAnyValue:StringEquals"
#       variable = ["ec2:Subnet", "ec2:AuthorizedService"]
#       values = [
#         "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:subnet/subnet-*",
#         "codebuild.amazonaws.com"
#       ]
#     }
#     effect = "Allow"
#   }
# }

# resource "aws_iam_policy" "ec2-network" {
#   name = format("%s-%s-%s-ec2-network", "${var.owner}", "${var.project}", "${var.environment}")
#   policy = data.aws_iam_policy_document.ec2-network.json
# }



resource "aws_iam_role" "role" {
  name               = format("%s-%s-%s-Maestro", "${var.owner}", "${var.project}", "${var.environment}")
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    },
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.cloudwatch.arn
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.ecs.arn
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.ec2.arn
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.ecr.arn
}

resource "aws_iam_role_policy_attachment" "elb" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.elb.arn
}

resource "aws_iam_role_policy_attachment" "iam-pass-role" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.iam-pass-role.arn
}

resource "aws_iam_role_policy_attachment" "iam-service-role" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.iam-service-role.arn
}


resource "aws_iam_role_policy_attachment" "kms" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.kms.arn
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "sm" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.sm.arn
}

# resource "aws_iam_role_policy_attachment" "ec2-network" {
#   role = aws_iam_role.role.name
#   policy_arn = aws_iam_policy.ec2-network.arn
# }

resource "aws_cloudwatch_log_group" "lg" {
  name              = format("/aws/codebuild/%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  retention_in_days = 7
}

resource "aws_security_group" "app" {
  name   = format("%s-%s-%s-app", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "lb" {
  name   = format("%s-%s-%s-lb", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group" "codebuild" {
  name   = format("%s-%s-%s-codebuild", "${var.owner}", "${var.project}", "${var.environment}")
  vpc_id = aws_vpc.vpc.id
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
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "all"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "lb_inbound_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
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

resource "aws_codebuild_project" "cb" {
  name           = format("%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  description    = "Maestro"
  service_role   = aws_iam_role.role.arn
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
      value = format("%s,%s,%s", aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_subnet[2].id)
    }
    environment_variable {
      name  = "ECS_EFS_VOLUMES"
      value = ""
    }
    environment_variable {
      name  = "ECS_EXECUTION_ROLE_ARN"
      value = aws_iam_role.role.arn
    }
    environment_variable {
      name  = "ECS_SERVICE_SECURITY_GROUPS"
      value = aws_security_group.app.id
    }
    environment_variable {
      name  = "ECS_SERVICE_SUBNETS"
      value = format("%s,%s,%s", aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id, aws_subnet.private_subnet[2].id)
    }
    environment_variable {
      name  = "ECS_SERVICE_TASK_PROCESSES"
      value = "web{1024;2048}:1-2"
    }
    environment_variable {
      name  = "ECS_TASK_ROLE_ARN"
      value = aws_iam_role.role.arn
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
      value = aws_vpc.vpc.id
    }
    environment_variable {
      name  = "MAESTRO_REPO_OVERRIDE"
      value = format("%s/%s", var.owner, var.project)
    }    

  }
  vpc_config {
    vpc_id = aws_vpc.vpc.id

    subnets = [
      aws_subnet.private_subnet[0].id,
      aws_subnet.private_subnet[1].id,
      aws_subnet.private_subnet[2].id
    ]

    security_group_ids = [
      aws_security_group.codebuild.id
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
    TASK_ROLE_ARN = aws_iam_role.role.arn,
    EXECUTION_ROLE_ARN = aws_iam_role.role.arn
  })
}

resource "aws_ecr_repository" "ecr_repository" {
  name = format("%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
}