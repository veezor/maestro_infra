#!/bin/bash

create_vpc() {
  cd VPC
  cdk deploy -c "STACK_NAME=$project_owner" -c "VPC_CIDR=$vpc_cidr" -c "TEST=$test" -c "VPC_NAME=$vpc_name" --profile $aws_profile
  cd ..
}

create_codebuild() {
  cd codebuild
  cdk deploy -c "TEST=$test" -c "VPC_ID=$vpc_id" -c "PROJECT_OWNER=$project_owner" -c "REPOSITORY_NAME=$repository_name" --profile $aws_profile
  cd ..
}

create_ecs() {
  cd ECS
  cdk deploy -c "PROJECT_OWNER=$project_owner" -c "REPOSITORY_NAME=$repository_name" -c "BRANCH=$repository_branch" -c "VPC_ID=$vpc_id" -c "PROJECT_SECRETS=$secrets" -c "TEST=$test" --profile $aws_profile
  cd ..
}

re_repository_url="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+)(.git)*$"
re_cidr="^([0-9]{1,3}\.){3}[0-9]{1,3}($|/(16|24))$"

#echo Installing NPM dependencies in all projects...
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

test=$(cat env.json | jq -r '.test')
secrets=$(cat env.json | jq -r '.secrets')
repository_url=$(cat env.json | jq -r '.repository.url')
repository_branch=$(cat env.json | jq -r '.repository.branch')
vpc_cidr=$(cat env.json | jq -r '.vpc.cidr')
vpc_id=$(cat env.json | jq -r '.vpc.id')
vpc_name=$(cat env.json | jq -r '.vpc.name')
aws_profile=$(cat env.json | jq -r '.aws.profile')

if [[ $repository_url =~ $re_repository_url ]]; then    
  protocol=${BASH_REMATCH[1]}
  separator=${BASH_REMATCH[2]}
  hostname=${BASH_REMATCH[3]}
  project_owner=${BASH_REMATCH[4]}
  repository_name=${BASH_REMATCH[5]}
else
  echo "Repository not valid. Try again."
  exit 0
fi


PS3='Please enter your choice: '
options=("VPC" "Codebuild" "ECS" "Codebuild_ECS" "ALL" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "VPC")
            echo "Only VPC will be created"
            create_vpc
            ;;
        "Codebuild")
            echo "Only Codebuild will be created"
            crete_codebuild
            ;;
        "ECS")
            echo "Only ECS will be created"
            create_ecs
            ;;
        "Codebuild_ECS")
            echo "Codebuild and ECS will be created. (vpc.id needs to exist on env.json)"
            create_codebuild
            create_ecs
            ;;
        "ALL")
            echo "VPC, Codebuild and ECS will be created"
            create_vpc
            create_codebuild
            create_ecs
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

