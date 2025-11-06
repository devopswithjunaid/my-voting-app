#!/bin/bash

echo "🔧 Fixing Jenkins Docker Integration..."

# Delete existing Jenkins deployment
echo "Deleting existing Jenkins deployment..."
kubectl delete deployment jenkins -n jenkins || true
kubectl delete configmap jenkins-init -n jenkins || true

# Wait for pods to terminate
echo "Waiting for pods to terminate..."
sleep 10

# Apply new Jenkins deployment with Docker support
echo "Deploying Jenkins with Docker support..."
kubectl apply -f jenkins-with-docker.yaml

# Wait for deployment to be ready
echo "Waiting for Jenkins to be ready..."
kubectl rollout status deployment/jenkins -n jenkins --timeout=300s

# Check if Jenkins is running
echo "Checking Jenkins status..."
kubectl get pods -n jenkins

echo "✅ Jenkins redeployed with Docker support!"
echo "🌐 Access Jenkins at: http://10.0.3.235:31667/"
echo "👤 Username: admin"
echo "🔑 Password: SecureJenkins123!"

# Test Docker access
echo "Testing Docker access in Jenkins..."
kubectl exec -n jenkins deployment/jenkins -- docker --version || echo "❌ Docker not accessible"
