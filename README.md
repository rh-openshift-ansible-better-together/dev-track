# OpenShift-Ansible Integration Lab

## 0 Introduction
Welcome to the Dev Track of the OpenShift + Ansible Better Together lab! Today you will learn about how Ansible can be leveraged to automate deployments and maintenance tasks on OpenShift. You'll gain experience around building an Ansible operator, and you'll integrate that operator with a data-driven app called WidgetFactory. Also, this lab will be performed on the brand new OpenShift 4 platform!

### 0.1 Scenario
You are an architect at Acme Corporation working as part of the WidgetFactory BU. WidgetFactory is a greenfield app that will serve as a widget inventory tracking system for Acme Corp. You want to put a POC together to demonstrate how WidgetFactory can be easily deployed and maintained on [OpenShift Container Platform](https://docs.openshift.com/container-platform/latest/getting_started/index.html) by leveraging the power of [Ansible Automation](https://www.ansible.com/resources/get-started).

To get started we'll introduce how Ansible can be used to automate provisioning and maintenance tasks on OpenShift through an Ansible operator. Then we'll look at how we can leverage Ansible for application configuration and deployment as part of a CI/CD pipeline.

## 1 SSH into Bastion Host or Configure Development Environment
There are a few different tools you need in order to complete the lab:
- docker
- operator-sdk
- git
- oc

We've provided an environment for you that already has these tools installed and ready to go, which we strongly recommend using because the lab instructions were written based off of it.

You'll need the private key to ssh into the VM. Download the key with:
```bash
curl -O https://s3.us-east-2.amazonaws.com/adeweylab/ocpkey.pem
chmod 400 ocpkey.pem
```

You'll be assigned a number when we start the lab. Ssh into your environment with

```bash
export USER_NUMBER=<number>
ssh -i ocpkey.pem ec2-user@bastion.workshop-day1-vm$USER_NUMBER.example.opentlc.com
sudo -i
```

After you SSH or set up your environment locally, you should clone this repo:
```bash
cd ~
git clone https://github.com/rh-openshift-ansible-better-together/dev-track.git
```

Set an environment variable to reference the examples in this workshop:
```bash
export LAB="/root/dev-track"
```

### 1.1 Log in to OpenShift
You'll need to log into OpenShift with the `oc` tool to talk to the cluster from the command line. You'll also want to log into the UI.
Log in using `oc`. When prompted with the user, provide the username that you were assigned. Your username is `user$USER_NUMBER`, so if you were assigned user 1, your username would be `user1`. For the password, enter `r3dh4t1!`.
```bash
oc login https://api.cluster-52a2.52a2.ocp4.opentlc.com:6443
```

Log into the UI by following this link http://console-openshift-console.apps.cluster-52a2.52a2.ocp4.opentlc.com. The login credentials are the same here as they were for `oc`.

Set an environment variable to reference your username throughout this lab:
```bash
export OCP_USER=<assigned-username>
```

### 1.2 Create OpenShift Project
You'll need to create an OpenShift project to perform the lab in. Create a project with:
```bash
oc new-project $OCP_USER
```

## 2 Create Quay Account and Repositories
In this lab we're going to build a new operator with Ansible. The operator itself is simply a container image, so we need a place to store it so we can reference it in a future deployment.

Let's create a Quay account if you don't have one already. Go to https://quay.io/signin/ and click `Create Account` at the bottom. Provide your username, email address, and password. Optionally, you can sign in with an existing Google or GitHub account and follow the prompts, but you'll need to be sure to go to account settings and change your password since you'll need one to log in with docker.

Once your account is created, click on `Create New Repository` in the upper right. In the text box that says `Repository Name`, type `mysql-operator`. Select the `Public` radio button. Then click `Create Public Repository`.

Create another repository called `mysql-operator-test`, following the same procedure. This will be a heavier mysql-operator that contains artifacts that are necessary for testing that we don't want as part of our production operator.

By the end of this section you should have two repositories in Quay under your account called `mysql-operator` and `mysql-operator-test`.

Set an environment variable to reference your Quay account:
```bash
export QUAY_USER=<quay-user>
printf "Quay Password: " ; read -sr QUAY_PASS_IN ; export QUAY_PASS=$QUAY_PASS_IN ; echo
```

## 3 Review the Ansible Operator

### 3.1 Operator Overview
The WidgetFactory app is a data-driven app that uses a MySQL database to store widget information. The team would like a way of making the MySQL deployment fast and painless, while also being able to take data snapshots and recover the database in a data loss scenario. You decide to leverage the cool new [Operator framework](https://coreos.com/operators/) to provide a simple way to self-service and maintain the deployment and maintenance of the MySQL database.

An operator is an extention to the Kubernetes API. With an operator, we can deploy a `Mysql` custom resource (CR), and OpenShift will be able to understand what we mean and deploy all of the dependent resources automatically. In this case we'll also be able to deploy `MysqlBackup` and `MysqlRestore` resources as well. More on those below.

The community provides many different operators supporting many different needs (see Catalog->OperatorHub for a list of all community operators). In this lab we'll learn to write our own operator with Ansible so we can create a custom operator catered specifically to our needs. After this lab, feel free to explore other operators in the community. There's a lot out there that showcase what else operators are able to provide.

### 3.2 Ansible Operator Structure
Navigate to the `mysql-operator` directory:
```bash
cd $LAB/mysql-operator
```
Here you will see the file structure of an Ansible operator. Check out the [operator-sdk](https://github.com/operator-framework/operator-sdk/blob/master/doc/ansible/user-guide.md) Ansible documentation for a full overview of the Ansible operator. For this lab, here's what's important to know:

| File/Dir | Purpose |
| -------- | ------- |
| build/   | Contains the Dockerfile for building the Ansible operator |
| deploy/  | Contains the OpenShift resources necessary for deploying the Ansible operator and creating the MySQL CRD (custom resource definition) |
| roles/   | Contains the Ansible roles that the operator will be running when a CR (custom resource) is created |
| molecule/ | Contains the Ansible playbooks to perform [Molecule](https://github.com/ansible/molecule) testing on the Ansible operator |
| watches.yaml | Configures the operator to associate a CR to a particular Ansible role |

When the Ansible operator is deployed, it will listen for CRs and will apply the Ansible role accordingly. Operators are designed to maintain the "desired state", meaning it will run in a loop and will constantly re-run the roles in accordance to the CR spec to ensure that the desired state is always reached. Therefore, it's imperative that each role be written in an idempotant and stateless manner. It should also be able to handle any change to the OpenShift environment that may occur anywhere during role execution.

### 3.3 Review Ansible Roles
Let's dive a little deeper into the actual Ansible code behind this operator. Find the `roles/` directory:
```bash
cd $LAB/mysql-operator/roles
```
Here you'll find three Ansible roles:

| Role | Purpose |
| ---- | ------- |
| mysql | Deploy a single-node MySQL server |
| mysqlbackup | Initiate an ad-hoc or scheduled backup of the MySQL database |
| mysqlrestore | Restore the database to a previous data backup |

Each of these roles relies heavily on the `k8s`, `k8s_facts`, and `k8s_status` Ansible modules, which are leveraged in this lab to create OpenShift resources, get information on existing resources, and set CR statuses.

Feel free to check out each role in greater detail. The cool thing about the Ansible operator is that, unsurprisingly, it's powered by Ansible Automation, which is designed to be easily read and understood. Unlike the [Go operator](https://github.com/operator-framework/operator-sdk/blob/master/doc/user-guide.md), the Ansible operator does not require you to be a developer to start unlocking an operator's true potential.

When you're finished checking out each role, let's test the Ansible operator to make sure it will perform as expected.

## 4 Test the Ansible Operator
The Ansible operator supports [Molecule](https://github.com/ansible/molecule) to perform testing in a live OpenShift cluster. Let's run tests to ensure that the operator is stable and ready to go.

### 4.1 Explore Molecule Structure
Find the molecule playbooks:
```bash
cd $LAB/mysql-operator/molecule
```

The `default` folder contains assertions that are used to ensure that the observed state is also the desired state. The `test-cluster` folder contains the molecule config as well as the playbook that initializes the MySQL CR.

Feel free to check out the `default/assert.yml` and `test-cluster/playbook.yml` plays. You'll find that it creates a Mysql CR, waits 2 minutes for it to become active, and then validates the deployment. If the database is healthy, we can assume that the operator is successfully doing its job.

### 4.2 Build the Test Operator
We need to turn the Ansible plays into a Docker image so that it can be deployed and tested on OpenShift. We also need to make sure we include the test artifacts that are normally excluded from the production image. We can do this easily with the operator-sdk tool.

On the command line, navigate to the `mysql-operator` directory and build the test operator:
```bash
cd $LAB/mysql-operator
sed -i "s/BASEIMAGE/quay.io\/$QUAY_USER\/mysql-operator-test-intermediate/g" $LAB/mysql-operator/build/test-framework/Dockerfile
operator-sdk build quay.io/$QUAY_USER/mysql-operator-test --enable-tests
```

Now that the test operator is built, let's push it to Quay with Docker.
```bash
docker login quay.io -u $QUAY_USER -p $QUAY_PASS
docker push quay.io/$QUAY_USER/mysql-operator-test
```

You'll find that this is a somewhat large image. The production-sized operator is much smaller, which is why after we test and validate that the operator is working we should rebuild without the `--enable-tests` flag to remove the test artifacts.

### 4.3 Deploy the Test Operator
Now that the image has been built and is now in Quay, let's deploy it in your project. 

First, we need to create some resources to give the operator permission to edit your project. If you recall, the `deploy/` directory contains OpenShift resources that are required for the operator to work properly. It contains a service account, role, rolebindings, deployment, CRDs, and CRs. For now, let's create only what we need to test the operator:
```bash
cd $LAB/mysql-operator
oc create -f deploy/service_account.yaml
oc create -f deploy/role.yaml
oc create -f deploy/role_binding.yaml
```

### 4.4 Execute Operator Tests
It's time to test the operator! Navigate to the mysql-operator folder:
```bash
cd $LAB/mysql-operator
```

Then trigger the tests:
```bash
operator-sdk test cluster quay.io/$QUAY_USER/mysql-operator-test --service-account mysql-operator
```

The command will hang for a couple minutes until the tests complete. You should be able to see the operator and the MySQL server spin up in OpenShift.

The command will return a Success message if the testing is successful. Otherwise, it will print the log output of the operator during its run. If the tests did not pass, you might be missing something in your environment, or you may simply have just missed a step.

## 5 Build and Deploy Production Operator
Now that we know the tests have passed, let's build the more lightweight production operator.

```bash
cd $LAB/mysql-operator
operator-sdk build quay.io/$QUAY_USER/mysql-operator
docker push quay.io/$QUAY_USER/mysql-operator
sed -i "s/OPERATOR_IMAGE/quay.io\/$QUAY_USER\/mysql-operator/g" $LAB/mysql-operator/deploy/operator.yaml
oc create -f $LAB/mysql-operator/deploy/operator.yaml
```

## 6 Deploy a MySQL Server
Now that the Ansible operator is deployed, it's super easy to deploy a MySQL server onto OpenShift! First, let's check out the MySQL CR:
```bash
cat $LAB/mysql-operator/deploy/crds/mysql/mysql_cr.yaml
```

This is a simple MySQL custom resource that when created will be picked up by the operator and trigger it to run the `mysql` role. Let's create the resource with:
```bash
oc create -f $LAB/mysql-operator/deploy/crds/mysql/mysql_cr.yaml
```

You should get a message saying that the MySQL resource was created. The MySQL instance itself should be up soon - right now it's running the corresponding Ansible role. We can see this role in action by checking out the operator logs:
```bash
oc logs --follow $(oc get po | grep mysql-operator | awk '{print $1}')
```

When the role is finished, you should see something like `ansible-runner exited successfully` in the logs, as well as a fresh MySQL instance in your project. Now that the instance is created, let's move on to deploying the WidgetFactory application. We'll come back to the operator later to demonstrate a backup and recovery after we have some data to work with.

## 7 Deploy the WidgetFactory application
One thing that OpenShift excels at, among many, is integration with Jenkins to provide a CI/CD platform. We can leverage Jenkins and Ansible together to build the WidgetFactory application and deploy it to OpenShift.

### 7.1 Deploy Jenkins
OpenShift provides a `JenkinsPipeline` build strategy that creates a Jenkins pipeline for CI/CD pipeline builds. We'll use this build strategy to build and deploy the WidgetFactory application.

First, we need to deploy a Jenkins instance to the widgetfactory project. Deploy a Jenkins instance with:
```bash
oc new-app jenkins-ephemeral -p MEMORY_LIMIT=2Gi
```

Your login credentials to Jenkins will be the same as your `$OCP_USER` and `r3dh4t1!` credentials.

### 7.2 Create the jenkins-agent-ansible Imagestream
The WidgetFactory pipeline depends on a build agent called `jenkins-agent-ansible`. The agent will be used to run a playbook that deploys the WidgetFactory resources to the environment.

The agent has already been built and pushed to Quay.

We can make Jenkins aware of this build agent by creating an imagestream with a label `role=jenkins-slave`. Let's create this imagestream with:
```bash
oc process -f $LAB/jenkins-agent-ansible/imagestream.yml --param APPLICATION_NAMESPACE=$OCP_USER | oc apply -f -
```

### 7.3 Review Application
The WidgetFactory application code is under `widget-factory/`. It's a simple spring-data service. One controller is set up as a `spring-data-rest` interface that autoconfigures CRUD operations on our `Widget` object. There is also a second controller that allows for building more custom queries.

### 7.4 Ansible OpenShift Applier
The WidgetFactory pipeline makes use of an Ansible role called the [OpenShift-Applier](https://github.com/redhat-cop/openshift-applier). The OpenShift Applier role is used to process and apply OpenShift templates. It's a useful Ansible role that allows you to specify all of your app's requirements in an OpenShift template and then leverage Ansible to supply parameters to the templates and apply them.

The various OpenShift Applier files for WidgetFactory are under `$LAB/widget-factory/.applier`. You can find all of the parameters the template expects under `group_vars/all.yml`. The Jenkins pipeline will pass in the extra vars when the ansible-playbook command is run.

### 7.5 Deploy Application
Now that the Ansible agent is created and the Jenkins pod is up and running, we're now ready to deploy our application:
```bash
oc process -f widget-factory/widget-pipeline.yml --param=SOURCE_REF=master --param DATABASE_HOST=mysql --param APPLICATION_NAMESPACE=$OCP_USER | oc apply -f -
oc start-build widget-factory-pipeline
```

To view the build's progress, expand `Builds` on the sidebar in the OpenShift UI and click `Builds` underneath that. Click on the widget-factory pipeline. You'll probably find that it is still pending and that there are no build logs displayed. This simply means that Jenkins is not ready yet, and when it is, the build will start and logs will display (you should see `View Logs` underneath the build number).

Click the `View Logs` link once it appears in the UI (it will appear under the build number). You'll need to confirm the security exception and log into Jenkins. The credentials are the same as your OpenShift username and password. Note that this may take a few minutes as Jenkins is running preliminary tasks.

When you log into Jenkins, you should immediately be taken to the Jenkins build. This build is building the Java application with maven and deploying the WidgetFactory application with Ansible. You can expect this build to take around 5 minutes.

When the app starts up, it persists many different widgets to the MySQL instance we created earlier. Let's return our focus back to the Ansible operator to perform a backup of the database.

## 8 Back up the MySQL Database
### 8.1 MysqlBackup Overview
If you recall, the operator that we created earlier contains a role called `mysqlbackup`. This role is capable of taking both ad-hoc and scheduled hot, logical backups of the MySQL database. The backup is triggered when a `MysqlBackup` CR is created in the project. 

Check out the `mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml` resource and notice its `spec:` stanza. Key/value pairs under `spec:` are defined as extra vars to the Ansible role. Notice how this CR has an `interval_minutes: 0` defined on its spec. This passes the `interval_minutes` var to the role, which tells Ansible to take a backup every x number of minutes. In this case, the role is configured to interpret 0 interval_minutes as an ad-hoc backup. Let's keep the CR the way it is for now.

For this lab, the `mysqlbackup` role will take each backup on a separate PVC.

### 8.2 Initiate an Ad-Hoc Backup
Let's see this backup role in action! We'll use the MysqlBackup spec defined in the given `mysqlbackup_cr.yaml`, which will take an ad-hoc backup of the database. Begin the backup process with:
```bash
oc create -f $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```

This will create an OpenShift cronjob that is responsible for mounting a brand new PVC and using it to back up the database's current state. It will keep `max_backups` completed backup PVCs in your project (defined in the `defaults/` of the mysqlbackup role). Wait until the PVC is created and then continue to the next step. You can run `oc get pvc` to determine if the PVC has been created. By default, the backup PVC will be called `mysqlbackup`.

## 9 Restore the MySQL Database
Here, we'll try to simulate a disaster recovery scenario in which data is lost from the database and a restore operation must take place.

### 9.1 Delete data from the MySQL database
Let's use the `mysql` binary installed on the MySQL pod to delete data from the database. First, access the pod with `oc rsh`:
```bash
oc rsh deployment/mysql
```

Once inside the pod, delete some data with:
```bash
mysql -h localhost -u admin -padmin123 widgetfactory -e "DROP TABLE widget"
exit
```

### 9.2 Restore the MySQL Database
Find the MysqlRestore CR at `mysql-backup/deploy/crds/mysqlrestore/mysqlrestore_cr.yaml`. In the spec you'll find a `mysql_backup_pvc` key defined under the spec that will be passed as an extra var to the Ansible role. Provide the name of a backup PVC that was created before the MySQL outtage.

Once you find a good backup to use, supply the name of the backup to the `mysql_backup_pvc` var of the `mysqlrestore_cr.yaml` Then trigger the restore:
```bash
sed -i 's/BACKUP_PVC/mysqlbackup/g' $LAB/mysql-operator/deploy/crds/mysqlrestore/mysqlrestore_cr.yaml
oc create -f $LAB/mysql-operator/deploy/crds/mysqlrestore/mysqlrestore_cr.yaml
```

This will create an OpenShift job that will mount the backup PVC. It will connect to the MySQL database and will apply the backup script to restore the contents of the database.

You can run `watch oc get jobs` to wait for the restore job to run and finish. You'll know when it's finished when the `mysqlrestore` job has `1/1` completions.

You can check to make sure that the restore was successful by using `oc rsh deployment/mysql` again:
```bash
mysql -h localhost -u admin -padmin123 widgetfactory -e "select * from widget"
```

## 10 For fun - Scheduled MySQL Backup
Previously we ran an ad-hoc backup using the mysqlbackup CR. We can create a different mysqlbackup CR to take a scheduled backup of the database:
```bash
sed -i 's/name: mysqlbackup/name: mysqlscheduledbackup/g' $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
sed -i 's/interval_minutes: 0/interval_minutes: 15/g' $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
oc create -f $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```
Modify the `spec.interval_minutes` from 0 to 15. This will create a cronjob that takes a backup every 15 minutes. By default, it will keep `max_backups` backup PVCs, which is defined as 2 under `$LAB/mysql-operator/roles/mysqlbackup/defaults/main.yml`.

Feel free to observe the backup process with `watch oc get cronjob` and `watch oc get pvc`.

## 11 Thank you!
Thank you for attending our workshop today! Hopefully you learned a lot about how OpenShift and Ansible can come together to accelerate delivery and innovation.
