- VPC_CIDR - default: 10.0.0.0/16
- STACK_NAME - Used to deploy this CloudFormation multiple times on same account using another stack name. default: VpcStack.
- VPC_NAME - defines the name of the VPC to be created.
- TEST - set `removalPolicy` on resources, cannot be used on production stage.

$ cdk deploy -c 'STACK_NAME=VpcStack' -c 'VPC_CIDR=10.0.0.0/16' -c 'TEST=true' -c 'VPC_NAME=<project_name>'
