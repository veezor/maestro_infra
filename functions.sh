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
    -c "BRANCH=$repository_branch" \
    --profile $aws_profile
  cd ..
}

create_codebuild() {
  vpc_id_env=$(cat $json_file | jq -r '.vpc.id')
  read -p "Enter VPC ID [$vpc_id_env]: " vpc_id
  vpc_id=${vpc_id:-$vpc_id_env}
  
  cd codebuild
  cdk diff -c "TEST=$test" \
    -c "VPC_ID=$vpc_id" \
    -c "BRANCH=$repository_branch" \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "GIT_SERVICE=$git_service" \
    -c "TAGS=$tags" \
    -c "VPC_SUBNETS_PRIVATE"=$vpc_subnets_private \
    -c "VPC_SUBNETS_PUBLIC"=$vpc_subnets_public \
    -c "LOADBALANCER_SCHEME"=$loadbalancer_scheme \
    -c "EFS_VOLUMES"=$efs_volumes \
    --profile $aws_profile

  cdk deploy -c "TEST=$test" \
    -c "VPC_ID=$vpc_id" \
    -c "BRANCH=$repository_branch" \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "GIT_SERVICE=$git_service" \
    -c "TAGS=$tags" \
    -c "VPC_SUBNETS_PRIVATE"=$vpc_subnets_private \
    -c "VPC_SUBNETS_PUBLIC"=$vpc_subnets_public \
    -c "LOADBALANCER_SCHEME"=$loadbalancer_scheme \
    -c "EFS_VOLUMES"=$efs_volumes \
    --profile $aws_profile
  cd ..
}

create_ecs() {
  vpc_id_env=$(cat $json_file | jq -r '.vpc.id')
  read -p "Enter VPC ID [$vpc_id_env]: " vpc_id
  vpc_id=${vpc_id:-$vpc_id_env}

  cd ECS
  cdk deploy \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "BRANCH=$repository_branch" \
    -c "VPC_ID=$vpc_id" \
    -c "PROJECT_SECRETS=$secrets" \
    -c "TEST=$test" \
    -c "TAGS=$tags" \
    -c "VPC_SUBNETS_PRIVATE"=$vpc_subnets_private \
    -c "VPC_SUBNETS_PUBLIC"=$vpc_subnets_public \
    --profile $aws_profile
  cd ..
}

create_sgs() {
  vpc_id_env=$(cat $json_file | jq -r '.vpc.id')
  read -p "Enter VPC ID [$vpc_id_env]: " vpc_id
  vpc_id=${vpc_id:-$vpc_id_env}

  # aws ec2 create-security-group \
  #   --tag-specifications $aws_cli_tags \
  #   --group-name "${repository_name,,}-${repository_branch}-app-sg" \
  #   --description 'APP SG' \
  #   --vpc-id $vpc_id \
  #   --profile $aws_profile
  aws ec2 create-security-group \
    --tag-specifications $aws_cli_tags \
    --group-name "${repository_name,,}-${repository_branch}-codebuild-sg" \
    --description 'CODEBUILD SG' \
    --vpc-id $vpc_id \
    --profile $aws_profile
  # aws ec2 create-security-group \
  #   --tag-specifications $aws_cli_tags \
  #   --group-name "${repository_name,,}-${repository_branch}-lb-sg" \
  #   --description 'LOADBALANCER SG' \
  #   --vpc-id $vpc_id \
  #   --profile $aws_profile
}

update_code() {
  git fetch
  git pull --rebase
}

