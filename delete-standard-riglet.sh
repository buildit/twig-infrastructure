#!/usr/bin/env bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BRANCH=master

cat .make

printf "\n${YELLOW}***${NC} For a clean deletion you must delete the images contained in the ECS repo for this riglet.\n\n"

printf "${RED}This will delete the riglet environment described above.${NC}\n"
read -p "Are you sure you want to proceed?  " -n 1 -r
echo

API_REPO=twig-api
WEB_REPO=twig

if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "Y" | make delete-app ENV=integration REPO=${API_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-app ENV=staging REPO=${API_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-app ENV=production REPO=${API_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-build REPO=${API_REPO} REPO_BRANCH=${BRANCH}

  echo "Y" | make delete-app ENV=integration REPO=${WEB_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-app ENV=staging REPO=${WEB_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-app ENV=production REPO=${WEB_REPO} REPO_BRANCH=${BRANCH}
  echo "Y" | make delete-build REPO=${WEB_REPO} REPO_BRANCH=${BRANCH}

  echo "Y" | make delete-compute ENV=integration
  echo "Y" | make delete-foundation ENV=integration
  echo "Y" | make delete-compute ENV=staging
  echo "Y" | make delete-foundation ENV=staging
  echo "Y" | make delete-compute ENV=production
  echo "Y" | make delete-foundation ENV=production
fi
