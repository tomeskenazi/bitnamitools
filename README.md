# Bitnami CI Project

This repository contains one prototype script resulting of the analysis of the project given by Bitnami to support the discovery of fleet machines that are not in use anymore in the development pipeline. Alongside is provided a corresponding Jenkins job configuration file to ease the integration and the scheduling of that tool.

## Introduction
Bitnami uses many clouds to support their development, tests, build and release strategies. The actual infrastructure, as well as development and test and other integration and release tools in use are unknown. This simplified exercise does not require in-depth knowledge of the latter and assumptions need to be addressed. As a result, several improvements could be suggested to better the script efficiency.

### Infrastructure
The Infrastructure where the script will run needs to clarified.

Requirements:
- A cloud system could be chosen for this prototype among GCE, AWS and Azure.

Assumptions: 
- Cloud chosen: Only **Amazon EC2 VM** instances are covered
- OS chosen: standard **Linux Red Hat Enterprise** distributions are deployed

Improvement Suggestions:
- All clouds used by Bitnami would need to be covered. It impacts discovery methods implemented in the script
- All Linux distributions and other Operating Systems (if any) should be covered and tested.

### Coding Management System (CMS)
Any project should use a CMS to version-control its resources.

Requirements:
- Code Management System: GIT via github will store the project code and documentation

Assumptions:
- The repository is **exposed as public** to avoid spending extra costs for this exercise. As a result, no credentials are needed to pull the project anywhere. No sensitive data is stored in this repository.
- **No formal release process** is in place to deploy the script, i.e. no use of tagging or branches.
- **No formal directory structure** is required. Only one script, a README file and a Jenkins job config file do not require any more complex file organisation strategy.

Improvements:
- The Repository should be private if sensitive data gets stored. Otherwise, such an exposure could be valuable to the company if open-sourcing is an option.
- This script would need to be integrated to any relevant repository and not held separate from the rest of the automation toolchain. This is to reduce inter-dependency issues with complementary tools.
- A Release process should be in place to tag stable versions every time a significant milestone is passed.


### Instance Discovery Methods
The script needs methods to detect instances that are currently active in the cloud.

Requirements:
- no explicit requirement

Assumptions:
- **No other deployment or provisioning methods are in place**
- **AWS API can be used** to run admin aws commands to discover VM instances. In this case, the only command that will be used is *describe-instances*. This requires the *AWS Shell* to be installed on the instance where the script will be run from. 

Improvements:
- Other deployment and provisioning tools such as Docker or chef/puppet may be used on exisiting instances. They could be used as an extra criteria to detect the use of an instance by a developer/tester. Relevant discovery methods should be added to cover those cases.

### Criteria On Obsolescence
Criteria needs to be established to detect whether a running VM instance is being used or not by a developer.

Requirements:
- none

Assumptions:
- **Connection logs** keep trace of every time a developer connects to the machine. By analysing the logs from the *last* command, it is possible to know if a user is still connected or when was the last connection made.
- **Jenkins Slaves could be running on the machine**: Instead of logging onto the instances, developers could use those machines as Jenkins slave nodes to build/test/deploy their projects. Checking the last time those projects ran can help determine if an instance is still in use.
- The **number of days** an instance has not been used is chosen as a mechanism to detect machines that need to be flagged as *not in use* anymore.

Improvements:
- As highlighted in the previous section, other tools may be used by developers that could be useful to detect any activity: VM Management tools or Provisioning tools may have APIs that could be used to detect whether the instance is still in use.
- Listening ports should be taken into account to verify if any other instances are trying to connect to the instances. Some other processes may be running for test purposes that are not taken into account by the current scenarios
- Analysing and keeping track of running processes would be an efficient indicator of any recent activity. A refined list of what is meant by 'active processes' could be maintained over time to refine this criteria.


### Script Coding
Requirements:
- None

Assumptions:
- **No guards against input parameters needed**: the script has been written to be run by sysadmins and therefore verifying the validity of its input arguments is not required.
- **Bash shell language**: As RedHat Enterprise distributions are used, bash could be used as standard and does not require any additional language package to be installed. The binary location is */usr/bin/bash* by default.
- The script is **version-controlled**. For traceability reasons and easy rollback, this script should not be directly integrated to a CI tool, but kept external. It is also easier to expose it as an open-source project if desired.

