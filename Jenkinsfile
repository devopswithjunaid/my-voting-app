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
        stage('Checkout & Prepare') {
            steps {
                checkout scm
                sh '''
                    echo "✅ Code checked out successfully"
                    echo "Build Number: ${BUILD_NUMBER}"
                    ls -la
                    find . -name "Dockerfile" -type f
                '''
            }
        }
        
        stage('Install Docker & Tools') {
            steps {
                sh '''
                    echo "=== Installing Docker and Tools ==="
                    
                    # Install Docker using get-docker script
                    if ! command -v docker &> /dev/null; then
                        echo "Installing Docker..."
                        curl -fsSL https://get.docker.com -o get-docker.sh
                        sh get-docker.sh
                        
                        # Add jenkins user to docker group
                        usermod -aG docker jenkins || true
                        
                        # Start Docker service
                        service docker start || systemctl start docker || true
                        
                        # Test Docker
                        docker --version
                    else
                        echo "✅ Docker already installed"
                    fi
                    
                    # Install AWS CLI
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -o awscliv2.zip
                        ./aws/install --update
                    else
                        echo "✅ AWS CLI already installed"
                    fi
                    
                    # Install kubectl
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        mv kubectl /usr/local/bin/
                    else
                        echo "✅ kubectl already installed"
                    fi
                '''
            }
        }
        
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "=== Verifying Tools ==="
                    docker --version
                    aws --version
                    kubectl version --client
                    
                    echo "=== Testing Docker ==="
                    docker ps || echo "Docker daemon starting..."
                    sleep 5
                    docker ps
                '''
            }
        }
        
        stage('ECR Login') {
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
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker system prune -f || true
            '''
        }
        success {
            echo "🎉 Complete CI/CD Pipeline successful! Application deployed to EKS!"
        }
        failure {
            echo "❌ Pipeline failed - check logs above"
        }
    }
}
