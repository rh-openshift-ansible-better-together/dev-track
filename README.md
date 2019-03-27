# Notes
- We need a cluster-admin to create `clusterrole.yaml` before starting the lab to give project admins the ability to create the `mysql` role and custom resource. It can also be done as part of cluster provisioning.
- We need a cluster admin to create the mysql crd before starting the lab
- For minishift development, we need to change set the REGISTRY_URL as part of applying the bc pipeline
