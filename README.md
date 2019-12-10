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

We've provided a VM for you that we recommend using to complete the lab that comes with the required tooling already installed. You'll need the private key to ssh into the VM. Download the key with:
```bash
curl -O https://s3.amazonaws.com/bettertogether.openshift-is-awesome.com/BetterTogether.pem
chmod 400 BetterTogether.pem
```

You'll be assigned a number when we start the lab. Set an environment variable to reference the number for SSH:
```bash
export USER_NUMBER=<number>
```
where `<number>` is 1, 2, 3, 4...

SSH into the VM using the directions from the table below.

| Location | SSH Command |
| -------- | ----------- |
| Jersey City | ssh -i BetterTogether.pem centos@ewrvm${USER_NUMBER}.openshift-is-awesome.com |

After you SSH into the VM, clone this repo and set an environment variable to reference examples used throughout this workshop.
```bash
cd ~
git clone https://github.com/rh-openshift-ansible-better-together/dev-track.git
export LAB="/home/centos/dev-track"
```

### 1.1 Log in to OpenShift
You'll need to log into OpenShift with the `oc` tool to talk to the cluster from the command line. You'll also want to log into the UI.

See the table below for your location's cluster information.

| Location | API Server | Web Console |
| -------- | ---------- | ----------- |
| Jersey City | https://api.cluster-jersey-2e22.jersey-2e22.open.redhat.com:6443 | http://console-openshift-console.apps.cluster-jersey-2e22.jersey-2e22.open.redhat.com |

Set an environment variable to reference your username and API Server:
```bash
export OCP_USER=<assigned-username> # For example, user60
export API_SERVER=<api-server>      # Referenced in the above table
```

Log in using `oc` by authenticating against the API Server. When prompted for the user, provide the username that you were assigned. Your username is `user$USER_NUMBER`, so if you were assigned user 1, your username would be `user1`. For the password, enter `openshift`.
```bash
oc login $API_SERVER --username=$OCP_USER --password='openshift'
```

Log into the UI by following your location's corresponding Web Console link from the table above. The login credentials are the same here as they were for `oc`.

### 1.2 Create OpenShift Project
You'll need to create an OpenShift project to perform the lab in. Create a project with:
```bash
oc new-project $OCP_USER
```

### 1.3 Deploy Jenkins
Later in this workshop, we will use Jenkins to deploy the WidgetFactory app using a CI/CD pipeline. Because the Jenkins server can take some time to become ready, let's spin it up ahead of time. We'll come back to Jenkins when we deploy WidgetFactory.
```bash
oc new-app jenkins-ephemeral -p MEMORY_LIMIT=2Gi
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
Let's dive a little deeper into the Ansible roles behind this operator. Find the `roles/` directory:
```bash
cd $LAB/mysql-operator/roles
```
Here you'll find three Ansible roles:

| Role | Purpose |
| ---- | ------- |
| mysql | Deploy a single-node MySQL server |
| mysqlbackup | Initiate an ad-hoc or scheduled backup of the MySQL database |
| mysqlrestore | Restore the database to a previous data backup |

## 4 Write the Ansible Operator
Time to get a little more hands-on. We've left several placeholders throughout the operator for you to write some Ansible. Let's walk through the changes you'll have to make to allow the operator to be fully functional.

Each VM has the `vi` editor installed. We also provide the complete files under `$LAB/answers` for you to copy at the end of each section.

### 4.1 Finish the `mysql` Role
View the `main.yml` tasks file under the `mysql` role:
```bash
cat $LAB/mysql-operator/roles/mysql/tasks/main.yml
```
Currently, the role is only generating a root password for the MySQL server if it is not passed in as an extra var through the MySQL custom resource. It doesn't yet deploy the MySQL server. Let's write some Ansible to deploy a MySQL server when a MySQL custom resource is created.

Under where it says `## TODO: Create MySQL Server`, add the following line:
```yaml
- name: Create resources for {{ name }} deployment
```
This is the name of the next task of the `mysql` role. It makes the Ansible code more readable by letting developers know what the task is supposed to do, and it makes runtime output easier for administrators to understand in the event of troubleshooting.

Note also the `{{ name }}` string. This is a variable in Ansible, which is defined in `$LAB/mysql-operator/roles/mysql/defaults/main.yml`. When expanded, it will equal the name of the mysql custom resource.

Let's add a couple more lines to the mysql role, so that your task now looks like this:
```yaml
- name: Create resources for {{ name }} deployment
  k8s:
    state: present
    definition: "{{ lookup('template', item.name) | from_yaml }}"
```

Notice the `k8s:` line. This tells Ansible to use the `k8s` module to perform an action on the OpenShift cluster. Think of a module as a function, in which `k8s:` is our "function" and `state:` and `definition` are the parameters to that function.

