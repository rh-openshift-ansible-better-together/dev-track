yum install -y docker
systemctl start docker
systemctl enable docker
curl -o /usr/local/bin/operator-sdk -L https://github.com/operator-framework/operator-sdk/releases/download/v0.7.1/operator-sdk-v0.7.1-x86_64-linux-gnu
curl -o /tmp/oc.tar.gz -L https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
tar xvf /tmp/oc.tar.gz -C /tmp
mv /tmp/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/local/bin/oc
chmod 110 /usr/local/bin/operator-sdk
chmod 110 /usr/local/bin/oc