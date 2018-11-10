#!/usr/bin/env bash

## Section 0
sudo yum install -y git apb rh-maven35
git clone https://github.com/srang/rh-openshift-ansible-broker-lab.git
echo export GIT_BASE="$(pwd)/rh-openshift-ansible-broker-lab" >> ~/.bashrc
source ~/.bashrc
cd ${GIT_BASE}/bootstrap

## Section 1
cd ${GIT_BASE}
git checkout section-1
cd ${GIT_BASE}/database-provision-playbook
ansible-playbook -vv database-playbook.yml -i inventory/
cd ${GIT_BASE}/widget-factory
sudo yum install -y rh-maven35 --enablerepo=rhel-server-rhscl-7-rpms
scl enable rh-maven35 bash


## Section 2
cd ${GIT_BASE}
git checkout section-2
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
