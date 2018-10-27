#!/usr/bin/env bash

# -- Not needed after initial startup --
# minishift start --extra-clusterup-flags="--enable=*,service-catalog,template-service-broker,automation-service-broker"
oc login -u system:admin
oc adm policy add-cluster-role-to-user cluster-admin srang
oc new-project widget-factory
oc process -f bootstrap.yaml | oc apply -f-