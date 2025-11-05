pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'my-voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'ls -la'
                echo "✅ Code checked out successfully"
            }
        }
        
        stage('Verify Tools') {
            steps {
                sh '''
                    echo "🔍 Verifying required tools..."
                    docker --version
                    aws --version || echo "⚠️ AWS CLI not found - installing..."
                    kubectl version --client || echo "⚠️ kubectl not found - installing..."
                    
                    # Install AWS CLI if missing
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -q awscliv2.zip
                        sudo ./aws/install
                        rm -rf aws awscliv2.zip
                    fi
                    
                    # Install kubectl if missing
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/
                    fi
                    
                    echo "✅ All tools verified"
                    aws --version
                    kubectl version --client
                '''
            }
        }
        
        stage('Test') {
            steps {
                echo "🧪 Running project validation..."
                sh '''
                    echo "Checking Dockerfiles..."
                    ls -la frontend/Dockerfile backend/Dockerfile worker/Dockerfile
                    
                    echo "Checking K8s manifests..."
                    ls -la k8s/*.yaml
                    
                    echo "✅ All required files present"
                '''
            }
        }
        
        stage('Build & Push Images') {
            parallel {
                stage('Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🏗️ Building Frontend..."
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "📤 Pushing Frontend to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "✅ Frontend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🏗️ Building Backend..."
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "📤 Pushing Backend to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "✅ Backend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "🏗️ Building Worker..."
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "📤 Pushing Worker to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "✅ Worker: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                echo '🚀 Deploying to EKS cluster...'
                sh '''
                    echo "⚙️ Configuring kubectl for EKS..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    kubectl cluster-info
                    
                    echo "🗄️ Deploying database and cache..."
                    kubectl apply -f k8s/database.yaml
                    
                    echo "⏳ Waiting for database to be ready..."
                    kubectl wait --for=condition=available --timeout=300s deployment/db || echo "DB timeout"
                    kubectl wait --for=condition=available --timeout=300s deployment/redis || echo "Redis timeout"
                    
                    echo "🔄 Updating image tags in manifests..."
                    sed -i "s|frontend-latest|frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                    sed -i "s|backend-latest|backend-${IMAGE_TAG}|g" k8s/backend.yaml
                    sed -i "s|worker-latest|worker-${IMAGE_TAG}|g" k8s/worker.yaml
                    
                    echo "🚀 Deploying application components..."
                    kubectl apply -f k8s/frontend.yaml
                    kubectl apply -f k8s/backend.yaml
                    kubectl apply -f k8s/worker.yaml
                    
                    echo "⏳ Checking deployment status..."
                    kubectl rollout status deployment/frontend --timeout=300s || echo "Frontend timeout"
                    kubectl rollout status deployment/backend --timeout=300s || echo "Backend timeout"
                    kubectl rollout status deployment/worker --timeout=300s || echo "Worker timeout"
                    
                    echo "📊 Final Status:"
                    kubectl get deployments
                    kubectl get services
                    kubectl get pods
                    
                    echo "🌐 LoadBalancer URLs:"
                    echo "Frontend: $(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
                    echo "Backend: $(kubectl get svc backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
                echo "🧹 Cleaning up local Docker images..."
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker system prune -f || true
            '''
        }
        success {
            echo "🎉 PIPELINE SUCCESS!"
            echo "🚀 Build Number: ${IMAGE_TAG}"
            echo "🌐 Frontend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
            echo "🌐 Backend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
            echo "🌐 Worker: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
            echo "📊 EKS Cluster: ${EKS_CLUSTER_NAME}"
            echo "🔗 Check LoadBalancer URLs in deployment logs above"
        }
        failure {
            echo "❌ PIPELINE FAILED!"
            echo "🔍 Check logs: ${BUILD_URL}console"
            echo "📊 EKS Cluster: ${EKS_CLUSTER_NAME}"
        }
    }
}
