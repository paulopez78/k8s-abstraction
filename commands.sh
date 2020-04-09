#!/bin/bash

# -------------------- SETUP -------------------------
# CREATE K8s CLUSTER
kind create cluster --config kind.yaml

# CREATE NAMESPACE
kubectl delete namespace votingapp
kubectl create namespace votingapp

# -------------------------- POD ---------------------------
kubectl run votingapp \
--image=paulopez/votingapp:0.1 \
--generator=run-pod/v1 \
-v=9 

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
kubectl get pods -n kube-system | grep kube
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

kubectl label pod votingapp-xxx app=votingapp-bug
kubectl label pod votingapp-xxx app=votingapp

# Get rs from etcd
./etcd.sh "/registry/replicasets/votingapp"

# ---------------------SERVICE-----------------------------
kubectl expose replicaset votingapp \
--port=8080 \
--target-port=5000 \
--type=ClusterIP \
-v=9

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

# test cluster IP with debug tools
./debug.sh

# watch endpoints resource changing replicas from replicaset
kubectl scale replicaset votingapp --replicas 5

# NodePort type (nodePort=30500)
kubectl edit svc votingapp
docker exec kind-worker 'curl 172.17.0.4:30500'

# iptables
iptables -L -t nat | grep votingapp

# ----------------------DEPLOYMENT-----------------------
kubectl create deployment votingapp \
--image=paulopez/votingapp:0.1 \
-v 9

kubectl set image deployment/votingapp \
votingapp=votingapp:0.2-beta \
-v 9

# Get deployment from etcd
./etcd.sh "/registry/deployments/votingapp"