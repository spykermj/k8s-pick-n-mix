#!/bin/sh

# create kind cluster with the needed settings to run an ingress controller on nodeports

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 7070
    hostPort: 7070
    protocol: TCP
EOF

helm upgrade --install --create-namespace=true -n kps kps --repo https://prometheus-community.github.io/helm-charts kube-prometheus-stack \
    -f kps-values.yaml

helm -n cert-manager upgrade --install --create-namespace=true cert-manager --repo https://charts.jetstack.io cert-manager --set installCRDs=true

kubectl create ns ingress
kubectl apply -f certs.yaml

helm upgrade --install --create-namespace -n ingress haproxy haproxytech/kubernetes-ingress -f haproxy-values.yaml

# make your browswer happy by getting it to trust trustme.crt as a valid certificate authority
kubectl -n cert-manager get secret root-secret -o jsonpath='{.data.ca\.crt}' | base64 -d > trustme.crt
