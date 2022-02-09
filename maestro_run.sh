#!/bin/bash

re_repo_url="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+)(.git)*$"
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
