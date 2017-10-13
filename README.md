# Twig AWS Riglet

This setup will create a CloudFormation, AWS CodePipeline/CodeBuild/CodeDeploy powered Rig on AWS.

## Setup

### Dependencies

For using this repo you'll need:

* The AWS CLI, and working credentials: `brew install awscli && aws configure`
* Setup `.make` for local settings

This can either be done by copying settings from the template `.make.example`
and save in a new file `.make`:

```ini
DOMAIN = <Domain to use for Foundation>
KEY_NAME = <Existing EC2 SSH key name>
OWNER = <The owner of the stack, either personal or corporate>
PROFILE = <AWS Profile Name>
PROJECT = <Project Name>
REGION = <AWS Region>
REPO_TOKEN = <Github OAuth or Personal Access Token>
```

Or also done interactively through `make .make`.

For the "real" twig riglet:

```ini
DOMAIN = buildit.tools
KEY_NAME = buildit-twig-ssh-keypair-us-east-1 (example: actual is dependent upon actual riglet/region)
OWNER = buildit
PROFILE = default (or whatever your configured profile is named)
PROJECT = twig
REGION = us-east-1
REPO_TOKEN = <ask a team member>
```

Confirm everything is valid with `make check-env`

### Firing it up

#### Feeling Lucky?  Uber-Scripts!
There are a couple of scripts that automate the detailed steps covered further down.  They hide the
details, which is both a good and bad thing.

* `./create-standard-riglet.sh` to create a full riglet with standard environments (integration/staging/production).
* `./delete-standard-riglet.sh` to delete it all.

#### Individual Makefile Targets
If you're not feeling particularly lucky, or you want to understand how things are assembled, or 
create a custom environment, or what-have-you, follow this guide.


##### Building it up
The full build pipeline requires at least integration, staging, and production environments, so the typical
installation is:

* Run `make create-foundation ENV=integration`
* Run `make create-compute ENV=integration`
* Run `make create-db ENV=integration`
* Run `make create-foundation ENV=staging`
* Run `make create-compute ENV=staging`
* Run `make create-db ENV=integration`
* Run `make create-foundation ENV=production`
* Run `make create-compute ENV=production`
* Run `make create-db ENV=integration`
* Run `make create-build REPO=<repo_name> REPO_BRANCH=<branch> CONTAINER_PORT=<port> HEALTH_CHECK_PATH=<path> LISTENER_RULE_PRIORITY=<priority>`, same options for status: `make status-build` and outputs `make outputs-build`
  * REPO is the repo that hangs off buildit organization (e.g "twig-api")
  * REPO_BRANCH is the branch name for the repo - MUST NOT CONTAIN SLASHES!
  * CONTAINER_PORT is the port that the application exposes (e.g. 8080)
  * HEALTH_CHECK_PATH is the path that is checked by the target group to determine health of the container (e.g. `/ping`)
  * LISTENER_RULE_PRIORITY is the priority of the the rule that gets created in the ALB.  While these won't ever conflict, ALB requires a unique number across all apps that share the ALB.  See [Application specifics](#application-specifics)
  * (optional) PREFIX is what goes in front of the URI of the application.  Defaults to OWNER but for the "real" riglet should be set to blank (e.g. `PREFIX=`)


##### Tearing it down

To delete everything, in order:

* Run `make delete-app ENV=<environment> REPO=<repo_name> REPO_BRANCH=<branch>` to delete the App stacks.
  * if you deleted the pipeline first, you'll find you can't delete the app stacks because the role that created them is gone.  You'll have to manually delete via aws cli and the `--role-arn` override
* Run `make delete-build REPO=<repo_name> REPO_BRANCH=<branch>` to delete the Pipline stack.
* Run `make delete-compute ENV=<environment>` to delete the Compute stack.
* Run `make delete-foundation ENV=<environment>` to delete the Foundation stack.
* Run `make delete-deps ENV=<environment>` to delete the required S3 buckets.


### Checking on things
* Check the outputs of the activities above with `make outputs-foundation ENV=<environment>`
* Check the status of the activities above with `make status-foundation ENV=<environment>`
* Check AWS CloudWatch Logs for application logs.  In the Log Group Filter box search 
  for for <owner>-<application> (at a minimum).  You can then drill down on the appropriate
  log group and individual log streams.

## Environment specifics
For simplicity's sake, the templates don't currently allow a lot of flexibility in network CIDR ranges.
The assumption at this point is that these VPCs are self-contained and "sealed off" and thus don't need 
to communicate with each other, thus no peering is needed and CIDR overlaps are fine.

Obviously, the templates can be updated if necessary.

| Environment  | CidrBlock |
| :---         | :---      |
| integration  | 10.10.0.0/16  |
| staging      | 10.20.0.0/16  |
| production   | 10.30.0.0/16  |

## Application specifics

| Application | ContainerPort | ListenerRulePriority 
| :---        | :---          | :---
| twig-api    | 3000          | 100                  
| twig        | 80            | 200 

## Scaling
There are a few scaling knobs that can be twisted.  Minimalistic defaults are established in the templates,
but the values can (and should) be updated in specific running riglets later.

For example, production should probably be scaled up, at least horizontally, if only for high availability, 
so increasing the number of cluster instances to at least 2 (and arguably 4) is probably a good idea, as well 
as running a number of ECS Tasks for each twig-api and twig (web).  ECS automatically distributes the Tasks
to the ECS cluster instances.

To make changes in the CloudFormation console, find the appropriate stack, select it, select 
"update", and specify "use current template".  On the parameters page make appropriate changes and 
submit.

### Application Scaling Parameters

| Parameter                    | Scaling Style | Stack                      | Parameter  
| :---                         | :---          | :---                       | :---
| # of ECS cluster instances   | Horizontal    | compute-ecs                | ClusterSize/ClusterMaxSize
| Size of ECS Hosts            | Vertical      | compute-ecs                | InstanceType    |
| Number of Tasks              | Horizontal    | app (once created by build)| TaskDesiredCount


### Database Scaling Parameters
And here are the available *database* scaling parameters.  
 
| Parameter             | Scaling Style | Stack         | Parameter  
| :---                  | :---          | :---          | :---
| Size of Couch Host    | Vertical      | db-couch      | InstanceType  |


## Architectural Decisions

We are documenting our decisions [here](../master/docs/architecture/decisions)
