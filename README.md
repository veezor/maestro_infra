
# First, export the AWS_ACCESS_KEY_ID and AWS_SECRET_KEY

terraform init -var-file=clients/sample/staging.tfvars

terraform plan -var-file=clients/sample/staging.tfvars -out clients/sample/staging.bin
terraform apply clients/sample/staging.bin
terraform destroy clients/sample/staging.bin