# OpenShift-Ansible Integration Lab

## 0 Introduction
### 0.1 Usecase
Today we are building a Widget inventory tracking system called WidgetFactory. It's comprised of a simple data-driven application backed by MySQL. We will start with deploying a MySQL Ansible operator which will be used for provisioning and backup/restore operations. After that, we will leverage Ansible in a CI/CD pipeline to build and deploy the WidgetFactory application.

### 0.2 Ansible and OpenShift
The goal of this lab is to show how the [OpenShift Container Platform](https://docs.openshift.com/container-platform/latest/getting_started/index.html) and [Ansible Automation](https://www.ansible.com/resources/get-started) can be leveraged together to increase innovation and accelerate delivery.

First we'll introduce how Ansible can be used to automate provisioning and maintenance tasks on OpenShift through an Ansible operator. Then we'll look at how we can leverage Ansible for application configuration and deployment as part of a CI/CD pipeline.

## 1 Install Necessary Tooling

In order to carry out the tasks required for this lab, you'll want to have the following tools installed on your system:
- git
- oc
- a text editor of your choosing

We've provided each participant with the choice of provisioning a RHEL7 VM that contains the required tools for this lab. Follow this link [here](TBD) if you want to provision a VM.

Otherwise, you can install the tools on your local machine. Git can be installed with your package manager. For example, on Fedora, CentOS, and RHEL:
```bash
yum -y install git
```

The OpenShift client (oc) can be downloaded [here](TBD). The OpenShift client is used to talk to the OpenShift environment and is a necessary tool to have for any type of development on OpenShift.

## 2 Build and Deploy the Ansible Operator

### 2.1 Ansible Operator Structure
First things first, let's clone this repo if you haven't already.
```bash
git clone https://github.com/rh-openshift-ansible-better-together/dev-track.git
```

Navigate to the `dev-track/mysql-operator` directory. Here you will see three directories and a watches.yaml file. Check out the [operator-sdk](TBD) documentation for a full overview of the ansible operator's file structure. For this lab, here's what's important to know:

| File/Dir | Purpose |
| -------- | ------- |
| build/   | Contains the Dockerfile for building the Ansible operator |
| deploy/  | Contains the OpenShift resources necessary for deploying the Ansible operator and creating the MySQL CRD (custom resource definition) |
| roles/   | Contains the Ansible roles that the operator will be running when a CR (custom resource) is created |
| watches.yaml | Configures the operator to associate a CR to a particular Ansible role |

When the Ansible operator is deployed, it will listen for MySQL CRs and will apply the Ansible role accordingly. Operators are designed to maintain the "desired state", meaning it will run on a loop and will constantly re-run the roles in accordance to the CR spec to ensure that the desired state is always reached. Therefore, it's imperative that each role be written in an idempotant and stateless manner.

### 2.2 Review Ansible Roles
Let's dive a little deeper into the actual Ansible code behind this operator. Inside the `roles/` directory, you'll find three Ansible roles:

| Role | Purpose |
| ---- | ------- |
| mysql | Deploy a single-node MySQL server |
| mysqlbackup | Initiate an ad-hoc or timed backup of the MySQL database |
| mysqlrestore | Restore the database to a previous snapshot |

Each of these roles relies heavily on the [k8s](TBD), [k8s_facts](TBD), and [k8s_status](TBD) Ansible modules, which are leveraged in this lab to create OpenShift resources, get information on existing resources, and set CR statuses.

Feel free to check out each role in greater detail. When you're finished, let's build the Ansible operator!

### 2.3 Build and Push the Ansible Operator
We need to turn the operator code into a Docker image so that it can be deployed onto OpenShift. To do this, we can leverage the operator-sdk to easily build the operator.

On the command line, navigate to the `dev-track/mysql-operator` directory. Then run the build subcommand of the operator-sdk:
```bash
operator-sdk build <openshift-registry>/namespace/image
```

<Explain why the build command is necessary and why it can't be done with just docker build>

Now that the operator is built, let's push it to the OpenShift cluster with Docker.
```bash
docker login <openshift-registry>
docker push <openshift-registry>/namespace/image
```

### 2.4 Deploy the Ansible Operator
Now that the image has been built and is now in the OpenShift registry, let's deploy it in your project. If you recall, the `deploy/` directory contains resources required for the operator to function properly. It contains the service account, role, and rolebindings required to create and get the OpenShift resources that it will be in charge of managing, and it contains the deployment spec of the operator itself. Use the `oc` tool to create the resources:
```bash
oc login <cluster-url>
oc create -f mysql-operator/deploy/service_account.yaml
oc create -f mysql-operator/deploy/role.yaml
oc create -f mysql-operator/deploy/role_binding.yaml
oc create -f mysql-operator/deploy/operator.yaml
```

The Ansible operator is very lightweight and should spin up very quickly! Normally you would also have to create CRDs (custom resource definition) in order for the operator to reconcile its `watches.yaml` spec, but this was already done for you because it requires cluster-admin privileges (TODO: check that this is true and that they can't just create namespace-scoped CRDs)

## 3 Deploy a MySQL Server
Now that the Ansible operator is deployed, it's super easy to deploy a MySQL server onto OpenShift! First, let's check out the MySQL CR:
```bash
cat mysql-operator/deploy/crds/mysql/mysql_cr.yaml
```

This is a simple MySQL custom resource that when created will be picked up by the operator and trigger it to run the `mysql` role. Let's create the resource with:
```bash
oc create -f mysql-operator/deploy/crds/mysql/mysql_cr.yaml
```

You should get a message saying that the MySQL resource was created. Our MySQL instance should be up soon - right now it's running the corresponding Ansible role. We can see this role in action by checking out the operator logs:
```bash
oc logs --follow $(oc get po | grep operator | awk '{print $1}')
```
There's probably a less ugly way to do that ^^

When the role is finished, you should see something like `ansible-runner exited successfully` in the logs, as well as a fresh MySQL instance in your project. Now that the instance is created, let's move on to deploying the WidgetFactory application. We'll come back to the operator later to demonstrate a backup and recovery after we have some data to work with.

## 4 Deploy the WidgetFactory application
(TODO: Should we also write a pipeline for deploying the mysql-operator?)
One thing that OpenShift excels at, among many, is integration with Jenkins to provide a CI/CD platform. We can leverage Jenkins and Ansible together to build the WidgetFactory application and deploy it to OpenShift.

### 4.1 Auto-deploy Jenkins
OpenShift provides out-of-the-box Jenkins integration by auto-provisioning a Jenkins instance when a BuildConfig of type `JenkinsPipeline` is created. For this lab there are two pipelines:

| Pipeline | Purpose |
| ---- | ------- |
| widget-jenkins-agent/agent-pipeline.yml | Build Jenkins agent with Ansible tooling |
| widget-factory/widget-pipeline.yml | Build and deploy WidgetFactory application |

In the next sections, we'll create the BuildConfig resources and build the WidgetFactory application

### 4.2 Create widget-jenkins-agent
Before we can run the application pipeline, we need to build a Jenkins agent with Ansible tooling. Let's create the necessary resources with:
```bash
oc process -f widget-jenkins-agent/agent-pipeline.yml --param=SOURCE_REF=master | oc apply -f -
```

In the web console, you should see the Jenkins master pod spinning up. Wait until that Jenkins instance is ready (blue circle around pod numbers), and then run:
```bash
oc start-build widget-jenkins-agent-pipeline
```

It won't be necessary to log into Jenkins, but if you want to log in and explore, you login credentials will be the same as your OpenShift login.

### 4.3 Review Application
The WidgetFactory application code is under `widget-factory/`. It's a simple spring-data service. One controller is set up as a `spring-data-rest` interface that autoconfigures CRUD operations on our `Widget` object. There is also a second controller that allows for building more custom queries.

### 4.4 Ansible OpenShift Applier
TODO: We might want to scrap the applier in favor for the k8s module, as that's what we're using for the Ansible operator. Judging the many tutorials over Ansible operator, the k8s module is the best practice. Might as well remain consistent.

### 4.5 Deploy Application
Now that the Ansible agent is created and the Jenkins pod is up and running, we're now ready to deploy our application:
```bash
oc process -f widget-factory/widget-pipeline.yml --param=SOURCE_REF=master | oc apply -f -
oc start-build widget-factory-pipeline --follow
```

From here, `oc` will output the build logs to stdout. When the build is finished, the command will terminate and you should see the WidgetFactory pod in the OpenShift UI. 

When the app started up, it persisted many different widgets to the MySQL instance we created earlier. Let's return our focus back to the Ansible operator to perform a data snapshot of the database.

## 5 Back up the MySQL Database
### 5.1 MysqlBackup Overview
If you recall, the operator that we created earlier contains a role called `mysqlbackup`. This role is capable of taking both ad-hoc and timed hot, logical backups of the MySQL database. The backup is triggered when a `MysqlBackup` CR is created in the project. 

Check out the `mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml` resource and notice its `spec:` stanza. Key/value pairs under spec: are defined as extra vars to the Ansible role. Notice how this CR has a `interval_minutes: 2` defined on its spec. This passes the `interval_minutes` var to the role, which tells Ansible to take a backup every x number of minutes. If you check out `mysql-operator/roles/mysqlbackup/defaults/main.yml`, you'll find that the default value for this var is `0`, which means that the backup will not be timed but rather will be a single, ad-hoc backup.

For this lab, the `mysqlbackup` role will take each backup on a separate PVC.

### 5.2 Initiate a Timed Backup
Let's see this backup role in action! We'll use the MysqlBackup spec defined in the given `mysqlbackup_cr.yaml`, which will take a backup of the database every 2 minutes. Begin the backup process with:
```bash
oc create -f mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```

This will create an OpenShift cronjob that is responsible for mounting a brand new PVC every `interval_minutes`. It will keep `max_backups` PVCs in your project (defined in the `defaults/` of the mysqlbackup role). Feel free to observe this process with `oc describe cronjob mysql-backup` and `oc get pvc`. Wait until at least one backup pvc is created, then continue to the next part of the lab.

## 6 Restore the MySQL Database
Here, we'll try to simulate a disaster recovery scenario in which data is lost from the database and a restore operation must take place.

### 6.1 Delete data from MySQL database
The WidgetFactory application exposes a very dangerous endpoint called `/deleteall`, which will delete all the data in the database (TODO: Endpoint is not created yet). Why the devs thought this would be a good idea, I don't know. In any case, this will be a great way to test out the restore function of the Ansible operator. Let's hit this endpoint with: 
```bash
curl <WidgetFactory route>/deleteall
```

### 6.2 Find the Appropriate Backup PVC
As you can recall, we have a timed backup running in the background. As a result, one of those backup PVCs could contain a backup of the empty database, which wouldn't do much good. (TODO: so we probably need a way to show the backup sql script that will actually show the backup sql script that a DBA would find and determine the right backup to use)

Find the name of the PVC with the script we want to use for the backup, then continue to the next step.

### 6.3 Restore the MySQL Database
Find the MysqlRestore CR at `mysql-backup/deploy/crds/mysqlrestore/mysqlrestore_cr.yaml`. In the spec you'll find a `mysql_backup_pvc` key defined under the spec that will be passed as an extra var to the Ansible role. Provide the name of the PVC that you found in section 6.2 here. Then create the CR with:
```bash
oc create -f mysql-backup/deploy/crds/mysqlrestore/mysqlrestore_cr.yaml
```

This will create an OpenShift job that will mount the backup PVC. It will connect to the MySQL database and will apply the backup script to restore the contents of the database.

TODO: Should probably provide instructions to prove that the script was applied.

# 7 Thank You!
Thank you for attending the OpenShift/Ansible Better Together lab! Hopefully you learned more about how Ansible and OpenShift can be leveraged together to allow deployments and maintenance to be a breeze! To learn more: <provide links>