`state: present` tells the `k8s` module to create a resource to the cluster (as opposed to deleting it, which would instead be `state: absent`). `definition: ` tells the `k8s` module specifically what to create on the cluster. Let's add one more piece of code to complete this Ansible task to tie everything together. Add to the mysql role so that your task now looks like this:
```yaml
- name: Create resources for {{ name }} deployment
  k8s:
    state: present
    definition: "{{ lookup('template', item) | from_yaml }}"
  loop:
    - name: secret.yml.j2
    - name: service.yml.j2
    - name: pvc.yml.j2
    - name: deployment.yml.j2
```

The `loop:` stanza is a control function that tells Ansible to loop through each item in the list below it. It works kind of like a for-each loop in Java. It will name each iteration of the loop `item` and will pass it back up to the `definition: ` parameter of the `k8s` module. It will get interpreted by an Ansible lookup function called `template`, meaning that it will leverage a dependency called `jinja2` to template out each YAML file and create them to the OpenShift cluster.

We'll talk more about the `jinja2` templating in the next example. For now, feel free to copy the answer over before continuing to the next section:
```bash
cp $LAB/answers/mysql/tasks/main.yml $LAB/mysql-operator/roles/mysql/tasks/
```

### 4.2 Finish the `mysqlbackup` Role
Let's take a look at the `mysqlbackup` role again:
```bash
cat $LAB/mysql-operator/roles/mysqlbackup/tasks/main.yml
```

This is a lengthy role, but it should look quite familiar for the most part after learning more about the `k8s` module in the previous section. One important thing to note is the first task in the role, which reads:
```yaml
- name: Create ad-hoc mysqlbackup objects
  k8s:
    state: present
    definition: "{{ lookup('template', item.name) | from_yaml }}"
  loop:
    - name: pvc.yml.j2
    - name: job.yml.j2
  when: interval_minutes == 0
```

The `when: interval_minutes == 0` part is another control construct which tells Ansible to run this task when the interval_minutes variable equals 0. The `interval_minutes` variable determines if the backup is ad-hoc (interval_minutes == 0) or scheduled (interval_minutes >= 1). By default, `interval_minutes` is equal to 0.

This whole role has been written for you with the exception of the `pvc.yml.j2` jinja2 template. Let's see what this file looks like right now:
```bash
cat $LAB/mysql-operator/roles/mysqlbackup/templates/pvc.yml.j2
```

It does a whole lot of - nothing. Never fear. We'll walk through this one like we did the `mysql` role.

The purpose of this jinja2 template is to create a dynamic pvc.yml spec based on Ansible variables. Let's begin by adding this to the file:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
{% if interval_minutes == 0 %}
  name: {{ name }}
{% else %}
  name: {{ name }}-{{ pvc_count }}
{% endif %}
```

Notice how jinja2 has a concept of conditional logic with `if` statements, similar to other template engines and programming languages. If `interval_minutes == 0`, then we'll give the PVC a static name, which again defaults to the name of the mysqlbackup custom resource. Else, we'll assign the PVC a dynamic name by giving it the name `{{ name }}-{{ pvc_count }}`. `pvc_count` is a variable in the role that will keep track of the number of PVCs in the namespace.

Let's add more to the file so that it now looks like this:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
{% if interval_minutes == 0 %}
  name: {{ name }}
{% else %}
  name: {{ name }}-{{ pvc_count }}
{% endif %}
  namespace: {{ namespace }}
  labels:
    app: {{ name }}
{% if interval_minutes == 0 %}
    role: backup
{% else %}
    role: scheduledbackup
{% endif %}
```

Here we added more of the same concept. Depending on if the backup is ad-hoc or scheduled, we'll give it a label called `backup` or `scheduledbackup` just so an administrator knows what kind of backup was initiated when looking back at the PVCs.

Let's add the last part so that the file looks like this:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
{% if interval_minutes == 0 %}
  name: {{ name }}
{% else %}
  name: {{ name }}-{{ pvc_count }}
{% endif %}
  namespace: {{ namespace }}
  labels:
    app: {{ name }}
{% if interval_minutes == 0 %}
    role: backup
{% else %}
    role: scheduledbackup
{% endif %}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: {{ volume_capacity }}
```

The PVC will be given a storage capacity of `{{ volume_capacity }}` which defaults to `1Gi`.

Once you're finished, feel free to copy the answer over to ensure you made the correct changes, then continue to the next section:
```bash
cp $LAB/answers/mysqlbackup/templates/pvc.yml.j2 $LAB/mysql-operator/roles/mysqlbackup/templates/
```

### 4.3 Finish the `mysqlrestore` role
This is the last role to finish before moving on to final testing and deployment of the MySQL Operator. 

First, notice the TODO in the default variables:
```yaml
cat $LAB/mysql-operator/roles/mysqlrestore/defaults/main.yml
```

The missing defaults here are the `name` and `namespace` variables for the custom resource. Let's add those variables in now:
```yaml
# Discovered from CustomResource metadata
name: "{{ meta.name | default('mysqlbackup') }}"
namespace: "{{ meta.namespace | default('mysql') }}"
```

In case you haven't noticed, the `#` symbol indicates a comment in YAML (and therefore in Ansible as well). Ansible by nature of being YAML-based is designed to be human-readable, but comments help go a long way to further increase readability.

