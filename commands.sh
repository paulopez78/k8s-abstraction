#!/bin/bash

# CREATE K8s CLUSTER
kind create cluster --config kind/kind.yaml

# NAMESPACE
kubectl create namespace votingapp

# ----------- POD ----------------
kubectl run votingapp \
--image=paulopez/votingapp:0.1 \
--generator=run-pod/v1 \
-v=9 

# check k8s control plane components running
kubectl get pods -n kube-system | grep kube

# KUBELET
# kind
docker exec kind-worker ps -aux | grep kubelet
# minikube
minikube ssh && pgrep kubelet

# Get pods from etcd
./etcd.sh "/registry/pods/votingapp"

# Pod creation workflow
kubectl get events --watch
kubectl describe pod votingapp

# ----------REPLICA SET----------
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  labels:
    app: votingapp
  name: votingapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: votingapp
  template:
    metadata:
      labels:
        app: votingapp
    spec:
      containers:
        - image: paulopez/votingapp:0.1
          name: votingapp
EOF

# replicaset workflow
kubectl get events --watch
kubectl describe replicaset votingapp
kubectl label pod votingapp app=votingapp-beta
kubectl label pod votingapp app=votingapp

# Get rs from etcd
./etcd.sh "/registry/replicasets/votingapp"

# ----------SERVICE----------
kubectl expose replicaset votingapp \
--port=8080 \
--target-port=5000 \
--type=ClusterIP \
-v=9

# Get service from etcd
./etcd.sh "/registry/services/votingapp"

# ----------DEPLOYMENT----------

# Get deployment from etcd
./etcd.sh "/registry/deployments/votingapp"