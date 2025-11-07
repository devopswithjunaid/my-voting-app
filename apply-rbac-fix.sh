#!/bin/bash

echo "🔧 Applying RBAC permissions for Jenkins..."

VPN_SERVER="35.85.108.1"
KEY_PATH="~/.ssh/secure-dev-keypair"

# Copy RBAC file to VPN server and apply
scp -i $KEY_PATH fix-jenkins-rbac.yaml ubuntu@$VPN_SERVER:/tmp/

ssh -i $KEY_PATH ubuntu@$VPN_SERVER << 'EOF'
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region us-west-2 --name secure-dev-env-cluster

echo "🔑 Applying RBAC permissions..."
kubectl apply -f /tmp/fix-jenkins-rbac.yaml

echo "✅ Verifying permissions..."
kubectl auth can-i create pods --as=system:serviceaccount:jenkins:jenkins -n jenkins
kubectl auth can-i list pods --as=system:serviceaccount:jenkins:default -n jenkins

echo "📋 Checking existing service accounts..."
kubectl get serviceaccounts -n jenkins

echo "🔍 Checking ClusterRoleBindings..."
kubectl get clusterrolebinding | grep jenkins

echo "✅ RBAC permissions applied successfully!"
echo "Jenkins can now create and manage pods without restart!"
EOF

echo "✅ RBAC fix completed!"
