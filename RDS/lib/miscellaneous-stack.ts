import {
  Stack, CfnOutput, StackProps, RemovalPolicy, aws_ec2 as ec2, aws_rds as rds, aws_secretsmanager as secretsmanager } from 'aws-cdk-lib';
import { IInstanceEngine } from 'aws-cdk-lib/aws-rds';
import { Construct } from 'constructs';

export class MiscellaneousStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    let test = this.node.tryGetContext('TEST');
    let vpcId = this.node.tryGetContext('VPC_ID');
    let branch = this.node.tryGetContext('BRANCH').toLowerCase();
    let githubOwner = this.node.tryGetContext('GITHUB_OWNER').toLowerCase();
    let githubRepository = this.node.tryGetContext('GITHUB_REPOSITORY').toLowerCase();
    let database_engine = this.node.tryGetContext('DATABASE_ENGINE').toLowerCase();

    let dbEngine = rds.DatabaseInstanceEngine.MYSQL;
    let dbPort = 3306;

    if(database_engine == 'postgres') {
      dbEngine = rds.DatabaseInstanceEngine.POSTGRES
      dbPort = 5432;
    }
   
    const vpc = ec2.Vpc.fromLookup(this, 'UseExistingVPC', {
      vpcId: vpcId
    });

    const secrets = secretsmanager.Secret.fromSecretNameV2(this, 'DBSecret', `${branch}/${githubOwner}-${githubRepository}`);

    const securityGroup = ec2.SecurityGroup.fromLookupByName(this, `UseApplicationSecurityGroup-${branch}`, `${githubRepository}-${branch}-sg`, vpc);

    const securityGroupDB = new ec2.SecurityGroup(this, `CreateDataBaseSecurityGroup`, {
      securityGroupName: `database-${branch}-sg`,
      allowAllOutbound: false,
      vpc: vpc
    })
    
    // securityGroupDB.addEgressRule(securityGroup, ec2.Port.udp(dbPort));
    
    const rdsInstance = new rds.DatabaseInstance(this, `${githubRepository}-${branch}-db`, {
      instanceIdentifier: `${githubRepository}-${branch}`,
      engine: dbEngine,
      credentials: {
        username: secrets.secretValueFromJson('USERNAME').toString(),
        password: secrets.secretValueFromJson('PASSWORD')
      },
      removalPolicy: (test=='true') ? RemovalPolicy.DESTROY : RemovalPolicy.RETAIN,
      vpc: vpc,
      databaseName: `${githubRepository}${branch}db`,
      securityGroups: [
        securityGroupDB
      ]
    });
    
    new CfnOutput(this, 'RdsEndpoint', { value: rdsInstance.instanceEndpoint.hostname });
  }
}