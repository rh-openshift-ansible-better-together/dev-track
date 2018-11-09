#!/usr/bin/env bash

## Section -1
sudo yum install -y git apb
git checkout git@github.com:srang/rh-openshift-ansible-broker-lab.git
GIT_BASE="$(pwd)/rh-openshift-ansible-broker-lab"

## Section 0
cd $(GIT_BASE)/bootstrap

## Section 1
cd $(GIT_BASE)/database-provision-playbook
ansible-playbook database-playbook.yml -i inventory/

## Section 2
oc login https://ec2-18-234-37-92.compute-1.amazonaws.com -u admin -p redhat01
oc new-project widget-factory
oc process -f bootstrap.yml | oc apply -f-
oc process template/mysql-ephemeral -p MYSQL_DATABASE=widgetfactory -n openshift | oc apply -f-
oc start-build widget-jenkins-agent-pipeline

## Section 3
oc create is database-provision-apb -n openshift
oc policy add-role-to-user system:image-builder system:serviceaccount:widget-factory:builder -n openshift
oc start-build database-provision-apb
## Pause
apb broker bootstrap
