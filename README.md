terraform init

# Vars.tfvars pode ser qualquer arquivo com as configurações do cliente
terraform plan -var-file=staging/vars.tfvars
terraform apply -var-file=staging/vars.tfvars
terraform destroy -var-file=staging/vars.tfvars



