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
EOF

helm upgrade --install --create-namespace=true -n kps kps --repo https://prometheus-community.github.io/helm-charts kube-prometheus-stack \
    -f kps-values.yaml

helm -n cert-manager upgrade --install --create-namespace=true cert-manager --repo https://charts.jetstack.io cert-manager --set installCRDs=true

kubectl create ns ingress
kubectl apply -f certs.yaml

helm upgrade --install -n ingress ingress-nginx --repo https://kubernetes.github.io/ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx --wait \
  --set controller.extraArgs.default-ssl-certificate="ingress/ingress-default" \
  --set controller.service.type=NodePort \
  --set controller.admissionWebhooks.certManager.enabled=true \
  --set controller.admissionWebhooks.certManager.issuerRef.name=cluster-ca-issuer \
  --set controller.admissionWebhooks.certManager.issuerRef.kind=ClusterIssuer \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \

kubectl -n ingress patch deployment ingress-nginx-controller --patch-file=nginx-ingress-patch.json

# make your browswer happy by getting it to trust trustme.crt as a valid certificate authority
kubectl get validatingwebhookconfiguration/ingress-nginx-admission -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | base64 -d > trustme.crt
