#!/usr/bin/env bash
# -- not needed after initial startup --
# minishift start --extra-clusterup-flags="--enable=*,service-catalog,template-service-broker,automation-service-broker"
# oc login -u system:admin
# oc adm policy add-cluster-role-to-user cluster-admin srang
oc new-project widget-factory
# oc delete is jenkins -n openshift
# oc import-image jenkins --from=registry.access.redhat.com/openshift3/jenkins-2-rhel7 -n openshift --confirm
# oc tag openshift/jenkins:latest openshift/jenkins:2
oc process -f bootstrap.yaml | oc apply -f-
oc process template/mysql-ephemeral -p MYSQL_DATABASE=widgetfactory -n openshift | oc apply -f-
oc policy add-role-to-user system:image-builder system:serviceaccount:widget-factory:builder -n openshift