Let's single out this bit for a second `name: "{{ meta.name | default('mysqlbackup') }}"`. Notice the pipe (`|`) operator. This means the same thing it does in bash - take the output of one command and provide it as input to another. In this case, if the `meta.name` variable does not exist, the default value for `name:` will be `mysqlbackup`. The `meta.name` represents the `mysqlrestore` custom resource name, in this case.

You can see this be done in a similar fashion with `namespace:` as well.

Let's also add something to the `job.yml.j2` jinja2 template to provide the logic behind the mysqlrestore operation. Find the TODO:
```bash
cat $LAB/mysql-operator/roles/mysqlrestore/templates/job.yml.j2
```

Replace where it says `# TODO: Add container args for restore` with the following:
```yaml
args: ["mysql --host {{ mysql_deployment }} -uroot -p$ROOT_PASSWORD $DATABASE_NAME < /var/backup/backup.sql"]
```

This will be the command that is run when a `mysqlrestore` custom resource is created. It will apply the backup script that gets created by the `mysqlbackup` role.

Once you're finished, feel free to copy the answer over to ensure your operator is correct:
```bash
cp $LAB/answers/mysqlrestore/defaults/main.yml $LAB/mysql-operator/roles/mysqlrestore/defaults/
cp $LAB/answers/mysqlrestore/templates/job.yml.j2 $LAB/mysql-operator/roles/mysqlrestore/templates/
```

