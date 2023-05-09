aws logs delete-log-group --log-group-name /aws/codebuild/foco-foco-ota-production-image-build --profile foco-master
aws secretsmanager delete-secret --secret-id "production/foco-foco-ota" --force-delete-without-recovery --profile foco-master
aws ecr delete-repository --repository-name foco-foco-ota-production --force --profile foco-master
aws iam delete-role --role-name foco-foco-ota-production-maestro-service --profile foco-master
aws cloudformation delete-stack --stack-name foco-foco-ota-production-MaestroStack --profile foco-master





https://github.com/fagianijunior/ArchInstall

https://git-codecommit.us-east-1.amazonaws.com/v1/repos/foco-ota

arn:aws:codecommit:us-east-1:156769710368:foco-ota