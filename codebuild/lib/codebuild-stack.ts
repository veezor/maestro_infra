import {
  Tags,
  Stack,
  StackProps,
  RemovalPolicy,
  aws_ecr as ecr,
  aws_ec2 as ec2,
  aws_ecs as ecs,
  aws_iam as iam,
  aws_logs as logs,
  aws_codebuild as codebuild,
  aws_secretsmanager as secretsmanager
} from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as yaml from 'yaml';
import * as fs from 'fs';

export class CodebuildStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const test = this.node.tryGetContext('TEST');
    let repositoryUrl = this.node.tryGetContext('REPOSITORY_URL');
    const projectOwner = this.node.tryGetContext('PROJECT_OWNER').toLowerCase();
    const repositoryName = this.node.tryGetContext('REPOSITORY_NAME').toLowerCase();
    const gitService = this.node.tryGetContext('GIT_SERVICE').toLowerCase();
    const projectTags = JSON.parse(this.node.tryGetContext('TAGS'));
    const branch = this.node.tryGetContext('BRANCH');
    const privateSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS_PRIVATE'));
    const publicSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS_PUBLIC'));
    const vpcId = this.node.tryGetContext('VPC_ID');
    const loadbalancerScheme = this.node.tryGetContext('LOADBALANCER_SCHEME');
    const efsVolumes = JSON.parse(this.node.tryGetContext('EFS_VOLUMES'));
    const projectSecrets = JSON.parse(this.node.tryGetContext('PROJECT_SECRETS'));
    
    let subnetsArns:any = [];

    Tags.of(this).add('Project', repositoryName);
    Tags.of(this).add('Branch', branch);
    
    for (let i = 0; i < projectTags.length; i++) {
      let element = projectTags[i];
      Tags.of(this).add(element[0], element[1]);
    }

    const vpc = (privateSubnetIds.length > 0) ?
      ec2.Vpc.fromVpcAttributes(this, 'UseExistingVpc', {
        availabilityZones: ec2.Vpc.fromLookup(this, 'GetAZsFromSubnet', { vpcId: vpcId }).availabilityZones,
        vpcId: vpcId,
        privateSubnetIds: privateSubnetIds,
        publicSubnetIds: publicSubnetIds
      }) :
      ec2.Vpc.fromLookup(this, 'UseExistingVPC', {
        vpcId: vpcId
      });

    const Ids = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS
    });

    for (let subnet of Ids.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`);
    }
    
    const codeBuildLogGroup = new logs.LogGroup(this, `CreateCloudWatchcodeBuildLogGroup`, {
      logGroupName: `/aws/codebuild/${projectOwner}-${repositoryName}-${branch}-image-build`,
      removalPolicy: (test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });
    
    var gitSource = codebuild.Source.gitHub({
        owner: projectOwner,
        repo: repositoryName,
        branchOrRef: branch
      });
    
    if (gitService == 'bitbucket') {
      gitSource = codebuild.Source.bitBucket({
        owner: projectOwner,
        repo: repositoryName,
        branchOrRef: branch
      });
    }

    const pubIds = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PUBLIC
    });

    const priIds = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS
    });

    for (let subnet of priIds.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`); 
    }

    const codeBuildManagedPolicies = new iam.ManagedPolicy(this, `CreateCodeBuildPolicy`, {
      managedPolicyName: `CodeBuild-${projectOwner}-${repositoryName}-${branch}`,
      statements: [
        new iam.PolicyStatement({
          sid: "ManageAppAutoScaling",
          effect: iam.Effect.ALLOW,
          actions: [
            "application-autoscaling:RegisterScalableTarget",
            "application-autoscaling:PutScalingPolicy",
            "application-autoscaling:DescribeScalingPolicies"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageCloudwatchAlarms",
          effect: iam.Effect.ALLOW,
          actions: [
            "cloudwatch:DescribeAlarms"
          ],
          resources: [`arn:aws:cloudwatch:${this.region}:${this.account}:alarm:*`]
        }),
        new iam.PolicyStatement({
          sid: "ManageCodebuild",
          effect: iam.Effect.ALLOW,
          actions: [
            "codebuild:BatchPutCodeCoverages",
            "codebuild:BatchPutTestCases",
            "codebuild:CreateReport",
            "codebuild:CreateReportGroup",
            "codebuild:UpdateReport",
            "codebuild:BatchGetBuilds"
          ],
          resources: [`arn:aws:codebuild:${this.region}:${this.account}:report-group/${projectOwner}-${repositoryName}-image-build-*`]
        }),
        new iam.PolicyStatement({
          sid: "ManageEC2",
          effect: iam.Effect.ALLOW,
          actions: [
            "ec2:CreateTags",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeInternetGateways",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcs"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageEC2Network",
          effect: iam.Effect.ALLOW,
          actions: [
            "ec2:CreateNetworkInterface",
            "ec2:CreateNetworkInterfacePermission",
            "ec2:DeleteNetworkInterface"
          ],
          resources: [
            `arn:aws:ec2:${this.region}:${this.account}:network-interface/*`,
            `arn:aws:ec2:${this.region}:${this.account}:subnet/*`
          ],
          conditions: {
            StringEquals: {
              "ec2:Subnet": subnetsArns,
              "ec2:AuthorizedService": "codebuild.amazonaws.com"
            }
          }
        }),
        new iam.PolicyStatement({
          sid: "ManageECR",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken",
            "ecr:GetDownloadUrlForLayer",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart"
          ],
          resources: [`arn:aws:ecr:${this.region}:${this.account}:repository/*`]
        }),
        new iam.PolicyStatement({
          sid: "ManageECRAuthToken",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecr:GetAuthorizationToken"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageECS",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecs:CreateService",
            "ecs:CreateCluster",
            "ecs:DescribeServices",
            "ecs:DescribeClusters",
            "ecs:ListServices",
            "ecs:RegisterTaskDefinition",
            "ecs:UpdateService"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageELB",
          effect: iam.Effect.ALLOW,
          actions: [
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:CreateTargetGroup",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:AddTags",
            "elasticloadbalancing:DescribeTargetGroups"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageIAMPassRole",
          effect: iam.Effect.ALLOW,
          actions: [
            "iam:PassRole"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageIAMServiceRole",
          effect: iam.Effect.ALLOW,
          actions: [
            "iam:CreateServiceLinkedRole"
          ],
          resources: [
            `arn:aws:iam::${this.account}:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService`,
            `arn:aws:iam::${this.account}:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageKMS",
          effect: iam.Effect.ALLOW,
          actions: [
            "kms:Decrypt"
          ],
          resources: [`arn:aws:kms:${this.region}:${this.account}:key/*`]
        }),
        new iam.PolicyStatement({
          sid: "ManageLogsOnCloudwatch",
          effect: iam.Effect.ALLOW,
          actions: [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:DescribeLogGroups",
            "logs:PutLogEvents",
            "logs:TagResource"
          ],
          resources: [`arn:aws:logs:${this.region}:${this.account}:*`]
        }),
        new iam.PolicyStatement({
          sid: "ManageS3",
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject"
          ],
          resources: [
            "arn:aws:s3:::*",
            "arn:aws:s3:::*/*"
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageSecretsManager",
          effect: iam.Effect.ALLOW,
          actions: [
            "secretsmanager:DescribeSecret",
            "secretsmanager:GetSecretValue"
          ],
          resources: [`arn:aws:secretsmanager:${this.region}:${this.account}:secret:*/${projectOwner}-${repositoryName}*`]
        })
      ]
    });

    const codeBuildProjectRole = new iam.Role(this, `CreateCodeBuildProjectRole`, {
      assumedBy: new iam.ServicePrincipal('codebuild.amazonaws.com'),
      roleName: `${projectOwner}-${repositoryName}-${branch}-maestro-service`,
      path: '/service-role/',
      managedPolicies: [
        codeBuildManagedPolicies
      ]
    });
    codeBuildProjectRole.applyRemovalPolicy((test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN);

    // Role to be used wen scheduled tasks is needed on the project
    // const scheduledTaskRole = new iam.Role(this, `CreateScheduledTaskRole`, {
    //   assumedBy: new iam.ServicePrincipal('events.amazonaws.com'),
    //   roleName: 'ecsEventsRole'
    // });
    // scheduledTaskRole.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName("AmazonEC2ContainerServiceEventsRole"));

    const securityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedCodeBuildSecurityGroup', `${repositoryName}-${branch}-codebuild-sg`, vpc);

    const appSecurityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedAppSecurityGroup', `${repositoryName}-${branch}-app-sg`, vpc);

    const albSecurityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedCodeBuildAlbSecurityGroup', `${repositoryName}-${branch}-lb-sg`, vpc);

    const buildImage = codebuild.LinuxBuildImage.fromDockerRegistry("public.ecr.aws/h4u2q3r3/maestro:1.2.1"); 

    const customBuildSpec = yaml.parse(fs.readFileSync('../configs/codebuild/customBuildSpec.yaml', 'utf8'));
    
    var efsVolumesString = "";
    if (efsVolumes.length >= 1) {
      for (let i = 0; i < efsVolumes.length; i++) {
        let parameters = ""
        for (let p = 0; p < efsVolumes[i].parameters.length; p++) {
          parameters = parameters.concat(";", efsVolumes[i].parameters[p]);
        }
        efsVolumesString = efsVolumesString.concat(efsVolumes[i].name, ":", efsVolumes[i].id, "{", efsVolumes[i].destination, parameters, "}", (i +1 < efsVolumes.length) ? "," : "" );        
      }
    };

    var privateSubnetIdsString = [];
    for (let subnet of priIds.subnets) {
      privateSubnetIdsString.push(subnet.subnetId); 
    };

    var publicSubnetIdsString = [];
    for (let subnet of pubIds.subnets) {
      publicSubnetIdsString.push(subnet.subnetId); 
    };

    var codebuildEnvs:any = {
      "ALB_SCHEME": {
        value: loadbalancerScheme
      },
      "ALB_SECURITY_GROUPS": {
        value: albSecurityGroup.securityGroupId
      },
      "ALB_SUBNETS": {
        value: (loadbalancerScheme == "intenal") ? privateSubnetIdsString.join(",") : publicSubnetIdsString.join(",")
      },
      "ECS_EFS_VOLUMES": {
        value: efsVolumesString
      },
      "ECS_EXECUTION_ROLE_ARN": {
        value: `arn:aws:iam::${this.account}:role/ecsTaskExecutionRole-${repositoryName}-${branch}`
      },
      "ECS_SERVICE_SECURITY_GROUPS": {
        value: appSecurityGroup.securityGroupId
      },
      "ECS_SERVICE_SUBNETS": {
        value: privateSubnetIdsString.join(",")
      },
      "ECS_SERVICE_TASK_PROCESSES": {
        value: "web{1024;2048}:1-2,console{1024;2048}"
      },
      "ECS_TASK_ROLE_ARN": {
        value: `arn:aws:iam::${this.account}:role/${projectOwner}-${repositoryName}-${branch}-service-role`
      },
      "MAESTRO_BRANCH_OVERRIDE": {
        value: branch
      },
      "MAESTRO_DEBUG": {
        value: false
      },
      "MAESTRO_NO_CACHE": {
        value: false
      },
      "MAESTRO_ONLY_BUILD": {
        value: ""
      },
      "MAESTRO_SKIP_BUILD": {
        value: ""
      },
      "WORKLOAD_RESOURCE_TAGS": {
        value: `Owner=${projectOwner},Project=${repositoryName},Environment=${branch},Branch=${branch}`
      },
      "WORKLOAD_VPC_ID": {
        value: vpcId
      }
    };

    if ( gitService == 'bitbucket' ) {
      codebuildEnvs["BRANCH"] = { value: "#{SourceVariables.BranchName}"};
    }

    var codebuildProjectStructure: any = {};
    codebuildProjectStructure = {
      projectName: `${projectOwner}-${repositoryName}-${branch}-image-build`,
      description: `Build to project ${repositoryName}, source from github, deploy to ECS fargate.`,
      buildSpec: codebuild.BuildSpec.fromObjectToYaml(customBuildSpec),
      role: codeBuildProjectRole,
      securityGroups: [securityGroup],
      environment: {
        buildImage: buildImage,
        privileged: true,
        environmentVariables: codebuildEnvs
      },
      vpc: vpc,
      cache: codebuild.Cache.none(),
      logging: {
        cloudWatch: {
          enabled: true,
          logGroup: codeBuildLogGroup
        }
      }
    };

    if (gitService != 'bitbucket') {
      codebuildProjectStructure.source = gitSource;
    };

    new codebuild.Project(this, `CreateCodeBuildProject`, codebuildProjectStructure);

    const executionRolePolicies = new iam.ManagedPolicy(this, `CreateExecutionRolePolicy-${branch}`, {
      managedPolicyName: `Execution-Policies-${projectOwner}-${repositoryName}-${branch}`,
      statements: [
        new iam.PolicyStatement({
          sid: "EnableSSMAccess",
          effect: iam.Effect.ALLOW,
          actions: [
            "ssmmessages:CreateControlChannel",
            "ssmmessages:CreateDataChannel",
            "ssmmessages:OpenControlChannel",
            "ssmmessages:OpenDataChannel"
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
          resources: [`arn:aws:ecr:${this.region}:${this.account}:${repositoryName}/*`]
        }),
        new iam.PolicyStatement({
          sid: "GetECRAuthorizedToken",
          effect: iam.Effect.ALLOW,
          actions: [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          resources: ["*"]
        }),
        new iam.PolicyStatement({
          sid: "ManageLogsOnCloudWatch",
          effect: iam.Effect.ALLOW,
          actions: [
            "autoscaling:Describe*",
            "cloudwatch:*",
            "logs:*",
            "sns:*",
            "iam:GetPolicy",
            "iam:GetPolicyVersion",
            "iam:GetRole"
          ],
          resources: ['*']
        }),
        new iam.PolicyStatement({
          sid: "manageEvents",
          effect: iam.Effect.ALLOW,
          actions: [
            "events:PutRule",
            "events:PutTargets"
          ],
          resources: [
            `arn:aws:events:${this.region}:${this.account}:rule/*`
          ]
        }),
        new iam.PolicyStatement({
          sid: "ManageS3Bucket",
          effect: iam.Effect.ALLOW,
          actions: [
            "iam:CreateServiceLinkedRole"
          ],
          resources: [
            "arn:aws:iam::*:role/aws-service-role/events.amazonaws.com/AWSServiceRoleForCloudWatchEvents*"
          ],
          conditions: {
              StringLike: {
                "iam:AWSServiceName": "events.amazonaws.com"
              }
          }
        }),
        new iam.PolicyStatement({
          sid: "ManageSecretValue",
          effect: iam.Effect.ALLOW,
          actions: [
            "secretsmanager:*"
          ],
          resources: [
            `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`
          ]
        })
      ]
    });

    const taskRole = new iam.Role(this, `CreateTaskRole-${branch}`, {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      roleName: `${projectOwner}-${repositoryName}-${branch}-service-role`,
      managedPolicies: [
        executionRolePolicies
      ],

    });

    const executionRole = new iam.Role(this, `CreateExecutionRole-${repositoryName}-${branch}`, {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      roleName: `ecsTaskExecutionRole-${repositoryName}-${branch}`,
      managedPolicies: [
        executionRolePolicies
      ]
    });

    projectSecrets["TASK_ROLE_ARN"] = `arn:aws:iam::${this.account}:role/${projectOwner}-${repositoryName}-${branch}-service-role`;
    projectSecrets["EXECUTION_ROLE_ARN"] = `arn:aws:iam::${this.account}:role/ecsTaskExecutionRole-${repositoryName}-${branch}`;

    const secrets = new secretsmanager.Secret(this, `CreateSecrets-${branch}`, {
      secretName: `${branch}/${projectOwner}-${repositoryName}`,
      description: `Used to project ${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
      generateSecretString: {
        secretStringTemplate: JSON.stringify(projectSecrets),
        generateStringKey: 'random'
      }
    });

    secrets.grantRead(codeBuildProjectRole);

    secrets.grantRead(executionRole);

    const ecrRepository = new ecr.Repository(this, `CreateNewECRRepository-${branch}`, {
      repositoryName: `${projectOwner}-${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });
  }
}
