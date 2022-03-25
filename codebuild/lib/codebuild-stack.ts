import {
  Tags,
  Stack,
  StackProps,
  RemovalPolicy,
  aws_ecr as ecr,
  aws_ec2 as ec2,
  aws_iam as iam,
  aws_logs as logs,
  aws_codebuild as codebuild,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as yaml from 'yaml';
import * as fs from 'fs';
import { IVpc } from 'aws-cdk-lib/aws-ec2';

export class CodebuildStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const test = this.node.tryGetContext('TEST');
    const projectOwner = this.node.tryGetContext('PROJECT_OWNER').toLowerCase();
    const repositoryName = this.node.tryGetContext('REPOSITORY_NAME').toLowerCase();
    const gitService = this.node.tryGetContext('GIT_SERVICE').toLowerCase();
    const projectTags = JSON.parse(this.node.tryGetContext('TAGS'));
    const branch = this.node.tryGetContext('BRANCH');
    const privateSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS_PRIVATE'));
    const vpcId = this.node.tryGetContext('VPC_ID');

    let subnetsArns:any = [];
    
    Tags.of(this).add('Project', repositoryName);

    for (let i = 0; i < projectTags.length; i++) {
      let element = projectTags[i];
      Tags.of(this).add(element[0], element[1]);
    }
    
    const codeBuildLogGroup = new logs.LogGroup(this, `CreateCloudWatchcodeBuildLogGroup`, {
      logGroupName: `/aws/codebuild/${projectOwner}-${repositoryName}-${branch}-image-build`,
      removalPolicy: (test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });
    
    var gitHubSource = codebuild.Source.gitHub({
        owner: projectOwner,
        repo: repositoryName,
        branchOrRef: 'master-veezor'
      });
    
    if (gitService == 'bitbucket') {
      gitHubSource = codebuild.Source.bitBucket({
        owner: projectOwner,
        repo: repositoryName,
        branchOrRef: 'master-veezor'
      });
    }

    const vpc = (privateSubnetIds.length > 0) ? 
      ec2.Vpc.fromVpcAttributes(this, 'UseExistingVpc', {
        availabilityZones: ec2.Vpc.fromLookup(this, 'GetAZsFromSubnet', { vpcId: vpcId }).availabilityZones,
        vpcId: vpcId,
        privateSubnetIds: privateSubnetIds
      }) :
      ec2.Vpc.fromLookup(this, 'UseExistingVPC', {
        vpcId: vpcId
      });

    const Ids = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE
    });

    for (let subnet of Ids.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`);
    }

    const codeBuildManagedPolicies = new iam.ManagedPolicy(this, `CreateCodeBuildPolicy`, {
      managedPolicyName: `CodeBuild-${projectOwner}-${repositoryName}-${branch}`,
      statements: [
        new iam.PolicyStatement({
          sid: "ManageRole",
          effect: iam.Effect.ALLOW,
          actions: [
            "iam:PassRole"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageECR",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:CompleteLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:InitiateLayerUpload",
            "ecr:BatchCheckLayerAvailability",
            "ecr:PutImage"
          ],
          resources: [`arn:aws:ecr:${this.region}:${this.account}:repository/*`]
        }),
        new iam.PolicyStatement({
          sid: "GetECRAuthorizedToken",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecr:GetAuthorizationToken"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManagerECS",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecs:ListServices",
				    "ecs:RegisterTaskDefinition",
            "ecs:CreateService",
				    "ecs:UpdateService"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageSecretValue",
          effect: iam.Effect.ALLOW,
          actions: ["secretsmanager:GetSecretValue"],
          resources: [
            `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*/${projectOwner}-${repositoryName}*`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageLogsOnCloudWatch",
          effect: iam.Effect.ALLOW,
          actions: [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogGroups"
          ],
          resources: [
            `arn:aws:logs:${this.region}:${this.account}:log-group::*`,
            codeBuildLogGroup.logGroupArn,
            `${codeBuildLogGroup.logGroupArn}:*`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageS3Bucket",
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation"
          ],
          resources: [
            "arn:aws:s3:::*",
            "arn:aws:s3:::*/*"
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageCodebuild",
          effect: iam.Effect.ALLOW,
          actions: [
            "codebuild:CreateReportGroup",
            "codebuild:CreateReport",
            "codebuild:UpdateReport",
            "codebuild:BatchPutTestCases",
            "codebuild:BatchPutCodeCoverages"
          ],
          resources: [
            `arn:aws:codebuild:${this.region}:${this.account}:report-group/${projectOwner}-${repositoryName}-image-build-*`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageEC2VPC",
          effect: iam.Effect.ALLOW,
          actions: [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeVpcs",
            "ec2:CreateTags",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeInternetGateways",
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:CreateTargetGroup"
          ],
          resources: [
            "*"
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageEC2NetworkInterface",
          effect: iam.Effect.ALLOW,
          actions: [
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission",
            "ec2:DeleteNetworkInterface"
          ],
          resources: [
            `arn:aws:ec2:${this.region}:${this.account}:network-interface/*`
          ],
          conditions: {
            StringEquals: {
              "ec2:Subnet": subnetsArns,
              "ec2:AuthorizedService": "codebuild.amazonaws.com"
            }
          }
        })
      ]
    });

    const codeBuildProjectRole = new iam.Role(this, `CreateCodeBuildProjectRole`, {
      assumedBy: new iam.ServicePrincipal('codebuild.amazonaws.com'),
      roleName: `${projectOwner}-${repositoryName}-${branch}-image-build-service-role`,
      path: '/service-role/',
      managedPolicies: [
        codeBuildManagedPolicies
      ]
    });
    codeBuildProjectRole.applyRemovalPolicy((test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN);

    const securityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedCodeBuildSecurityGroup', `${repositoryName}-${branch}-codebuild-sg`, vpc);

    const albSecurityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedCodeBuildAlbSecurityGroup', `${repositoryName}-${branch}-lb-sg`, vpc);

    const buildImage = codebuild.LinuxBuildImage.fromDockerRegistry("public.ecr.aws/h4u2q3r3/aws-codebuild-cloud-native-buildpacks:l4"); 

    const customBuildSpec = yaml.parse(fs.readFileSync('../configs/codebuild/customBuildSpec.yaml', 'utf8'));

    new codebuild.Project(this, `CreateCodeBuildProject`, {
      projectName: `${projectOwner}-${repositoryName}-${branch}-image-build`,
      description: `Build to project ${repositoryName}, source from github, deploy to ECS fargate.`,
      badge: true,
      source: gitHubSource,
      buildSpec: codebuild.BuildSpec.fromObjectToYaml(customBuildSpec),
      role: codeBuildProjectRole,
      securityGroups: [securityGroup],
      environment: {
        buildImage: buildImage,
        privileged: true,
        environmentVariables: {
          "MAESTRO_BRANCH_OVERRIDE": {
            value: branch
          },
          "ECS_SERVICE_SUBNETS": {
            value: Ids.subnetIds
          },
          "ECS_SERVICE_SECURITY_GROUPS": {
            value: securityGroup.securityGroupId
          },
          "WORKLOAD_RESOURCE_TAGS": {
            value: `Owner=${projectOwner},Project=${repositoryName},Environment=${branch},Branch=${branch}`
          },
          "ECS_TASK_ROLE_ARN": {
            value: `arn:aws:iam::${this.account}:role/${projectOwner}-${repositoryName}-${branch}-service-role`
          },
          "ECS_EXECUTION_ROLE_ARN": {
            value: `arn:aws:iam::${this.account}:role/ecsTaskExecutionRole-${repositoryName}-${branch}`
          },
          "ECS_SERVICE_TASK_PROCESSES": {
            value: "web:2{1024;2048},console{1024;2048}"
          },
          "ALB_SUBNETS": {
            value: Ids.subnetIds
          },
          "ALB_SCHEME": {
            value: "internal"
          },
          "ALB_SECURITY_GROUPS": {
            value: albSecurityGroup.securityGroupId
          },
          "WORKLOAD_VPC_ID": {
            value: vpcId
          },
          "MAESTRO_NO_CACHE": {
            value: false
          },
          "MAESTRO_CLEAR_CACHE": {
            value: false
          },
          "MAESTRO_DEBUG": {
            value: false
          }
        }
      },
      vpc: vpc,
      cache: codebuild.Cache.local(codebuild.LocalCacheMode.DOCKER_LAYER, codebuild.LocalCacheMode.SOURCE),
      logging: {
        cloudWatch: {
          enabled: true,
          logGroup: codeBuildLogGroup
        }
      }
    });
  }
}