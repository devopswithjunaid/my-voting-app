pipeline {
    agent {
        docker {
            image 'amazon/aws-cli:latest'
            args '-v /var/run/docker.sock:/var/run/docker.sock --user root'
        }
    }
    
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
        stage('Setup Tools') {
            steps {
                sh '''
                    echo "🔧 Installing required tools..."
                    
                    # Install Docker CLI
                    apk add --no-cache docker-cli
                    
                    # Install kubectl
                    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                    chmod +x kubectl
                    mv kubectl /usr/local/bin/
                    
                    # Install git (for checkout)
                    apk add --no-cache git
                    
                    echo "✅ Tools installed successfully"
                    
                    # Verify installations
                    docker --version
                    aws --version
                    kubectl version --client
                '''
            }
        }
        
        stage('Checkout') {
            steps {
                checkout scm
                sh 'ls -la'
                echo "✅ Code checked out successfully"
            }
        }
        
        stage('Test') {
            steps {
                echo "🧪 Running basic file checks..."
                sh '''
                    echo "Checking Dockerfiles..."
                    ls -la */Dockerfile
                    
                    echo "Checking K8s manifests..."
                    ls -la k8s/*.yaml
                    
                    echo "✅ All required files present"
                '''
            }
        }
        
        stage('Build & Push to ECR') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🏗️ Building Frontend Docker image..."
                                
                                # Build image
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                
                                # Tag images
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "📤 Pushing Frontend to ECR..."
                                
                                # Login to ECR
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                
                                # Push images
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "✅ Frontend image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🏗️ Building Backend Docker image..."
                                
                                # Build image
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                
                                # Tag images
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "📤 Pushing Backend to ECR..."
                                
                                # Login to ECR
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                
                                # Push images
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "✅ Backend image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "🏗️ Building Worker Docker image..."
                                
                                # Build image
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                
                                # Tag images
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "📤 Pushing Worker to ECR..."
                                
                                # Login to ECR
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                
                                # Push images
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "✅ Worker image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
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
                    echo "⚙️ Configuring kubectl..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    
                    kubectl cluster-info
                    
                    echo "🗄️ Deploying database and cache first..."
                    kubectl apply -f k8s/database.yaml
                    
                    echo "⏳ Waiting for database to be ready..."
                    kubectl wait --for=condition=available --timeout=300s deployment/db || true
                    kubectl wait --for=condition=available --timeout=300s deployment/redis || true
                    
                    echo "🔄 Updating image tags in manifests..."
                    sed -i "s|frontend-latest|frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                    sed -i "s|backend-latest|backend-${IMAGE_TAG}|g" k8s/backend.yaml
                    sed -i "s|worker-latest|worker-${IMAGE_TAG}|g" k8s/worker.yaml
                    
                    echo "🚀 Deploying application components..."
                    kubectl apply -f k8s/frontend.yaml
                    kubectl apply -f k8s/backend.yaml
                    kubectl apply -f k8s/worker.yaml
                    
                    echo "⏳ Checking rollout status..."
                    kubectl rollout status deployment/frontend --timeout=300s || echo "⚠️ Frontend rollout timeout"
                    kubectl rollout status deployment/backend --timeout=300s || echo "⚠️ Backend rollout timeout"
                    kubectl rollout status deployment/worker --timeout=300s || echo "⚠️ Worker rollout timeout"
                    
                    echo "📊 Deployment status:"
                    kubectl get deployments
                    kubectl get services
                    kubectl get pods
                    
                    echo "🌐 Getting LoadBalancer URLs..."
                    echo "Frontend LB:"
                    kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
                    echo ""
                    echo "Backend LB:"
                    kubectl get svc backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
                    echo ""
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
                echo "🧹 Cleaning up Docker images..."
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
            echo "🎉 Pipeline completed successfully!"
            echo "🚀 Application deployed with build: ${IMAGE_TAG}"
            echo "🌐 Frontend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
            echo "🌐 Backend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
            echo "🌐 Worker: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
            echo "📊 Check EKS cluster: ${EKS_CLUSTER_NAME}"
        }
        failure {
            echo "❌ Pipeline failed!"
            echo "🔍 Check Jenkins logs for details: ${BUILD_URL}console"
            echo "📊 EKS Cluster: ${EKS_CLUSTER_NAME}"
        }
    }
}
