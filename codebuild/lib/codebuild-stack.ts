import {
  Tags,
  Stack,
  CfnOutput,
  StackProps,
  RemovalPolicy,
  aws_ec2 as ec2,
  aws_iam as iam,
  aws_logs as logs,
  aws_codebuild as codebuild,
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as yaml from 'yaml';
import * as fs from 'fs';

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
    const deployUserExist = this.node.tryGetContext('DEPLOY_USER_EXIST');

    let subnetsArns:any = [];

    console.log(`test: ${test}`, `projectOwner: ${projectOwner}`, `repositoryName: ${repositoryName}`, `gitService: ${gitService}`, `projectTags: ${projectTags}`, `branch: ${branch}`, `privateSubnetIds: ${privateSubnetIds}`, `vpcId: ${vpcId}`, `deployUserExist: ${deployUserExist}`);
    
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
        branchOrRef: branch
      });
    
    if (gitService == 'bitbucket') {
      gitHubSource = codebuild.Source.bitBucket({
        owner: projectOwner,
        repo: repositoryName,
        branchOrRef: branch
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
          sid: "ManagerCodestarConnection",
          effect: iam.Effect.ALLOW,
          actions: [
            "codestar-connections:CreateConnection",
            "codestar-connections:GetInstallationUrl",
            "ec2:DeleteNetworkInterface",
            "ecr:GetAuthorizationToken",
            "ec2:DescribeDhcpOptions",
            "codestar-connections:ListConnections",
            "ec2:DescribeSecurityGroups",
            "codestar-connections:GetIndividualAccessToken",
            "ec2:CreateNetworkInterface",
            "iam:PassRole",
            "codestar-connections:ListInstallationTargets",
            "ec2:DescribeNetworkInterfaces",
            "codestar-connections:StartOAuthHandshake",
            "ec2:DescribeVpcs",
            "codestar-connections:ListHosts",
            "codestar-connections:StartAppRegistrationHandshake",
            "codestar-connections:RegisterAppCode",
            "ec2:DescribeSubnets",
            "codestar-connections:CreateHost"
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
          resources: [`arn:aws:ecr:${this.region}:${this.account}:repository/${projectOwner}-${repositoryName}-${branch}*`]
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
          sid: "ManageSecretValue",
          effect: iam.Effect.ALLOW,
          actions: ["secretsmanager:*"],
          resources: [
            `arn:aws:secretsmanager:${this.region}:${this.account}:secret:${branch}/${projectOwner}-${repositoryName}*`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageLogsOnCloudWatch",
          effect: iam.Effect.ALLOW,
          actions: [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          resources: [
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
            "ec2:DescribeVpcs"
          ],
          resources: [
            "*"
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageEC2NetworkInterface",
          effect: iam.Effect.ALLOW,
          actions: [
            "ec2:CreateNetworkInterfacePermission"
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

    const buildImage = codebuild.LinuxBuildImage.fromDockerRegistry("public.ecr.aws/h4u2q3r3/aws-codebuild-cloud-native-buildpacks:l2"); 

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
        privileged: true
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

    var iamDeployUser:iam.IUser;
    
    if (deployUserExist == 'true') {
      iamDeployUser = iam.User.fromUserName(this, `UseExistentDeployUser`, `${repositoryName}-build`);
    } else {
      iamDeployUser = new iam.User(this, `CreateBuildIAMUser`, {
        userName: `${repositoryName}-build`,
      });
  
      iamDeployUser.applyRemovalPolicy((test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN);
  
      iamDeployUser.attachInlinePolicy(
        new iam.Policy(this, `appsManageS3MediaApi`, {
          policyName: `apps-manage-s3-media-api`,
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                "s3:ListBucketMultipartUploads",
                "ecr:GetDownloadUrlForLayer",
                "s3:ListBucket",
                "ecr:UploadLayerPart",
                "s3:GetBucketAcl",
                "ecr:ListImages",
                "s3:GetBucketPolicy",
                "s3:ListMultipartUploadParts",
                "ecr:PutImage",
                "s3:PutObject",
                "s3:GetObjectAcl",
                "s3:GetObject",
                "iam:PassRole",
                "secretsmanager:GetSecretValue",
                "s3:AbortMultipartUpload",
                "ecr:BatchGetImage",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "s3:DeleteObject",
                "s3:GetBucketLocation",
                "ecr:InitiateLayerUpload",
                "s3:PutObjectAcl",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetRepositoryPolicy",
                "s3:PutBucketPolicy"
              ],
              resources: [
                `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`,
                `arn:aws:iam::${this.account}:role/*`,
                `arn:aws:ecr:${this.region}:${this.account}:repository/*`
              ]
            }),
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                "ecs:UpdateCluster",
                "ecs:UpdateService",
                "ses:*",
                "logs:*",
                "ecs:RegisterTaskDefinition",
                "ecr:GetAuthorizationToken",
                "ecs:DescribeServices",
                "codebuild:*"
              ],
              resources: [
                "*"
              ]
            })
          ]
        })
      );
  
      iamDeployUser.attachInlinePolicy(
        new iam.Policy(this, `Secretmanager`, {
          policyName: `ManageSecretsmanager`,
          statements: [
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                "secretsmanager:GetRandomPassword",
                "secretsmanager:ListSecrets"
              ],
              resources: [
                "*"
              ]
            }),
            new iam.PolicyStatement({
              effect: iam.Effect.ALLOW,
              actions: [
                "secretsmanager:*"
              ],
              resources: [
                `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`
              ]
            }),
          ]
        })
      );
    }

    const accessKey = new iam.CfnAccessKey(this, 'myAccessKey', {
      userName: iamDeployUser.userName,
    });

    new CfnOutput(this, 'accessKeyId', {value: accessKey.ref });
    new CfnOutput(this, 'secretAccessKey', { value: accessKey.attrSecretAccessKey });
  }
}