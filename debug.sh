#!/bin/bash
kubectl delete pod tools
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tools
spec:
  containers:
    - name: tools
      image: paulopez/tools
      imagePullPolicy: Always
      args:
        - sleep
        - "99999"

EOF
kubectl wait --for=condition=Ready pod/tools
kubectl exec -it tools -- sh