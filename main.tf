terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.17"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "${var.region}"
}

locals {
  public_cidrs  = cidrsubnets(aws_vpc.vpc.cidr_block, 8, 8, 8)
  private_cidrs = cidrsubnets(aws_vpc.vpc.cidr_block, 8, 8, 8)
}

data "aws_caller_identity" "current" {}

# Create a VPC
resource "aws_vpc" "vpc" {
  cidr_block            = "${var.vpc_cidr_block}"
  enable_dns_hostnames  = true
  enable_dns_support    = true

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "public_subnet" {
  for_each    = { for idx in range(3): idx => true }
  vpc_id      = aws_vpc.vpc.id
  cidr_block  = local.public_cidrs[each.key]

  tags = {
    "Name"        = format("%s-%s-public%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_subnet" "private_subnet" {
  for_each    = { for idx in range(3): idx => true }
  vpc_id      = aws_vpc.vpc.id
  cidr_block  = local.private_cidrs[each.key]
  
  tags = {
    "Name"        = format("%s-%s-private%s", "${var.owner}", "${var.environment}", each.key)
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }

}

resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"

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

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ng.id
  }

  tags = {
    "Name"        = format("%s-%s", "${var.owner}", "${var.environment}")
    "Owner"       = "${var.owner}"
    "Environment" = "${var.environment}"
  }
}

resource "aws_route_table_association" "public_association" {
  for_each        = { for idx in range(3): idx => true }
  subnet_id       = aws_subnet.public_subnet[each.key].id
  route_table_id  = aws_route_table.rt.id
}

resource "aws_route_table_association" "private_association" {
  for_each      = { for idx in range(3): idx => true }
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.rt.id
}

resource "aws_iam_role" "service_role" {
  name = format("%s-%s-%s-Maestro", "${var.owner}", "${var.project}", "${var.environment}")
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "application-autoscaling:RegisterScalableTarget",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:DescribeScalingPolicies"
        ]
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageAppAutoScaling"
      },
      {
        Action = "cloudwatch:DescribeAlarms"
        Resource = "arn:aws:cloudwatch:us-east-1:${data.aws_caller_identity.current.account_id}:alarm:*"
        Effect = "Allow"
        Sid = "ManageCloudwatchAlarms"
      },
      {
        Action = [
          "codebuild:BatchPutCodeCoverages",
          "codebuild:BatchPutTestCases",
          "codebuild:CreateReport",
          "codebuild:CreateReportGroup",
          "codebuild:UpdateReport",
          "codebuild:BatchGetBuilds"
        ]
        Resource = "arn:aws:codebuild:us-east-1:${data.aws_caller_identity.current.account_id}:report-group/${var.owner}-${var.project}-image-build-*"
        Effect = "Allow"
        Sid = "ManageCodebuild"
      },
      {
        Action = [
          "ec2:CreateTags",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageEC2"
      },
      {
        Condition = {
          StringEquals = {
            "ec2:Subnet" = [
              "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:subnet/subnet-*"
            ]
            "ec2:AuthorizedService" = "codebuild.amazonaws.com"
          }
        }
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = [
          "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:us-east-1:${data.aws_caller_identity.current.account_id}:subnet/*"
        ]
        Effect = "Allow"
        Sid = "ManageEC2Network"
        },
        {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "arn:aws:ecr:us-east-1:${data.aws_caller_identity.current.account_id}:repository/*"
        Effect = "Allow"
        Sid = "ManageECR"
      },
      {
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageECRAuthToken"
      },
      {
        Action = [
          "ecs:CreateService",
          "ecs:CreateCluster",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageECS"
      },
      {
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:AddTags"
        ]
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageELB"
      },
      {
        Action = "iam:PassRole"
        Resource = "*"
        Effect = "Allow"
        Sid = "ManageIAMPassRole"
      },
      {
        Action = "iam:CreateServiceLinkedRole"
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
        ]
        Effect = "Allow"
        Sid = "ManageIAMServiceRole"
      },
      {
        Action = "kms:Decrypt"
        Resource = "arn:aws:kms:us-east-1:${data.aws_caller_identity.current.account_id}:key/*"
        Effect = "Allow"
        Sid = "ManageKMS"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:PutLogEvents",
          "logs:TagResource"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:*"
        Effect = "Allow"
        Sid = "ManageLogsOnCloudwatch"
      },
      {
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
        Effect = "Allow"
        Sid = "ManageS3"
      },
      {
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:*/${var.owner}-${var.project}*"
        Effect = "Allow"
        Sid = "ManageSecretsManager"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lg" {
  name              = format("/aws/codebuild/%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  retention_in_days = 7
}

resource "aws_codebuild_project" "cb" {
  name          = format("%s-%s-%s", "${var.owner}", "${var.project}", "${var.environment}")
  description   = "Maestro"
  service_role  = aws_iam_role.service_role.arn
  source {
    type = "GITHUB"
    location = "https://github.com/owner/repo"
    buildspec = "buildspec.yml"
  }
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
  }
}