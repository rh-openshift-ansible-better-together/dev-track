# OpenShift-Ansible Integration Lab

## Admin Tasks
An admin needs to do the following things either during provisioning or before the lab starts:
- Ensure each person has their own project
- Ensure each person has project admin access
- Apply the `clusterrole.yaml` file to aggregate CRD permissions to the admin cluster role
- Apply the 3 CRDs: `mysql-operator/deploy/crds/*/*_crd.yaml`
- Make sure there are enough PVs in the cluster (required for mysql deployment and backup)

### TODOs Remaining:
- Have participants build parts of the operator instead of simply applying it
- We need more Ansible involved in the operator (rather than simply just apply resources)
- Improve backup/restore process
- Need to provision lab on RHPDS and validate lab works there
- HA mysql?