import { Tags, Stack, StackProps, RemovalPolicy, aws_s3 as s3, aws_ec2 as ec2, aws_ecr as ecr, aws_ecs as ecs, aws_iam as iam, aws_logs as logs, aws_ecs_patterns as ecs_patterns, aws_secretsmanager as secretsmanager, CfnOutput } from 'aws-cdk-lib';
import { ISecret } from 'aws-cdk-lib/aws-secretsmanager';
import { ECRDeployment, DockerImageName } from 'cdk-ecr-deployment';
import { Construct } from 'constructs';

export class EcsStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    let test = this.node.tryGetContext('TEST');
    let vpcId = this.node.tryGetContext('VPC_ID');
    let branch = this.node.tryGetContext('BRANCH').toLowerCase();
    let projectSecrets = this.node.tryGetContext('PROJECT_SECRETS');
    let projectOwner = this.node.tryGetContext('PROJECT_OWNER').toLowerCase();
    let repositoryName = this.node.tryGetContext('REPOSITORY_NAME').toLowerCase();

    let subnetsArns:any = [];
    
    Tags.of(this).add('Project', `${repositoryName}`);
    Tags.of(this).add('Branch', `${branch}`);

    const ecsLogGroup = new logs.LogGroup(this, `CreateCloudWatchEcsLogGroup-${branch}`, {
      logGroupName: `/ecs/${projectOwner}-${repositoryName}-${branch}-web`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
    });
    
    const vpc = ec2.Vpc.fromLookup(this, 'UseExistingVPC', {
      vpcId:vpcId
    });

    const vpcSubnets = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE
    });

    for (let subnet of vpcSubnets.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`)
    };

    const codeBuildProjectRole = iam.Role.fromRoleArn(this, 'UseBuildServiceRole',
                                  `arn:aws:iam::${this.account}:role/service-role/${projectOwner}-${repositoryName}-image-build-service-role`);

    const secrets = new secretsmanager.Secret(this, `CreateSecrets-${branch}`, {
      secretName: `${branch}/${projectOwner}-${repositoryName}`,
      description: `Used to project ${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
      generateSecretString: {
        secretStringTemplate: projectSecrets,
        generateStringKey: 'random'
      }
    });
    
    secrets.grantRead(codeBuildProjectRole);

 
    const securityGroup = new ec2.SecurityGroup(this, `CreateApplicationSecurityGroup-${branch}`, {
      securityGroupName: `${repositoryName}-${branch}-sg`,
      allowAllOutbound: true,
      vpc: vpc
    });

    const iamUser = new iam.User(this, `CreateIAMUser-${branch}`, {
      userName: `${repositoryName}-${branch}`,
    });

    iamUser.attachInlinePolicy(
      new iam.Policy(this, `accessToS3BucketFrontend-${branch}`, {
        policyName: `access-to-s3-bucket-fronend-${branch}`,
        statements: [ 
          new iam.PolicyStatement({
            effect: iam.Effect.ALLOW,
            actions: [
              "s3:PutObject",
              "s3:ListBucket",
              "s3:DeleteObject",
              "s3:PutObjectAcl",
              "s3:PutBucketPolicy"
            ],
            resources: ["*"],
          }),
        ]
      })
    );

    iamUser.attachInlinePolicy(
      new iam.Policy(this, `appsManageS3Media-${branch}`, {
        policyName: `apps-manage-s3-media-${branch}`,
        statements: [
          new iam.PolicyStatement({
            effect: iam.Effect.ALLOW,
            actions: [
              "ecr:GetDownloadUrlForLayer",
              "ecr:UploadLayerPart",
              "ecr:ListImages",
              "ecr:PutImage",
              "iam:PassRole",
              "secretsmanager:GetSecretValue",
              "ecr:BatchGetImage",
              "ecr:CompleteLayerUpload",
              "ecr:DescribeRepositories",
              "ecr:InitiateLayerUpload",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetRepositoryPolicy",
            ],
            resources: [
              `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`,
              `arn:aws:iam::${this.account}:role/*`,
              `arn:aws:ecr:${this.region}:${this.account}:*`
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
    )

    iamUser.attachInlinePolicy(
      new iam.Policy(this, `${projectOwner}${repositoryName}Secretmanager-${branch}`, {
        policyName: `${projectOwner}-${repositoryName}-secretmanager-${branch}`,
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
    
    const ecrRepository = new ecr.Repository(this, `CreateNewECRRepository-${branch}`, {
      repositoryName: `${projectOwner}-${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });

    new ECRDeployment(this, 'DeployDockerImage', {
      src: new DockerImageName('public.ecr.aws/g5e8c9c6/veezor_demo'),
      dest: new DockerImageName(ecrRepository.repositoryUri),
    });

    const cluster = new ecs.Cluster(this, `CreateCluster-${branch}`, {
      clusterName: `${repositoryName}-${branch}`,
      vpc: vpc,
    });
    
    const taskRole = new iam.Role(this, `CreateTaskRole-${branch}`, {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      roleName: `${projectOwner}-${repositoryName}-${branch}-service-role`
    });

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
          actions: ["secretsmanager:GetSecretValue"],
          resources: [
            `arn:aws:secretsmanager:${this.region}:${this.account}:secret:*`
          ]
        })
      ]
    });

    const executionRole = new iam.Role(this, `CreateExecutionRole-${branch}`, {
      assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      roleName: `ecsTaskExecutionRole-${branch}`,
      managedPolicies: [
        executionRolePolicies
      ]
    });

    const taskDefinition = new ecs.FargateTaskDefinition(this, `CreateTaskDefinition-${branch}`, {
      family: `${projectOwner}-${repositoryName}-${branch}-web`,
      memoryLimitMiB: 512,
      cpu: 256,
      taskRole: taskRole,
      executionRole: executionRole,
    });

    
    var taskSecrets:{[key: string]: ecs.Secret} = {};
    
    for (var key in JSON.parse(projectSecrets)) {
      taskSecrets[key] = ecs.Secret.fromSecretsManager(secrets,key);
    };

    taskDefinition.addContainer(`${projectOwner}-${repositoryName}-${branch}`, {
      image: ecs.ContainerImage.fromEcrRepository(ecrRepository),
      containerName: `${projectOwner}-${repositoryName}-${branch}`,
      memoryLimitMiB: 512,
      logging: new ecs.AwsLogDriver({
        streamPrefix: "ecs",
        logGroup: ecsLogGroup
      }),
      secrets: taskSecrets,
      portMappings: [{
        hostPort: 3000,
        protocol: ecs.Protocol.TCP,
        containerPort: 3000,
      }]
    });

    const loadBalancerFargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(this, `CreatLoadBalancer-${branch}`, {
      cluster: cluster,
      serviceName: `${repositoryName}-${branch}-web`,
      desiredCount: 1,
      publicLoadBalancer: true,
      taskDefinition: taskDefinition,
      assignPublicIp: false,
      loadBalancerName: `${repositoryName.replace('_','-')}-${branch}-lb`,
      securityGroups: [securityGroup]
    });

    loadBalancerFargateService.targetGroup.configureHealthCheck({
      path: "/",
    });
  }
}