Improvements:
- This script needs to be made more robust against errors raised by the remote ssh commands used throughout. Although that script was tested and some errors have been anticipated, it is probably not covering all error cases. For such a sensitive script, more effort should be put on this side.
- This script should be amended to run on any type of OS and distributions used at Bitnami.



### Integration to CI tools
Requirements:
- This script must be integratable to Jenkins.

Assumptions:
- **Jenkins** is used as the CI tool of choice at Bitnami.
- This script **runs on Jenkins master** instance to avoid interacting with slave nodes. This avoids deploying the *AWS shell* on other instances.
- The following plugins will need to be installed: **GIT Plugin** and **SSH Slaves Plugin**. This is to allow Jenkins to pull the latest script from the master branch
- **Jenkins job is kept simple**: to avoid complicating version-controlling, Jenkins jobs should be kept simple. In this case, source control pulls the latest code available in the CMS, the build steps are limited to running the script, and post-build steps are inexistent.

Improvements:
- Other CI tools (such as Travis or CircleCI) should be considered if used at Bitnami.
- This script should be scheduled to run on a regular basis, weekly for instance.
- The Jenkins job could be enriched by:
  - Adding post-build alerts (email notification for instance) to notify a sysadmin of the machines flagged as 'not used anymore'.
  - Keeping track of flagged machines to make sure they are not used anymore. For instance, after having been flagged three times, they could automatically be suspended and a notification sent to or sysadmin to deal with the final decommissioning phase or to the last users who logged into the flagged instances before it could be fully decommisionned
  - Keeping track of the hostnames, logged-in users, and the number of times VM instances have been flagged as unused: this is useful to automate any decommissioning and generate statistics (number of instances flagged, decommissioned, new instances, types of machines, etc.). This could be achieved by connecting to an external database for instance.
- Automatically decommissioning these instances are not recommended without making sure all acceptable criteria have been covered. Such a feature could be an extension of this script or another dedicated script. In all cases, a final warning notification should be sent to a sysadmin before the script wipes the instances for good.


## Getting Started

This section will run through running and testing instructions.

### Prerequisites

The script provided runs in a Linux shell environment. As long as Bash is available (*/usr/bin/bash*), no pre-requisites are required.

### How-to Use

```
Usage: ./checkInstances.sh [options]
   ./checkInstances.sh --aws-id=<AWS_ACCESS_KEY_ID> --aws-key=<AWS_SECRET_ACCESS_KEY> --aws-region=<AWS_DEFAULT_REGION> --sys-ssh=<SSH_FILENAME> --sys-usr=<USERNAME> --nbdays <NB_DAYS>

Parameters:
	AWS_ACCESS_KEY_ID: The AWS API Access ID used to connect to the EC2 Cloud
	AWS_SECRET_ACCESS_KEY: The AWS API Access Key used to connect to the EC2 Cloud
	AWS_DEFAULT_REGION: The AWS Region
	SSH_FILENAME: filename of the private SSH key used to connect to EC2 instances
	USERNAME: user name associated with the private key used to connect to EC2 instances
	NB_DAYS: Number of days used as a criteria to flag instances as 'not in use' anymore

Extra Options:
    --help: Show the script usage help
    --verbose: Add debug traces
    --jenkins-ssh <FILENAME> & SSH key of jenkins user (default ~jenkins/.ssh/id_rsa)
    --jenkins-ws & Location of Jenkins workspace on slaves (default /home/jenkins/workspace)
```

The script will list all the AWS instances that are not flagged as active anymore. This will be output under the trace *THESE INSTANCES MAY NEED TO BE DECOMMISSIONED*
This is based on 'last' log activity and jenkins workspace if used (ssh-jenkins option required).

Example of Output (*non-verbose*):

```
Analysing instance: xxx.xx.xx.43
Analysing instance: xxx.xx.x.73
THESE INSTANCES MAY NEED TO BE DECOMMISSIONED:
ip-xxx-xx-xx-43.eu-west-1.compute.internal (xxx.xx.xx.43)
ip-xxx-xx-x-xx.eu-west-1.compute.internal (xxx.xx.x.73)
```

Example of Output (*verbose*):

