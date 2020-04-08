#!/bin/bash

# Get all keys and values from etcd db
key=$1
etcd_path=${2:-"/etc/kubernetes"}
#etcd_path=${2:-"/run/config/"}
etcd_pod=$(kubectl get pods -n kube-system | grep etcd | awk '{ print $1 }')

kubectl exec \
-n kube-system \
"$etcd_pod" -- \
sh -c "ETCDCTL_API=3 etcdctl \
--cacert=${etcd_path}/pki/etcd/ca.crt \
--cert=${etcd_path}/pki/etcd/healthcheck-client.crt \
--key=${etcd_path}/pki/etcd/healthcheck-client.key \
get \"$key\" \
--prefix=true -w json" | jq -r '.kvs[0].value' | base64 --decode