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
    -c "BRANCH=$repository_branch" \
    -c "PROJECT_OWNER=$project_owner" \
    -c "REPOSITORY_NAME=$repository_name" \
    -c "GIT_SERVICE=$git_service" \
    -c "TAGS=$tags" \
    -c "VPC_SUBNETS_PRIVATE"=$vpc_subnets_private \
    -c "VPC_SUBNETS_PUBLIC"=$vpc_subnets_public \
    -c "LOADBALANCER_SCHEME"=$loadbalancer_scheme \
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

  aws ec2 create-security-group \
    --tag-specifications $aws_cli_tags \
    --group-name "${repository_name,,}-${repository_branch}-app-sg" \
    --description 'APP SG' \
    --vpc-id $vpc_id \
    --profile $aws_profile
  aws ec2 create-security-group \
    --tag-specifications $aws_cli_tags \
    --group-name "${repository_name,,}-${repository_branch}-codebuild-sg" \
    --description 'CODEBUILD SG' \
    --vpc-id $vpc_id \
    --profile $aws_profile
  aws ec2 create-security-group \
    --tag-specifications $aws_cli_tags \
    --group-name "${repository_name,,}-${repository_branch}-lb-sg" \
    --description 'LOADBALANCER SG' \
    --vpc-id $vpc_id \
    --profile $aws_profile
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
  has_tags=$(cat $json_file | jq 'has("tags")')
  has_test=$(cat $json_file | jq 'has("test")')
  has_test=$(cat $json_file | jq 'has("test")')
  has_test=$(cat $json_file | jq 'has("test")')
  has_test=$(cat $json_file | jq 'has("test")')
  has_test=$(cat $json_file | jq 'has("test")')
  

  has_test=$(cat $json_file | jq 'has("test")')
  if [ $has_test == true ]; then
    echo "Key test found - OK"

    test_value=$(cat $json_file | jq '.test')
    if [[ "$test_value" == true ]] || [[ "$test_value" = false ]]; then
      echo "Test value is: $test_value - OK"
    else
      echo "Test value is not valid, acceptable is (true|false). - FAIL"
      exit 0
    fi
  else
    echo "Key test not found - FAIL"
    exit 0
  fi

  has_environment=$(cat $json_file | jq 'has("environment")')
  if [ $has_environment == true ]; then
    echo "Key environment found - OK"

    environment_value=$(cat $json_file | jq '.environment')
    if [[ "$environment_value" == \"production\" ]] || [[ "$environment_value" == \"staging\" ]]; then
      echo "Environment value is: $environment_value - OK"
    else
      echo "Environment value $environment_value is not valid, acceptable value is ('production'|'staging'). - FAIL"
      exit 0
    fi
  else
    echo "Key environment not found - FAIL"
    exit 0
  fi

  has_secrets=$(cat $json_file | jq 'has("secrets")')
  if [ $has_secrets == true ]; then
    echo "Key secrets found - OK"

    secrets_value=$(cat $json_file | jq '.secrets')
    echo "Secrets value is: $secrets_value"
  else
    echo "Key secrets not found - FAIL"
    exit 0
  fi

  has_repository=$(cat $json_file | jq 'has("repository")')
  if [ $has_repository == true ]; then
    echo "Key repository found - OK"

    has_repository_url=$(cat $json_file | jq '.repository' | jq 'has("url")' )
    if [ $has_repository_url == true ]; then
      echo "Key repository.url found - OK"

      repository_url_value=$(cat $json_file | jq '.repository.url')
      if [[ $repository_url_value =~ $re_repository_url ]]; then
        echo "repository.url value is: $repository_url_value - OK"
      else
        echo "repository.url value is not valid, acceptable value is a github ou bitbucket repository url with https://... - FAIL"
        exit 0
      fi
    else
      echo "Key repository.url not found - FAIL"
      exit 0
    fi

    has_repository_branch=$(cat $json_file | jq '.repository' | jq 'has("branch")' )
    if [ $has_repository_branch == true ]; then
      echo "Key repository.branch found - OK"

      repository_branch_value=$(cat $json_file | jq '.repository.branch')
      if [[ $repository_branch_value = \"production\" ]] || [[ $repository_branch_value = \"staging\" ]]; then
        echo "repository.branch value is: $repository_branch_value - OK"
      else
        echo "repository.branch value is not valid, acceptable value is ('production'|'staging') - FAIL"
        exit 0
      fi
    else
      echo "Key repository.branch not found - FAIL"
      exit 0
    fi
  else
    echo "Key repository not found - FAIL"
    exit 0
  fi

  has_vpc=$(cat $json_file | jq 'has("vpc")')
  if [ $has_vpc == true ]; then
    echo "Key vpc found - OK"

    has_vpc_name=$(cat $json_file | jq '.vpc' | jq 'has("name")' )
    if [ $has_vpc_name == true ]; then
      echo "Key vpc.name found - OK"

      vpc_name_value=$(cat $json_file | jq '.vpc.name')
      if [[ $vpc_name_value != null ]]; then
        echo "vpc.name value is: $vpc_name_value - OK"
      else
        echo "vpc.name value is not valid - FAIL"
        exit 0
      fi
    else
      echo "Key vpc.name not found - FAIL"
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