```
URRENT USER: jenkins
CURRENT IP: xxx.xx.x.xxx
AWS_ACCESS_KEY_ID: XXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
AWS_DEFAULT_REGION: eu-west-1
USER FOR AWS API ACCESS: ec2-xxxx
SSH KEYFILE FOR AWS API ACCESS: ~/.xxx/xxxxxxx.pem
SSH KEYFILE FOR JENKINS: ~jenkins/.ssh/xxx_xxx
JENKINS WORKSPACE: /home/jenkins/workspace
NB_DAYS: 1
DEBUGMODE: 1
==================================
Analysing instance: xxx.xx.xx.43
==================================
Analysing Jenkins Workspace...
-> Workspace has been used recently by a Jenkins job
/home/jenkins/workspace /home/jenkins/workspace/test_slave /home/jenkins/workspace/test_slave/testfile.txt /home/jenkins/workspace/test_slave/toto
==================================
Analysing instance: xxx.xx.x.73
==================================
Analysing Jenkins Workspace...
Analysing Last Connection Log...
---------------------------------------------------------------------------------------
LINE: dev1 pts/0 xx.xxx.xx.110 Fri Oct 6 14:48:39 2017 - Fri Oct 6 14:48:43 2017 (00:00)
LASTCONNECTIONUSER: dev1
LASTCONNECTIONTIME: Fri Oct 6 14:48:43 2017
LASTTIME: 1507301323
DIFFTIME: -74167
---------------------------------------------------------------------------------------
LINE: dev1 pts/0 xx.xxx.xx.110 Wed Oct 4 19:30:48 2017 - Wed Oct 4 19:30:51 2017 (00:00)
LASTCONNECTIONUSER: dev1
LASTCONNECTIONTIME: Wed Oct 4 19:30:51 2017
LASTTIME: 1507145451
DIFFTIME: 81705
---------------------------------------------------------------------------------------
LINE: dev1 pts/0 xx.xxx.xx.110 Wed Oct 4 19:10:27 2017 - Wed Oct 4 19:10:58 2017 (00:00)
LASTCONNECTIONUSER: dev1
LASTCONNECTIONTIME: Wed Oct 4 19:10:58 2017
LASTTIME: 1507144258
DIFFTIME: 82898
---------------------------------------------------------------------------------------
LINE: ec2-user pts/0 xxx.xx.x.149 Wed Oct 4 19:08:14 2017 - Wed Oct 4 19:08:24 2017 (00:00)
LASTCONNECTIONUSER: ec2-user
LASTCONNECTIONTIME: Wed Oct 4 19:08:24 2017
LASTTIME: 1507144104
DIFFTIME: 83052
---------------------------------------------------------------------------------------
LINE: dev1 pts/0 xx.xxx.xx.110 Wed Oct 4 19:01:23 2017 - Wed Oct 4 19:01:27 2017 (00:00)
LASTCONNECTIONUSER: dev1
LASTCONNECTIONTIME: Wed Oct 4 19:01:27 2017
LASTTIME: 1507143687
DIFFTIME: 83469
---------------------------------------------------------------------------------------
LINE: ec2-user pts/0 xx.xxx.xx.110 Wed Oct 4 18:57:22 2017 - Wed Oct 4 19:00:39 2017 (00:03)
LASTCONNECTIONUSER: ec2-user
LASTCONNECTIONTIME: Wed Oct 4 19:00:39 2017
LASTTIME: 1507143639
DIFFTIME: 83517
---------------------------------------------------------------------------------------
ALL INSTANCES SEEM IN USE
```


