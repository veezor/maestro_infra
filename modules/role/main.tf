data "aws_caller_identity" "current" {}
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

data "aws_iam_policy_document" "cloudwatch-ssm" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:TagResource", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "cloudwatch-ssm" {
  name   = format("%s-%s-%s-cloudwatch-ssm", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.cloudwatch-ssm.json
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

data "aws_iam_policy_document" "ec2-autoscaling" {
  statement {
    actions   = ["ec2:CreateTags", "ec2:DescribeAccountAttributes", "ec2:DescribeDhcpOptions", "ec2:DescribeInternetGateways", "ec2:DescribeNetworkInterfaces", "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs", "ec2:CreateNetworkInterface", "ec2:CreateNetworkInterfacePermission", "ec2:DeleteNetworkInterface"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    actions   = ["application-autoscaling:RegisterScalableTarget", "application-autoscaling:PutScalingPolicy", "application-autoscaling:DescribeScalingPolicies"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "ec2-autoscaling" {
  name   = format("%s-%s-%s-ec2-autoscaling", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.ec2-autoscaling.json
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

data "aws_iam_policy_document" "elb-es" {
  statement {
    actions   = ["elasticloadbalancing:CreateListener", "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DescribeListeners", "elasticloadbalancing:DescribeLoadBalancers", "elasticloadbalancing:DescribeTargetGroups", "elasticloadbalancing:AddTags", "es:CreateDomain", "es:CreateElasticsearch*", "es:DeleteDomain", "es:DeleteElasticsearch*"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "elb-es" {
  name   = format("%s-%s-%s-elb-es", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.elb-es.json
}

 data "aws_iam_policy_document" "iam" {
   statement {
     actions   = ["iam:PassRole"]
     resources = ["*"]
     effect    = "Allow"
   }
   statement {
     actions   = ["iam:CreateServiceLinkedRole"]
     resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService"]
     effect    = "Allow"
   }
 }
 
resource "aws_iam_policy" "iam" {
  name   = format("%s-%s-%s-iam", "${var.owner}", "${var.project}", "${var.environment}")
  policy = data.aws_iam_policy_document.iam.json
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

resource "aws_iam_role" "codebuild_role" {
  name               = format("%s-%s-%s-CodeBuild-Maestro", "${var.owner}", "${var.project}", "${var.environment}")
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
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
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch-ssm" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.cloudwatch-ssm.arn
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.ecs.arn
}

resource "aws_iam_role_policy_attachment" "ec2-autoscaling" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.ec2-autoscaling.arn
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.ecr.arn
}

resource "aws_iam_role_policy_attachment" "elb-es" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.elb-es.arn
}

resource "aws_iam_role_policy_attachment" "iam" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.iam.arn
}

resource "aws_iam_role_policy_attachment" "kms" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.kms.arn
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "sm" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.sm.arn
}

resource "aws_iam_role" "ecs_role" {
  name               = format("%s-%s-%s-ECS-Maestro", "${var.owner}", "${var.project}", "${var.environment}")
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
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "codebuild_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch-ssm_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.cloudwatch-ssm.arn
}

resource "aws_iam_role_policy_attachment" "ecs_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.ecs.arn
}

resource "aws_iam_role_policy_attachment" "ec2-autoscaling_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.ec2-autoscaling.arn
}

resource "aws_iam_role_policy_attachment" "ecr_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.ecr.arn
}

resource "aws_iam_role_policy_attachment" "elb-es_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.elb-es.arn
}

resource "aws_iam_role_policy_attachment" "iam_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.iam.arn
}

resource "aws_iam_role_policy_attachment" "kms_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.kms.arn
}

resource "aws_iam_role_policy_attachment" "s3_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.s3.arn
}

resource "aws_iam_role_policy_attachment" "sm_for-ecs" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = aws_iam_policy.sm.arn
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild_role.arn
}