## 5 Test the Ansible Operator
The Ansible operator supports [Molecule](https://github.com/ansible/molecule) to perform testing in a live OpenShift cluster. Let's run tests to ensure that the operator is stable and ready to go.

### 5.1 Explore Molecule Structure
Find the molecule playbooks:
```bash
cd $LAB/mysql-operator/molecule
```

The `defaults` folder contains assertions that are used to ensure that the observed state is also the desired state. The `test-cluster` folder contains the molecule config as well as the playbook that initializes the MySQL CR.

Feel free to check out the `defaults/assert.yml` and `test-cluster/playbook.yml` plays. You'll find that it creates a Mysql CR, waits 2 minutes for it to become active, and then validates the deployment. If the database is healthy, we can assume that the operator is successfully doing its job.

### 5.2 Build the Test Operator
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

### 5.3 Deploy the Test Operator
Now that the image has been built and is now in Quay, let's deploy it in your project. 

First, we need to create some resources to give the operator permission to edit your project. If you recall, the `deploy/` directory contains OpenShift resources that are required for the operator to work properly. It contains a service account, role, rolebindings, deployment, CRDs, and CRs. For now, let's create only what we need to test the operator:
```bash
cd $LAB/mysql-operator
oc create -f deploy/service_account.yaml
oc create -f deploy/role.yaml
oc create -f deploy/role_binding.yaml
```

### 5.4 Execute Operator Tests
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

## 6 Build and Deploy Production Operator
Now that we know the tests have passed, let's build the more lightweight production operator.

```bash
cd $LAB/mysql-operator
operator-sdk build quay.io/$QUAY_USER/mysql-operator
docker push quay.io/$QUAY_USER/mysql-operator
sed -i "s/OPERATOR_IMAGE/quay.io\/$QUAY_USER\/mysql-operator/g" $LAB/mysql-operator/deploy/operator.yaml
oc create -f $LAB/mysql-operator/deploy/operator.yaml
```

## 7 Deploy a MySQL Server
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

## 8 Deploy the WidgetFactory application
One thing that OpenShift excels at, among many, is integration with Jenkins to provide a CI/CD platform. We can leverage Jenkins and Ansible together to build the WidgetFactory application and deploy it to OpenShift.

### 8.1 Create the jenkins-agent-ansible Imagestream
The WidgetFactory pipeline depends on a build agent called `jenkins-agent-ansible`. The agent will be used to run a playbook that deploys the WidgetFactory resources to the environment.

The agent has already been built and pushed to Quay.

We can make Jenkins aware of this build agent by creating an imagestream with a label `role=jenkins-slave`. Let's create this imagestream with:
```bash
oc process -f $LAB/jenkins-agent-ansible/imagestream.yml --param APPLICATION_NAMESPACE=$OCP_USER | oc apply -f -
```

### 8.2 Review Application
The WidgetFactory application code is under `widget-factory/`. It's a simple spring-data service. One controller is set up as a `spring-data-rest` interface that autoconfigures CRUD operations on our `Widget` object. There is also a second controller that allows for building more custom queries.

### 8.3 Ansible OpenShift Applier
The WidgetFactory pipeline makes use of an Ansible role called the [OpenShift-Applier](https://github.com/redhat-cop/openshift-applier). The OpenShift Applier role is used to process and apply OpenShift templates. It's a useful Ansible role that allows you to specify all of your app's requirements in an OpenShift template and then leverage Ansible to supply parameters to the templates and apply them.

The various OpenShift Applier files for WidgetFactory are under `$LAB/widget-factory/.applier`. You can find all of the parameters the template expects under `group_vars/all.yml`. The Jenkins pipeline will pass in the extra vars when the ansible-playbook command is run.

### 8.4 Deploy Application
Now that the Ansible agent is created and the Jenkins pod is up and running, we're now ready to deploy our application:
```bash
oc process -f $LAB/widget-factory/widget-pipeline.yml --param=SOURCE_REF=master --param DATABASE_HOST=mysql --param APPLICATION_NAMESPACE=$OCP_USER | oc apply -f -
oc start-build widget-factory-pipeline
```

To view the build's progress, expand `Builds` on the sidebar in the OpenShift UI and click `Builds` underneath that. Click on the widget-factory pipeline. You should begin to see a pipeline displaying the progress of the build. If you don't see any progress, allow Jenkins a minute to provision its agent pod.

When the app starts up, it persists many different widgets to the MySQL instance we created earlier. Let's return our focus back to the Ansible operator to perform a backup of the database.

## 9 Back up the MySQL Database
### 9.1 MysqlBackup Overview
If you recall, the operator that we created earlier contains a role called `mysqlbackup`. This role is capable of taking both ad-hoc and scheduled hot, logical backups of the MySQL database. The backup is triggered when a `MysqlBackup` CR is created in the project. 

Check out the `mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml` resource and notice its `spec:` stanza. Key/value pairs under `spec:` are defined as extra vars to the Ansible role. Notice how this CR has an `interval_minutes: 0` defined on its spec. This passes the `interval_minutes` var to the role, which tells Ansible to take a backup every x number of minutes. In this case, the role is configured to interpret 0 interval_minutes as an ad-hoc backup. Let's keep the CR the way it is for now.

For this lab, the `mysqlbackup` role will take each backup on a separate PVC.

### 9.2 Initiate an Ad-Hoc Backup
Let's see this backup role in action! We'll use the MysqlBackup spec defined in the given `mysqlbackup_cr.yaml`, which will take an ad-hoc backup of the database. Begin the backup process with:
```bash
oc create -f $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```

This will create an OpenShift job that is responsible for mounting a brand new PVC and using it to back up the database's current state. It will keep `max_backups` completed backup PVCs in your project (defined in the `defaults/` of the mysqlbackup role). Wait until the PVC is created and then continue to the next step. You can run `oc get pvc` to determine if the PVC has been created. By default, the backup PVC will be called `mysqlbackup`.

## 10 Restore the MySQL Database
Here, we'll try to simulate a disaster recovery scenario in which data is lost from the database and a restore operation must take place.

### 10.1 Delete data from the MySQL database
Let's use the `mysql` binary installed on the MySQL pod to delete data from the database. First, access the pod with `oc rsh`:
```bash
oc rsh deployment/mysql
```

Once inside the pod, delete some data with:
```bash
mysql -h localhost -u admin -padmin123 widgetfactory -e "DROP TABLE widget"
exit
```

### 10.2 Restore the MySQL Database
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

## 11 For fun - Scheduled MySQL Backup
Previously we ran an ad-hoc backup using the mysqlbackup CR. We can create a different mysqlbackup CR to take a scheduled backup of the database:
```bash
sed -i 's/name: mysqlbackup/name: mysqlscheduledbackup/g' $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
sed -i 's/interval_minutes: 0/interval_minutes: 15/g' $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
oc create -f $LAB/mysql-operator/deploy/crds/mysqlbackup/mysqlbackup_cr.yaml
```
Modify the `spec.interval_minutes` from 0 to 15. This will create a cronjob that takes a backup every 15 minutes. By default, it will keep `max_backups` backup PVCs, which is defined as 2 under `$LAB/mysql-operator/roles/mysqlbackup/defaults/main.yml`.

Feel free to observe the backup process with `watch oc get cronjob` and `watch oc get pvc`.

## 12 Thank you!
Thank you for attending our workshop today! Hopefully you learned a lot about how OpenShift and Ansible can come together to accelerate delivery and innovation.
