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
CERT_ARN = <unique ID of TLS certificate defined in AWS Certificate manager>
```

Or also done interactively through `make .make`.

For the "real" twig riglet:

```ini
DOMAIN = buildit.tools
KEY_NAME = buildit-twig-ssh-keypair-us-east-1 (example: actual is dependent upon actual riglet/region)
OWNER = buildit
PROFILE = default (or whatever your configured profile is named)
PROJECT = twig
REGION = us-west-2
REPO_TOKEN = <ask a team member>
CERT_ARN = <unique ID of buildit.tools TLS certificate in us-west-2>
```

Confirm everything is valid with `make check-env`

### Firing it up

#### Feeling Lucky?  Uber-Scripts!
There are a couple of scripts that automate the detailed steps covered further down.  They hide the
details, which is both a good and bad thing.

* `./create-standard-riglet.sh [branch name]` to create a full riglet with standard environments (integration/staging/production).
* `./delete-standard-riglet.sh [branch name]` to delete it all.


#### Individual Makefile Targets
If you're not feeling particularly lucky, or you want to understand how things are assembled, or 
create a custom environment, or what-have-you, follow this guide.

##### Building it up
The full build pipeline requires at least integration, staging, and production environments, so the typical
installation is:

###### Execution/runtime Infrastructure and Environments
* Run `make create-foundation ENV=integration`
  * (optional) EMAIL_ADDRESS to send alarms to
* Run `make create-compute ENV=integration`
* Run `make create-db ENV=integration`
* Run `make create-foundation ENV=staging`
  * (optional) EMAIL_ADDRESS to send alarms to
* Run `make create-compute ENV=staging`
* Run `make create-db ENV=staging`
* Run `make create-foundation ENV=production`
  * (optional) EMAIL_ADDRESS to send alarms to
* Run `make create-compute ENV=production`
* Run `make create-db ENV=production`


###### Build "Environments"
In this case there's no real "build environment", unless you want to consider AWS services an environment.
We are using CodePipeline and CodeBuild, which are build _managed services_ run by Amazon (think Jenkins in 
the cloud, sort-of).  So what we're doing in this step is creating the build pipeline(s) for our code repo(s).

* Run `make create-build REPO=<repo_name> REPO_BRANCH=<branch> CONTAINER_PORT=<port> HEALTH_CHECK_PATH=<path> LISTENER_RULE_PRIORITY=<priority>`, same options for status: `make status-build` and outputs `make outputs-build`
  * REPO is the repo that hangs off buildit organization (e.g "twig-api")
  * REPO_BRANCH is the branch name for the repo - MUST NOT CONTAIN SLASHES!
  * CONTAINER_PORT is the port that the application exposes (e.g. 8080)
  * HEALTH_CHECK_PATH is the path that is checked by the target group to determine health of the container (e.g. `/ping`)
  * LISTENER_RULE_PRIORITY is the priority of the the rule that gets created in the ALB.  While these won't ever conflict, ALB requires a unique number across all apps that share the ALB.  See [Application specifics](#application-specifics)
  * (optional) PREFIX is what goes in front of the URI of the application.  Defaults to OWNER but for the "real" riglet should be set to blank (e.g. `PREFIX=`)

###### Deployed Applications
It gets a little weird here.  You never start an application yourself in this riglet.  The build environments 
actually dynamically create "app" stacks in CloudFormation as part of a successful build.  These app stacks 
represent deployed and running code (they basically map to ECS Services and TaskDefinitions).

##### Tearing it down

To delete a running riglet, in order:

* Run `make delete-app ENV=<environment> REPO=<repo_name> REPO_BRANCH=<branch>` to delete any running App stacks.
  * if for some reason you deleted the pipeline first, you'll find you can't delete the app stacks because 
    the role under which they were created was deleted with the pipeline. In this case you'll have to create 
    a temporary "god role" and manually delete the app via the `aws cloudformation delete-stack` command, 
    supplying the `--role-arn` override.
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
There are a few scaling "knobs" that can be twisted in running stacks, using CloudFormation console.  
Conservative defaults are established in the templates, but the values can (and should) be updated 
in specific running riglets later.

For example, production ECS should probably be scaled up, at least horizontally, if only for high availability, 
so increasing the number of cluster instances to at least 2 (and arguably 4) is probably a good idea, as well 
as running a number of ECS Tasks for each twig-api and twig (web).  ECS automatically distributes the Tasks
to the ECS cluster instances.

The same goes for the CouchDB instance, but in this case the only scaling option is vertical:  give it
a larger box.  Note that a resize of the instance type does not result in any lost data.

The above changes can be made in the CloudFormation console.  To make changes find the appropriate stack, 
select it, choose "update", and specify "use current template".  On the resulting parameters page make appropriate 
changes and submit.

It's a good idea to always pause on the final submission page to see the predicted actions for your changes 
before proceeding, or consider using a Change Set.

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


## Maintenance
Except in very unlikely and unusual circumstances _all infrastructure/build changes should be made via CloudFormation 
updates_ either by submitting template file changes via the appropriate make command, or by changing parameters in
the existing CloudFormation stacks using the console.  Failure to do so will cause the running environment(s) to diverge 
from the as-declared CloudFormation resources and may (will) make it impossible to do updates in 
the future via CloudFormation.

> An alternative to immediate execution of stack updates in the CloudFormation console is to use the "change set" 
> feature. This creates a pending update to the CloudFormation stack that can be executed immediately, or go through an 
> approval process.  This is a safe way to preview the "blast radius" of planned changes, too before committing.

### Scaling
See section above.

### Updating ECS AMIs
The ECS cluster runs Amazon-supplied AMIs.  The AMIs are captured in a map in the `compute-ecs/main.yaml`
template.  Occasionally, Amazon releases newer AMIs and marks existing instances as out-of-date in the
ECS console.  To update to the latest set of AMIs, run the `./cloudformation/scripts/ecs-optimized-ami.sh`
script and copy the results into the `compute-ecs/main.yaml` template's `AWSRegionToAMI` mapping. 


## Architectural Decisions

We are documenting our decisions [here](../master/docs/architecture/decisions)
