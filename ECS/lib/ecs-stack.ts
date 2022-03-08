import {
  Tags,
  Stack,
  StackProps,
  RemovalPolicy,
  aws_s3 as s3,
  aws_ec2 as ec2,
  aws_ecr as ecr,
  aws_ecs as ecs,
  aws_iam as iam,
  aws_logs as logs,
  aws_ecs_patterns as ecs_patterns,
  aws_secretsmanager as secretsmanager,
  CfnOutput,
  aws_elasticloadbalancingv2 as elbv2,
  aws_datasync
} from 'aws-cdk-lib';

import { ECRDeployment, DockerImageName } from 'cdk-ecr-deployment';
import { Construct } from 'constructs';

export class EcsStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    
    const test = this.node.tryGetContext('TEST');
    const vpcId = this.node.tryGetContext('VPC_ID');
    const branch = this.node.tryGetContext('BRANCH').toLowerCase();
    const projectSecrets = JSON.parse(this.node.tryGetContext('PROJECT_SECRETS'));
    const projectOwner = this.node.tryGetContext('PROJECT_OWNER').toLowerCase();
    const repositoryName = this.node.tryGetContext('REPOSITORY_NAME').toLowerCase();
    const projectTags = JSON.parse(this.node.tryGetContext('TAGS'));
    const appUserExist = this.node.tryGetContext('APP_USER_EXIST').toLowerCase();
    const privateSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS_PRIVATE'));
    const publicSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS_PUBLIC'));
    
    let subnetsArns:any = [];
    
    Tags.of(this).add('Project', repositoryName);
    Tags.of(this).add('Branch', branch);

    for (let i = 0; i < projectTags.length; i++) {
      let element = projectTags[i];
      Tags.of(this).add(element[0], element[1]);
    }

    const ecsLogGroup = new logs.LogGroup(this, `CreateCloudWatchEcsLogGroup-${branch}`, {
      logGroupName: `/ecs/${projectOwner}-${repositoryName}-${branch}-web`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
    });
    
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
      subnetType: ec2.SubnetType.PRIVATE
    });

    for (let subnet of Ids.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`);
    }

    const codeBuildProjectRole = iam.Role.fromRoleArn(this, 'UseBuildServiceRole',
                                  `arn:aws:iam::${this.account}:role/service-role/${projectOwner}-${repositoryName}-${branch}-image-build-service-role`);

    const securityGroup = ec2.SecurityGroup.fromLookupByName(this, 'ImportedApplicationSecurityGroup',
    `${repositoryName}-${branch}-app-sg`, vpc);
    
    const ecrRepository = new ecr.Repository(this, `CreateNewECRRepository-${branch}`, {
      repositoryName: `${projectOwner}-${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });

    new ECRDeployment(this, 'DeployDockerImage', {
      src: new DockerImageName('public.ecr.aws/g5e8c9c6/veezor_demo'),
      dest: new DockerImageName(ecrRepository.repositoryUri),
    });

    const cluster = new ecs.Cluster(this, `CreateCluster-${branch}`, {
      clusterName: `${projectOwner}-${repositoryName}-${branch}`,
      vpc: vpc,
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

    const taskDefinition = new ecs.FargateTaskDefinition(this, `CreateTaskDefinition-${branch}`, {
      family: `${projectOwner}-${repositoryName}-${branch}-web`,
      memoryLimitMiB: 512,
      cpu: 256,
      taskRole: taskRole,
      executionRole: executionRole,
    });

    var taskSecrets:{[key: string]: ecs.Secret} = {};
    
    for (var key in projectSecrets) {
      taskSecrets[key] = ecs.Secret.fromSecretsManager(secrets,key);
    };

    taskDefinition.addContainer(`${projectOwner}-${repositoryName}-${branch}`, {
      image: ecs.ContainerImage.fromEcrRepository(ecrRepository),
      containerName: `${projectOwner}-${repositoryName}`,
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

    const securityGroupLoadBalancer =  ec2.SecurityGroup.fromLookupByName(this, 'ImportedLoadBalancerSecurityGroup', `${repositoryName}-${branch}-lb-sg`, vpc);

    const lb = new elbv2.ApplicationLoadBalancer(this, 'CreateLoadBalancer', {
      vpc: vpc,
      internetFacing: true,
      loadBalancerName: `${repositoryName.replace('_','-')}-${branch}-lb`,
      securityGroup: securityGroupLoadBalancer
    });
        
    const loadBalancerFargateService = new ecs_patterns.ApplicationLoadBalancedFargateService(this, `CreatLoadBalancer-${branch}`, {
      cluster: cluster,
      serviceName: `${repositoryName}-${branch}-web`,
      desiredCount: 1,
      taskDefinition: taskDefinition,
      assignPublicIp: false,
      securityGroups: [securityGroup],
      loadBalancer: lb,
      targetProtocol: elbv2.ApplicationProtocol.HTTP,
      protocol: elbv2.ApplicationProtocol.HTTP,
      publicLoadBalancer: true,
      listenerPort: 80,
      redirectHTTP: false,
      deploymentController: {
        type: ecs.DeploymentControllerType.CODE_DEPLOY,
      },
    });
    
    loadBalancerFargateService.targetGroup.configureHealthCheck({
      path: "/",
    });
  }
}