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
  aws_secretsmanager as secretsmanager
} from 'aws-cdk-lib';

import { IVpc } from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export class EcsStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const test = this.node.tryGetContext('TEST');
    const vpcId = this.node.tryGetContext('VPC_ID');
    const branch = this.node.tryGetContext('BRANCH').toLowerCase();
    const projectSecrets = this.node.tryGetContext('PROJECT_SECRETS');
    const projectOwner = this.node.tryGetContext('PROJECT_OWNER').toLowerCase();
    const repositoryName = this.node.tryGetContext('REPOSITORY_NAME').toLowerCase();
    const projectTags = JSON.parse(this.node.tryGetContext('TAGS'));
    const appUserExist = this.node.tryGetContext('APP_USER_EXIST').toLowerCase();
    const privateSubnetIds = JSON.parse(this.node.tryGetContext('VPC_SUBNETS'));

    let subnetsArns:any = [];

    Tags.of(this).add('Project', repositoryName);
    Tags.of(this).add('Branch', branch);

    for (let i = 0; i < projectTags.length; i++) {
      let element = projectTags[i];
      Tags.of(this).add(element[0], element[1]);
    }

    new logs.LogGroup(this, `CreateCloudWatchEcsLogGroup-${branch}`, {
      logGroupName: `/ecs/${projectOwner}-${repositoryName}-${branch}-web`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
    });

    const vpc = (privateSubnetIds.length > 0) ?
      ec2.Vpc.fromVpcAttributes(this, 'UseExistingVpc', {
        availabilityZones: ec2.Vpc.fromLookup(this, 'GetAZsFromSubnet', { vpcId: vpcId }).availabilityZones,
        vpcId: vpcId,
        privateSubnetIds: privateSubnetIds
      }) :
      ec2.Vpc.fromLookup(this, 'UseExistingVPC', {
        vpcId: vpcId
      })

    const Ids = vpc.selectSubnets({
      subnetType: ec2.SubnetType.PRIVATE
    });

    for (let subnet of Ids.subnets) {
      subnetsArns.push(`arn:aws:ec2:${this.region}:${this.account}:subnet/${subnet.subnetId}`);
    }

    new secretsmanager.Secret(this, `CreateSecrets-${branch}`, {
      secretName: `${branch}/${projectOwner}-${repositoryName}`,
      description: `Used to project ${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
      generateSecretString: {
        secretStringTemplate: projectSecrets,
        generateStringKey: 'random'
      }
    });
       
    new ecr.Repository(this, `CreateNewECRRepository-${branch}`, {
      repositoryName: `${projectOwner}-${repositoryName}-${branch}`,
      removalPolicy: test=='true' ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });

    new ecs.Cluster(this, `CreateCluster-${branch}`, {
      clusterName: `${projectOwner}-${repositoryName}-${branch}`,
      vpc: vpc
    });
  }
}