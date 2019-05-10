FROM quay.io/operator-framework/ansible-operator:v0.5.0

USER 0

RUN yum install -y mysql

USER 1001

COPY roles/ ${HOME}/roles/
COPY watches.yaml ${HOME}/watches.yaml
