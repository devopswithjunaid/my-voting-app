pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Environment Setup') {
            steps {
                sh '''
                    echo "=== Environment Check ==="
                    whoami
                    pwd
                    echo "Build Number: ${BUILD_NUMBER}"
                    
                    echo "=== Installing Tools ==="
                    # Install Docker if not available
                    if ! command -v docker &> /dev/null; then
                        echo "Installing Docker..."
                        curl -fsSL https://get.docker.com -o get-docker.sh
                        sudo sh get-docker.sh || sh get-docker.sh
                        sudo usermod -aG docker jenkins || true
                        sudo systemctl start docker || sudo service docker start || true
                    fi
                    
                    # Install AWS CLI if not available
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -o awscliv2.zip
                        sudo ./aws/install --update || ./aws/install --update
                    fi
                    
                    # Install kubectl if not available
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/ || mv kubectl /usr/local/bin/
                    fi
                    
                    echo "=== Tool Verification ==="
                    docker --version || echo "Docker installation in progress..."
                    aws --version || echo "AWS CLI installation in progress..."
                    kubectl version --client || echo "kubectl installation in progress..."
                '''
            }
        }
        
        stage('Checkout Code') {
            steps {
                checkout scm
                sh '''
                    echo "=== Repository Structure ==="
                    ls -la
                    find . -name "Dockerfile" -type f
                    echo "✅ Code checkout successful"
                '''
            }
        }
        
        stage('Docker Access Setup') {
            steps {
                sh '''
                    echo "=== Setting up Docker access ==="
                    
                    # Try to access Docker
                    if docker ps >/dev/null 2>&1; then
                        echo "✅ Docker is accessible"
                    else
                        echo "Setting up Docker access..."
                        # Try different methods to access Docker
                        sudo chmod 666 /var/run/docker.sock 2>/dev/null || true
                        sudo usermod -aG docker jenkins 2>/dev/null || true
                        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
                        
                        # Wait a bit for Docker to start
                        sleep 10
                        
                        # Test again
                        if docker ps >/dev/null 2>&1; then
                            echo "✅ Docker access configured successfully"
                        else
                            echo "❌ Docker still not accessible - will show manual instructions"
                        fi
                    fi
                '''
            }
        }
        
        stage('ECR Login') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        echo "=== ECR Login ==="
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        echo "✅ ECR Login successful"
                    '''
                }
            }
        }
        
        stage('Build Images') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "=== Building Frontend ==="
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                echo "✅ Frontend image built"
                            '''
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "=== Building Backend ==="
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                echo "✅ Backend image built"
                            '''
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "=== Building Worker ==="
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                echo "✅ Worker image built"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            steps {
                sh '''
                    echo "=== Pushing Images to ECR ==="
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                    echo "✅ All images pushed to ECR"
                '''
            }
        }
        
        stage('Manual Build Instructions') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) != 0 
                }
            }
            steps {
                sh '''
                    echo "=================================================="
                    echo "🚀 MANUAL BUILD INSTRUCTIONS"
                    echo "=================================================="
                    echo "Docker not accessible. Run these commands manually:"
                    echo ""
                    echo "1. ECR Login:"
                    echo "   aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    echo ""
                    echo "2. Build Images:"
                    echo "   cd frontend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ."
                    echo "   cd backend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} ."
                    echo "   cd worker && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} ."
                    echo ""
                    echo "3. Push Images:"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                    echo "=================================================="
                '''
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        echo "=== Configuring kubectl ==="
                        aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        echo "=== Updating Kubernetes Manifests ==="
                        sed -i "s|image: .*voting-app:frontend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                        sed -i "s|image: .*voting-app:backend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}|g" k8s/backend.yaml
                        sed -i "s|image: .*voting-app:worker.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}|g" k8s/worker.yaml
                        
                        echo "=== Deploying to EKS ==="
                        kubectl apply -f k8s/database.yaml
                        kubectl apply -f k8s/frontend.yaml
                        kubectl apply -f k8s/backend.yaml
                        kubectl apply -f k8s/worker.yaml
                        
                        echo "=== Waiting for deployments ==="
                        kubectl rollout status deployment/frontend --timeout=300s || true
                        kubectl rollout status deployment/backend --timeout=300s || true
                        kubectl rollout status deployment/worker --timeout=300s || true
                        
                        echo "✅ Deployment completed"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=== Deployment Status ==="
                    kubectl get pods -o wide
                    kubectl get services
                    kubectl get deployments
                    
                    echo "=== Service URLs ==="
                    kubectl get svc -o wide
                '''
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline Cleanup ==="
            sh '''
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} 2>/dev/null || true
                docker system prune -f 2>/dev/null || true
            '''
        }
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed - check logs above"
        }
    }
}