### Integrate it to Jenkins
Place the whole '*Check Instances*' directory in the *jobs* directory (usually */var/lib/jenkins/jobs/*) on Jenkins master, then *Reload Configuration from Disk* in the *Manage Jenkins* section.

It will create the '*Check Instances*' job for you that you need to edit for:
- Filling in default values of parameters (required if regular automatic scheduling is planned)
- Replacing the **[CUSTOMFIELD]** by the proper values needed by the script as described in the above sections.
- Remove the *--verbose* parameter is not required (should not be required for automatic scheduling)

## Testing the Script

### Setting up the Test Environment
This assumes there is no existing AWS environment and everything needs to be set from scratch.

#### Setting up the Jenkins Master instance
This instance will be used to run the script.

- Create a new instance from AWS Console, choose a default Red Hat Enterprise Release and set the security group to allow HTTP, SSH and custom 8080 ports open to secure IPs of your choice, as well as all connections to current VPC.
- Log on to the machine and run:
```
# Update System Packages
sudo yum update -y
# Install GIT
sudo yum install git
#Install JAVA
sudo yum install java
#Install PIP (required to install AWS shell)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
sudo python get-pip.py
#Install AWS-SHELL
sudo pip install aws-shell
#Install and run Jenkins
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
sudo yum install jenkins -y
sudo service jenkins start
```
- In jenkins, install the following plugins:
  - **Git Plugin** (used to pull the bitnami scripts from github)
  - **SSH Slaves plugin** (used as a method of connection between nodes)

A few extra steps are required before running the script:
- From local machine, copy the SSH key to Jenkins ssh directory. The key is required by the script to run remote shell commands:
```
scp -i <SSHKEY_FILENAME> <SSHKEY_FILENAME> <AWS_USERID>@<JENKINS_IP>:~/
```
- From Jenkins machine, move the ssh keys to the right place:
```
sudo su -
mov <SSHKEY_FILENAME> /var/lib/jenkins/.ssh/
chown jenkins:jenkins /var/lib/jenkins/.ssh/<SSHKEY_FILENAME>
```


#### Setting up a couple of developer instances
In AWS Console:
- Create two new default Red Hat Enterprise instances and set the security group to allow SSH connections open to secure IPs of your choice, as well as all connections to current VPC.
- Create two new security key-pairs for a dev user, then extract public key from downloaded pem file by locally running: ssh-keygen -y
- Log onto the new instances, run the following and fill in the *authorized_keys* file:
```
sudo adduser dev1
sudo su - dev1
mkdir .ssh
chmod 700 .ssh
vi .ssh/authorized_keys # <= insert dev1 user public key there
chmod 600 .ssh/authorized_keys
```

Do the following to add a slave node to one of the instances only:
In AWS Console:
- Create a new security key-pair for jenkins user (that we would call *jenkins.pem*), then extract public key from downloaded pem file by locally running: ssh-keygen -y

From Local machine
- Copy the private key to Jenkins Server
```
scp -i <SSHKEY_FILENAME> jenkins.pem <JENKINS_IP>:~/
```

From Jenkins Server:
- Run the following:
```
# Move the ssh key to the right place
sudo su
mv jenkins.pem /var/lib/jenkins/.ssh/id_rsa
chown jenkins:jenkins /var/lib/jenkins/.ssh/id_rsa
chmod 600 /var/lib/jenkins/.ssh/id_rsa
```

On Jenkins Slave Machine:
- Run the following:
```
# Install JAVA if not already installed
sudo yum install java
# Add Jenkins user and prepare ssh
sudo useradd jenkins -U -s /bin/bash
sudo su - jenkins
mkdir .ssh
chmod 700 .ssh
vi .ssh/authorized_keys <= insert jenkins user ssh public key
chmod 600 .ssh/authorized_keys
```
- Update */etc/sudoers* by adding the line:
```
jenkins         ALL=(ALL)       NOPASSWD: ALL
```

On Jenkins HTTP Server:
- Configure a new host using ssh connection method. Use ssh key authentication by creating new credentials using the default .ssh location. Deactivate any host key verification strategy.
- Create a new test job and assign it a specific new node to run on. 


### Running the tests

Two sets of tests could be envisaged:
- From the above setup, the script will run to verify both Jenkins workspace and *last* connection log on one dev instance, and only the *last* connection log on the other instance.
- Test the criteria detection (number of days without changes) by modifying the file status of Jenkins workspace as well as fake a change in the *last* system command to have a variety of test cases.

#### Locally:
As long as *AWS Shell* is installed on a Linux environment with bash installed, please refer to the "*How to Use*" section to test this script.

#### As Part of Jenkins CI:
Run the '*Check Instances*' job wihtout forgetting to activate the *verbose* parameter.


## Authors

* **Thomas Eskenazi** - *Initial work* - As part of an exercise requested by Bitnami

## License

<Not specified>

## Acknowledgments

* Thanks for helping me brushing up my skills after a year and a half of traveling abroad.
