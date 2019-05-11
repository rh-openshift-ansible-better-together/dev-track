# OpenShift-Ansible Integration Lab

## 0 Introduction
### 0.1 Usecase
Today we are building a Widget inventory tracking system called WidgetFactory. It's comprised of a simple data-driven application backed by MySQL. We will start with deploying a MySQL Ansible operator which will be used for provisioning and backup/restore operations. After that, we will leverage Ansible in a CI/CD pipeline to build and deploy the WidgetFactory application.

### 0.2 Ansible and OpenShift
The goal of this lab is to show how the [OpenShift Container Platform](https://docs.openshift.com/container-platform/latest/getting_started/index.html) and [Ansible Automation](https://www.ansible.com/resources/get-started) can be leveraged together to increase innovation and accelerate delivery.

First we'll introduce how Ansible can be used to automate provisioning and maintenance tasks on OpenShift through an Ansible operator. Then we'll look at how we can leverage Ansible for application configuration and deployment as part of a CI/CD pipeline.

## 1 SSH into Bastion Host (also should provide instructions for local dev in case wifi is slow and people are on mac/linux)
TODO

## 2 Review the Ansible Operator

### 2.1 Ansible Operator Structure
First things first, let's clone this repo if you haven't already.
```bash
git clone https://github.com/rh-openshift-ansible-better-together/dev-track.git
```

Navigate to the `dev-track/mysql-operator` directory. Here you will see three directories and a watches.yaml file. Check out the [operator-sdk](https://github.com/operator-framework/operator-sdk) documentation for a full overview of the ansible operator's file structure. For this lab, here's what's important to know:

| File/Dir | Purpose |
| -------- | ------- |
| build/   | Contains the Dockerfile for building the Ansible operator |
| deploy/  | Contains the OpenShift resources necessary for deploying the Ansible operator and creating the MySQL CRD (custom resource definition) |
| roles/   | Contains the Ansible roles that the operator will be running when a CR (custom resource) is created |
| molecule/ | Contains the Ansible playbooks to perform [Molecule](https://github.com/ansible/molecule) testing on the Ansible operator |
| watches.yaml | Configures the operator to associate a CR to a particular Ansible role |

When the Ansible operator is deployed, it will listen for MySQL CRs and will apply the Ansible role accordingly. Operators are designed to maintain the "desired state", meaning it will run on a loop and will constantly re-run the roles in accordance to the CR spec to ensure that the desired state is always reached. Therefore, it's imperative that each role be written in an idempotant and stateless manner.

### 2.2 Review Ansible Roles
Let's dive a little deeper into the actual Ansible code behind this operator. Inside the `roles/` directory, you'll find three Ansible roles:

| Role | Purpose |
| ---- | ------- |
| mysql | Deploy a single-node MySQL server |
| mysqlbackup | Initiate an ad-hoc or timed backup of the MySQL database |
| mysqlrestore | Restore the database to a previous snapshot |

Each of these roles relies heavily on the `k8s`, `k8s_facts`, and `k8s_status` Ansible modules, which are leveraged in this lab to create OpenShift resources, get information on existing resources, and set CR statuses.

Feel free to check out each role in greater detail. When you're finished, let's test the Ansible operator to make sure it will perform as expected.

## 3 Build and Test the Ansible Operator
The Ansible operator supports Molecule to perform tests on the operator in a live OpenShift cluster. Let's execute the tests to ensure that the operator is stable and ready to go.

### 3.1 Build and Push Test Operator
We need to turn the operator code into a Docker image so that it can be deployed and tested in OpenShift. We also need to make sure we include the test artifacts that are normally excluded from the trusted image. We can do this easily with the operator-sdk tool.

On the command line, navigate to the `dev-track/mysql-operator` directory. Then run the build subcommand of the operator-sdk:
```bash
operator-sdk build image-registry.openshift-image-registry.svc:5000/widgetfactory/mysql-operator --enable-tests
```

Now that the test operator is built, let's push it to the OpenShift cluster with Docker.
TODO: Docker needs to be configured to push to the internal registry, or just have them create quay accounts and push there
```bash
docker login <openshift-registry>
docker push <openshift-registry>/namespace/image
```

### 3.2 Deploy the Ansible Operator
Now that the image has been built and is now in the OpenShift registry, let's deploy it in your project. If you recall, the `deploy/` directory contains resources required for the operator to function properly. It contains the service account, role, and rolebindings required to create and get the OpenShift resources that it will be in charge of managing, and it contains the deployment spec of the operator itself. Use the `oc` tool to create the resources:
```bash
oc login <cluster-url>
oc create -f mysql-operator/deploy/service_account.yaml
oc create -f mysql-operator/deploy/role.yaml
oc create -f mysql-operator/deploy/role_binding.yaml
oc create -f mysql-operator/deploy/operator.yaml
```

The Ansible operator is very lightweight and should spin up very quickly! Normally you would also have to create CRDs (custom resource definition) in order for the operator to reconcile its `watches.yaml` spec, but this was already done for you because it requires cluster-admin privileges (TODO: check that this is true and that they can't just create namespace-scoped CRDs)

### 3.3 Explore Molecule Playbooks
The molecule playbooks at `mysql-operator/molecule` create live tests in the OpenShift environment. The `default/` folder provides a playbook consisting of tasks and assertions. The `test-cluster/` folder provides a playbook that creates the custom resources and waits for them to be ready.

Feel free to peruse the `mysql-operator/molecule/default/asserts.yml` and `mysql-operator/molecule/test-cluster/playbook.yml` plays. Then continue on to the next section.

### 3.4 Execute Operator Tests
Once you're more familiar with the tests that will be performed, let's execute the tests. Navigate to the mysql-operator folder:
```bash
cd mysql-operator
```

The operator-sdk contains a `test` subcommand that is responsible for executing the molecule tests. Make sure you're logged into the OpenShift cluster first:
```bash
oc login <master>
oc project widgetfactory
```

Then trigger the tests:
```bash
operator-sdk test cluster quay.io/adewey/mysql-operator --service-account mysql-operator
```

The command will hang until the tests complete. You should be able to see the MySQL server spin up in openshift as well as the test operator and its logs.
TODO: How to see the logs?

### 3.5 Build Runtime Operator
Now that we know the tests have passed, let's build the runtime operator.
TODO: Explain better that the test operator has tons of other things that add weight that are unnecesssary for normal operator functions
```bash
operator-sdk build image-registry.openshift-image-registry.svc:5000/widgetfactory/mysql-operator --enable-tests
docker login <openshift-registry>
docker push <openshift-registry>/namespace/image
```

TODO: Modify the molecule tests to actually remove the Mysql instance when the tests pass.
For now, just remove it with `oc delete mysql mysql`.

## 4 Deploy a MySQL Server
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

When the role is finished, you should see something like `ansible-runner exited successfully` in the logs, as well as a fresh MySQL instance in your project. Now that the instance is created, let's move on to deploying the WidgetFactory application. We'll come back to the operator later to demonstrate a backup and recovery after we have some data to work with.

## 4 Deploy the WidgetFactory application
(TODO: Should we also write a pipeline for deploying the mysql-operator? Probably, but it's really hard to do since the operator-sdk requires docker. The right way to do this is probably to create an operator s2i builder image, since builds are privileged by nature. Or just create an scc but that's not a great way imo. Surprisingly there's not an operator s2i image out there already)
One thing that OpenShift excels at, among many, is integration with Jenkins to provide a CI/CD platform. We can leverage Jenkins and Ansible together to build the WidgetFactory application and deploy it to OpenShift.

### 4.1 Auto-deploy Jenkins (doesn't work in test cluster bc auto prov is turned off)
OpenShift provides out-of-the-box Jenkins integration by auto-provisioning a Jenkins instance when a BuildConfig of type `JenkinsPipeline` is created. For this lab there are two pipelines:

| Pipeline | Purpose |
| ---- | ------- |
| jenkins-agent-ansible/agent-pipeline.yml | Build Jenkins agent with Ansible tooling |
| widget-factory/widget-pipeline.yml | Build and deploy WidgetFactory application |

In the next sections, we'll create the BuildConfig resources and build the WidgetFactory application

### 4.2 Create jenkins-agent-ansible (doesn't work in test ocp 4 env bc the node doesn't have the rhel-7-server-rpms repo)
Before we can run the application pipeline, we need to build a Jenkins agent with Ansible tooling. Let's create the necessary resources with:
```bash
oc process -f jenkins-agent-ansible/agent-pipeline.yml --param=SOURCE_REF=master | oc apply -f -
```

In the web console, you should see the Jenkins master pod spinning up. Wait until that Jenkins instance is ready (blue circle around pod numbers), and then run:
```bash
oc start-build jenkins-agent-ansible-pipeline
```

It won't be necessary to log into Jenkins, but if you want to log in and explore, you login credentials will be the same as your OpenShift login.

### 4.3 Review Application
The WidgetFactory application code is under `widget-factory/`. It's a simple spring-data service. One controller is set up as a `spring-data-rest` interface that autoconfigures CRUD operations on our `Widget` object. There is also a second controller that allows for building more custom queries.

### 4.4 Ansible OpenShift Applier
The OpenShift applier is a role that's great for deploying applications onto openshift. <blah blah>

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

Check out the `mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml` resource and notice its `spec:` stanza. Key/value pairs under spec: are defined as extra vars to the Ansible role. Notice how this CR has a `interval_minutes: 5` defined on its spec. This passes the `interval_minutes` var to the role, which tells Ansible to take a backup every x number of minutes. If you check out `mysql-operator/roles/mysqlbackup/defaults/main.yml`, you'll find that the default value for this var is `0`, which means that the backup will not be timed but rather will be a single, ad-hoc backup.

For this lab, the `mysqlbackup` role will take each backup on a separate PVC.

### 5.2 Initiate a Timed Backup
Let's see this backup role in action! We'll use the MysqlBackup spec defined in the given `mysqlbackup_cr.yaml`, which will take a backup of the database every 2 minutes. Begin the backup process with:
```bash
oc create -f mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```

This will create an OpenShift cronjob that is responsible for mounting a brand new PVC every `interval_minutes`. It will keep `max_backups` PVCs in your project (defined in the `defaults/` of the mysqlbackup role). Feel free to observe this process with `oc describe cronjob mysql-backup` and `oc get pvc`. Wait until at least one backup pvc is created, then continue to the next part of the lab.

## 6 Restore the MySQL Database
Here, we'll try to simulate a disaster recovery scenario in which data is lost from the database and a restore operation must take place.

### 6.1 Delete data from MySQL database (not implemented yet, but not technically necessary to do the restore)
The WidgetFactory application exposes a very dangerous endpoint called `/deleteall`, which will delete all the data in the database (TODO: Endpoint is not created yet). Why the devs thought this would be a good idea, I don't know. In any case, this will be a great way to test out the restore function of the Ansible operator. Let's hit this endpoint with: 
```bash
curl <WidgetFactory route>/deleteall
```

### 6.2 Find the Appropriate Backup PVC
As you can recall, we have a timed backup running in the background. As a result, one of those backup PVCs could contain a backup of the empty database, which wouldn't do much good. (TODO: so we probably need a way to show the backup sql script that will actually show the backup sql script that a DBA would find and determine the right backup to use. Or provide a count of entries as an annotation on the pvc, or some way to get a high level peek of what's inside)

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