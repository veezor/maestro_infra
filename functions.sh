run_bootstrap() {
  cd bootstrap
  cdk bootstrap \
    --profile $aws_profile 
  cd ..
}

create_vpc() {
  cd VPC
  cdk deploy \
    -c "PROJECT_OWNER=$project_owner" \
    -c "VPC_CIDR=$vpc_cidr" \
    -c "TEST=$test" \
    -c "VPC_NAME=$vpc_name" \
    -c "ENVIRONMENT=$environment" \
    -c "TAGS=$tags" \
    --profile $aws_profile
  cd ..
}

create_codebuild() {
  vpc_id_env=$(cat $json_file | jq -r '.vpc.id')
  read -p "Enter VPC ID [$vpc_id_env]: " vpc_id
  vpc_id=${vpc_id:-$vpc_id_env}
  
  cd codebuild
  cdk deploy -c "TEST=$test" \
    -c "VPC_ID=$vpc_id" \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "GIT_SERVICE=$git_service" \
    -c "TAGS=$tags"
    --profile $aws_profile
  cd ..
}

create_ecs() {
  vpc_id_env=$(cat $json_file | jq -r '.vpc.id')
  read -p "Enter VPC ID [$vpc_id_env]: " vpc_id
  vpc_id=${vpc_id:-$vpc_id_env}

  cd codebuild
  cd ECS
  cdk deploy \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "BRANCH=$repository_branch" \
    -c "VPC_ID=$vpc_id" \
    -c "PROJECT_SECRETS=$secrets" \
    -c "TEST=$test" \
    -c "TAGS=$tags" \
    --profile $aws_profile
  cd ..
}

update_code() {
  git fetch
  git pull --rebase
}

update_npm() {
  echo Installing NPM dependencies in all projects...
  cd VPC
  npm install
  cd ../codebuild
  npm install
  cd ../ECS
  npm install
  cd ../RDS
  npm install
  cd ..
  echo All NPM dependencies installed.
}