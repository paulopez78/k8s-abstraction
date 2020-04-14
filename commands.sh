#!/bin/bash

# -------------------- SETUP -------------------------
# CREATE K8s CLUSTER
kind create cluster --config kind.yaml
kubectl get nodes

# CREATE NAMESPACE
kubectl delete namespace votingapp
kubectl create namespace votingapp
kubectl get namespaces 
kubens votingapp

# -------------------------- POD ---------------------------
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: votingapp
  name: votingapp
spec:
  containers:
    - image: paulopez/votingapp:0.1
      name: votingapp
EOF

# verify is up and running
kubectl logs votingapp

# check k8s control plane components running
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide | grep kind-control-plane
docker exec kind-worker ps -aux | grep kubelet

# Get pods from etcd
./etcd.sh "/registry/pods/votingapp"

# Pod creation workflow
kubectl get events --watch
kubectl describe pod votingapp

# check pod is running with debug tool
kubectl get pods -o wide
./debug.sh

# ----------------------REPLICA SET------------------------
kubectl delete pod votingapp
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
kubectl get pods -l app=votingapp

# delete random pod
kubectl delete pod votingapp-xxx 

# relabel pods
kubectl label pod votingapp-xxx app=votingapp-debug
kubectl label pod votingapp-xxx app=votingapp

# Get rs from etcd
./etcd.sh "/registry/replicasets/votingapp"

# ---------------------SERVICE-----------------------------
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: votingapp
spec:
  ports:
  - port: 8080
    targetPort: 5000
  selector:
    app: votingapp
  type: ClusterIP
EOF

# Get service from etcd
./etcd.sh "/registry/services/votingapp"

# test cluster IP and Pod IP with debug tools
./debug.sh

# watch endpoints resource changing replicas from replicaset
watch "kubectl get pods -o wide --show-labels"
kubectl get ep -w
kubectl scale replicaset votingapp --replicas 5

# NodePort type (nodePort=30500)
kubectl edit svc votingapp
docker exec kind-worker sh -c 'curl 172.17.0.4:30500/vote'

# iptables
iptables -L -t nat | grep votingapp

# ----------------------DEPLOYMENT-----------------------
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: votingapp
spec:
  minReadySeconds: 30
  strategy:
    type: RollingUpdate
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

# setup watchers for testing rolling update
watch "kubectl get pods --show-labels -o wide"
kubectl get endpoints -w
watch "kubectl get rs -o wide"
watch "kubectl get deployments -o wide"
watch "docker exec kind-worker sh -c 'curl 172.17.0.4:30500 --silent' | grep h1"

# trigger rolling update
kubectl set image deployment/votingapp \
votingapp=paulopez/votingapp:0.2-beta \
-v 9

# Get deployment from etcd
./etcd.sh "/registry/deployments/votingapp"