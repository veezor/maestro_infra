
Parameters needed as context (-c)
    - VPC_ID - Id from the VPC to be used.
    - TEST - (true/false) Set `removalPolicy` on resources, cannot be used on production stage.
    - GITHUB_OWNER
    - GITHUB_REPOSITORY

$ cdk deploy -c 'TEST=true' -c 'VPC_ID=vpc-a58dbcdd' -c 'PROJECT_OWNER=veezor' -c 'REPOSITORY_NAME=veezor_demo' --profile <account>