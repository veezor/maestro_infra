import {
  Stack,
  StackProps,
  CfnParameter,
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

    const vpcName = this.node.tryGetContext('VPC_NAME').toLowerCase();
    const test = this.node.tryGetContext('TEST');

    // const vpcName = new CfnParameter(this, "vpcName", {
    //   type: "String",
    //   description: "The name of the VPC.",
    // }).valueAsString;
    
    // const test = new CfnParameter(this, "test", {
    //   type: "String",
    //   description: "The test flag does not can be used on production stage."
    // }).valueAsString;

    console.log((test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN);

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
          subnetType: ec2.SubnetType.PRIVATE,
        },
        // {
        //   cidrMask: 24,
        //   name: `isolated`,
        //   subnetType: ec2.SubnetType.ISOLATED,
        // },
      ]
    });

    const flowlogGroup = new logs.LogGroup(this, 'CreateVPCCustomLogGroup', {
      logGroupName: `${vpcName}-vpc-loggroup`,
      removalPolicy: (test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN
    });

    const vpcFlowLogRole = new iam.Role(this, 'VPCCustomRole', {
      assumedBy: new iam.ServicePrincipal('vpc-flow-logs.amazonaws.com'),
      description: 'Created by Veezor, used for fargate projects.',
      roleName: `${vpcName}-vpc-role`,
    });
    vpcFlowLogRole.applyRemovalPolicy((test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN);

    new ec2.FlowLog(this, 'VPCFlowLog', {
      resourceType: ec2.FlowLogResourceType.fromVpc(vpc),
      destination: ec2.FlowLogDestination.toCloudWatchLogs(flowlogGroup, vpcFlowLogRole)
    });

    new CfnOutput(this, 'VpcId', { value: vpc.vpcId });
  }
}