update_npm() {
  echo Installing NPM dependencies in all projects...
  cd bootstrap
  npm install
  cd ../VPC
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

validate_env_file() {
  re_repository_url="(github|bitbucket)(.com|.org)[\/]([^\/]+)[\/]([^\/.]+)"
  re_vpc_cidr="^([01]?\d\d?|2[0-4]\d|25[0-5])(?:\.[01]?\d\d?|\.2[0-4]\d|\.25[0-5]){3}(\/[0-2]\d|\/3[0-2])$"
  re_vpc_id="^(vpc-)+[a-z0-9]*$"

  has_vpc=$(cat $json_file | jq 'has("vpc")')
  has_loadbalancer=$(cat $json_file | jq 'has("loadbalancer")')

  has_test=$(cat $json_file | jq 'has("test")')  
  printf "Key test "
  if [ $has_test == true ]; then
    printf "found, "
    test_value=$(cat $json_file | jq '.test')
    if [[ "$test_value" == true ]] || [[ "$test_value" = false ]]; then
      echo "with value: $test_value - OK"
    else
      echo "with no valid value, values acceptable is (true|false). - Fix it and try again."
      exit 0
    fi
  else
    printf "not found - Fix it and try again."
    exit 0
  fi

  has_environment=$(cat $json_file | jq 'has("environment")')
  printf "Key environment "
  if [ $has_environment == true ]; then
    printf "found, "

    environment_value=$(cat $json_file | jq '.environment')
    if [[ "$environment_value" == \"production\" ]] || [[ "$environment_value" == \"staging\" ]]; then
      echo "with value: $environment_value - OK"
    else
      echo "with no valid value, acceptable value is ('production'|'staging'). - Fix it and try again."
      exit 0
    fi
  else
    echo "not found - Fix it and try again."
    exit 0
  fi

  has_secrets=$(cat $json_file | jq 'has("secrets")')
    printf "Key secrets "
  if [ $has_secrets == true ]; then
    printf "found, "
    secrets_value=$(cat $json_file | jq '.secrets')
    echo "with value: $secrets_value - OK"
  else
    echo "not found - Fix it and try again."
    exit 0
  fi

  has_repository=$(cat $json_file | jq 'has("repository")')
  printf "Key repository "
  if [ $has_repository == true ]; then
    printf "found, "
    has_repository_url=$(cat $json_file | jq '.repository' | jq 'has("url")' )
    if [ $has_repository_url == true ]; then
      printf "containing a url key, "

      repository_url_value=$(cat $json_file | jq '.repository.url')
      if [[ $repository_url_value =~ $re_repository_url ]]; then
        printf "with value: $repository_url_value "
      else
        echo "with no valide value, acceptable value is a github ou bitbucket repository url with https://... - FAIL"
        exit 0
      fi
    else
      echo "and key repository.url not found - FAIL"
      exit 0
    fi

    has_repository_branch=$(cat $json_file | jq '.repository' | jq 'has("branch")' )
    if [ $has_repository_branch == true ]; then
      printf "and the branch key "

      repository_branch_value=$(cat $json_file | jq '.repository.branch')
      if [[ $repository_branch_value = \"production\" ]] || [[ $repository_branch_value = \"staging\" ]] || [[ $repository_branch_value = \"dev\" ]]; then
        echo "with value: $repository_branch_value - OK"
      else
        echo "with no valid value, acceptable value is ('production'|'staging'|'dev') - FAIL"
        exit 0
      fi
    else
      echo "is not found - FAIL"
      exit 0
    fi
  else
    echo "is not found - FAIL"
    exit 0
  fi

  has_vpc=$(cat $json_file | jq 'has("vpc")')
  printf "Key vpc "
  if [ $has_vpc == true ]; then
    printf "found, "

    has_vpc_name=$(cat $json_file | jq '.vpc' | jq 'has("name")' )
    if [ $has_vpc_name == true ]; then
      printf "containig a name key "
      vpc_name_value=$(cat $json_file | jq '.vpc.name')
      if [[ $vpc_name_value != null ]]; then
        echo "with value: $vpc_name_value - OK"
      else
        echo "with not valid value - FAIL"
        exit 0
      fi
    else
      echo " not found - FAIL"
      exit 0
    fi

    has_vpc_cidr=$(cat $json_file | jq '.vpc' | jq 'has("cidr")' )
    if [ $has_vpc_cidr == true ]; then
      echo "Key vpc.cidr found - OK"

      # vpc_cidr_value=$(cat $json_file | jq '.vpc.cidr')
      # if [[ $vpc_cidr_value =~ $re_vpc_cidr ]]; then
      #   echo "vpc.cidr value is: $vpc_cidr_value - OK"
      # else
      #   echo "vpc.cidr value $vpc_cidr_value is not valid, acceptable value is something like (10.0.1.0/16) - FAIL"
      #   exit 0
      # fi
    else
      echo "Key vpc.cidr not found - FAIL"
      exit 0
    fi

    has_vpc_id=$(cat $json_file | jq '.vpc' | jq 'has("id")' )
    if [ $has_vpc_id == true ]; then
      echo "Key vpc.id found - OK"

      # vpc_id_value=$(cat $json_file | jq '.vpc.id')
      # if [[ "$vpc_id_value" =~ $re_vpc_id ]]; then
      #   echo "vpc.id value is: $vpc_id_value - OK"
      # else
      #   echo "vpc.id value $vpc_id_value is not valid, acceptable value is something like (vpc-017e5aa9c40fda62d)"
      #   exit 0
      # fi
    else
      echo "Key vpc.id not found - FAIL"
      exit 0
    fi

    has_vpc_subnets=$(cat $json_file | jq '.vpc' | jq 'has("subnets")' )
    if [ $has_vpc_subnets == true ]; then
      echo "Key vpc.subnets found - OK"

      has_vpc_subnets_private=$(cat $json_file | jq '.vpc.subnets' | jq 'has("private")' )
      if [ $has_vpc_subnets_private == true ]; then
        echo "Key vpc.subnets.private found - OK"
      else
        echo "Key vpc.subnets.private not found - FAIL"
      fi

      has_vpc_subnets_public=$(cat $json_file | jq '.vpc.subnets' | jq 'has("public")' )
      if [ $has_vpc_subnets_public == true ]; then
        echo "Key vpc.subnets.public found - OK"
      else
        echo "Key vpc.subnets.public not found - FAIL"
      fi
    else
      echo "Key vpc.subnets not found - FAIL"
      exit 0
    fi
  else
    echo "Key vpc not found - FAIL"
    exit 0
  fi

  has_loadbalancer=$(cat $json_file | jq 'has("loadbalancer")')
  if [ $has_loadbalancer == true ]; then
    echo "Key loadbalancer found - OK"

    has_loadbalancer_scheme=$(cat $json_file | jq '.loadbalancer' | jq 'has("scheme")' )
    if [ $has_loadbalancer_scheme == true ]; then
      echo "Key loadbalancer.scheme found - OK"

      loadbalancer_scheme_value=$(cat $json_file | jq '.loadbalancer.scheme')
      if [ "$loadbalancer_scheme_value" == \"internet-facing\" ] || [ "$loadbalancer_scheme_value" == \"internal\" ]; then
        echo "loadbalancer.scheme value is: $loadbalancer_scheme_value - OK"
      else
        echo "loadbalancer.scheme value is not valid, acceptable value is (internet-facing|internal) - FAIL"
        exit 0
      fi
    else
      echo "Key loadbalancer.scheme not found - FAIL"
      exit 0
    fi
  else
    echo "Key loadbalancer not found - FAIL"
    exit 0
  fi

  has_tags=$(cat $json_file | jq 'has("tags")')
  if [ $has_tags == true ]; then
    echo "Key tags found - OK"
  else
    echo "Key loadbalancer not found - FAIL"
    exit 0
  fi

  echo "Env file is correct!"
}