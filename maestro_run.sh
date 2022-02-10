#!/bin/bash

source ./functions.sh

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -e|--env-file)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        json_file="$2"
        shift
      else
        echo "Error: Argument for $1 in missing" >&2
        exit 1
      fi
      ;;
    -p|--profile)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        aws_profile="$2"
        shift 2
      else
        echo "Error: Argument for $1 in missing" >&2
        exit 1
      fi
      ;;
    -*|--*=) # unsupported flags
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

re_repository_url="(github|bitbucket)(.com|.org)[\/]([^\/]+)[\/]([^\/.]+)"
re_cidr="^([0-9]{1,3}\.){3}[0-9]{1,3}($|/(16|24))$"

update_code
update_npm

test=$(cat $json_file | jq -r '.test')
secrets=$(cat $json_file | jq -r '.secrets')
repository_url=$(cat $json_file | jq -r '.repository.url')
repository_branch=$(cat $json_file | jq -r '.repository.branch')
vpc_cidr=$(cat $json_file | jq -r '.vpc.cidr')
vpc_id=$(cat $json_file | jq -r '.vpc.id')
vpc_name=$(cat $json_file | jq -r '.vpc.name')

if [[ $repository_url =~ $re_repository_url ]]; then
  git_service=${BASH_REMATCH[1]}
  project_owner=${BASH_REMATCH[3]}
  repository_name=${BASH_REMATCH[4]}
else
  echo "Repository url not valid. Try again."
  exit 0
fi

PS3='Please enter your choice: '
options=("VPC" "Codebuild" "ECS" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "VPC")
            echo "VPC will be created"
            create_vpc
            ;;
        "Codebuild")
            echo "Codebuild will be created"
            create_codebuild
            ;;
        "ECS")
            echo "ECS will be created"
            create_ecs
            ;;
        "Codebuild_ECS")
            echo "Codebuild and ECS will be created"
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

