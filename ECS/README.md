- PROJECT_OWNER     - 
- REPOSITORY_NAME   - 
- BRANCH            - 
- VPC_ID            - 
- PROJECT_SECRETS   -   
- TEST              - set `removalPolicy` on resources, cannot be used on production stage.

$ cdk deploy -c 'PROJECT_OWNER=veezor' -c 'REPOSITORY_NAME=veezor_demo' -c 'BRANCH=production' -c 'VPC_ID=vpc-234324234' -c 'PROJECT_SECRETS=\{\}' -c 'TEST=true' --profile