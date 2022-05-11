import {
  Tags,
  Stack,
  StackProps,
  RemovalPolicy,
  CfnOutput,
  aws_ec2 as ec2,
  aws_logs as logs,
  aws_iam as iam
} from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class VpcStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const test = this.node.tryGetContext('TEST');
    const vpcName = this.node.tryGetContext('VPC_NAME').toLowerCase();
    const projectTags = JSON.parse(this.node.tryGetContext('TAGS'));

    for (let i = 0; i < projectTags.length; i++) {
      let element = projectTags[i];
      Tags.of(this).add(element[0], element[1]);
    }

    const vpc = new ec2.Vpc(this, `${vpcName}-vpc`, {
      cidr: this.node.tryGetContext('VPC_CIDR'),
      enableDnsHostnames: true,
      enableDnsSupport: true,
      natGateways: 1,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: `public`,
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 24,
          name: `private`,
          subnetType: ec2.SubnetType.PRIVATE_WITH_NAT,
        }
      ]
    });

    new CfnOutput(this, 'VpcId', { value: vpc.vpcId });
  }
}