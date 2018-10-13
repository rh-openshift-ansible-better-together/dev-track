# OpenShift-Ansible Integration Lab

## TODO

* Reach out to Bernard/Chad about any existing GPTE labs on APBs
* Framework
    * Thorntail/Microprofile
    * Spring Boot
* Service purpose
    * cookie-factory
    * cool-stuff-store
* Jenkins Deployment
    * auto-provisioned instance
    * ansible applier
    * template-service-broker
* Repo location (probably not `srang`)
* Java package path (probably not `srang`)
* Minimize required participant tooling
    * che - too much overhead
    * pre-write application code
* Schema automation
    * flyway
    * liquibase
* `before` and `completed` branches

## Components

* [Cookie Factory Service](#cookie-factory)
* [Database Provisioner APB](#db-provsioner-apb)

## Cookie Factory

Example cloud-native Java microservice that connects to a database for the purpose of 
tracking inventory for a made-up cookie factory.

## Database Provisioner APB

A playbook bundle for provisioning a database on an existing MySQL server and binding
connection information and credentials back to the application namespace.

## Lab Config

Supporting automation code used for setting lab environment on a standard OCP
environment