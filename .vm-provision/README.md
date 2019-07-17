# Provisioning of Client VMs for BetterTogether Workshops #

## 0 Introduction
This is the code to provision the necessary client VMs in AWS that will be used by students while working on the Dev Track of the OpenShift + Ansible Better Together lab! 

### Clone Repo
On your local wokstation (desktop/laptop) clone this repo
```bash
git clone https://github.com/rh-openshift-ansible-better-together/dev-track.git $HOME/dev-track
cd $HOME/dev-track/.vm_provision
```
### Requirements
Before you can create any EC2 instance(s), the following is implied:
- You have an AWS account
- You know how to provision instances via AWS SDK cli ( boto3 )
- You have setup your `$HOME/.aws/credentials` and `$HOME/.aws/config` 
- You can provision more than 50+ ec2 intances of type t2-medium
- You have a Route 53 hosted zone in your AWS account
- You know how to create VPC, Security Groups, Key Pairs, etc..
- You know how to run Ansible (duhhh)

#### Modify aws.yml 
In order to properly provision the necessary client VM's, the file located in `vars/aws.yml` needs information from your AWS account
```bash
vi vars/aws.yml
```

#### Create EC2 instances
Now that you have properly filled in all the required information, its time to create the VM's
```bash
ansible-playbook provision.yml
```
Your Ansible playbook should finish successfully.

### Check your AWS account
If your EC2 instances are in state `running`, then proceed to spot check a few VMs by login into them.
After spot checking a few VMs, and all is well, please update the main README.md with the right information
