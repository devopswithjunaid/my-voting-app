pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
    }
    
    stages {
        stage('🔍 Environment Setup') {
            steps {
                script {
                    echo "=== ENVIRONMENT SETUP ==="
                    sh '''
                        echo "📋 System Info:"
                        whoami
                        pwd
                        echo "Build: ${BUILD_NUMBER}"
                        
                        echo "🔧 Installing Tools..."
                        
                        # Install Docker if not present
                        if ! command -v docker &> /dev/null; then
                            curl -fsSL https://get.docker.com -o get-docker.sh
                            sh get-docker.sh
                        fi
                        
                        # Install AWS CLI if not present
                        if ! command -v aws &> /dev/null; then
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip awscliv2.zip
                            sudo ./aws/install
                            rm -rf awscliv2.zip aws/
                        fi
                        
                        # Install kubectl if not present
                        if ! command -v kubectl &> /dev/null; then
                            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
                            rm kubectl
                        fi
                        
                        echo "🔧 Tools Check:"
                        docker --version || echo "Docker not available"
                        aws --version || echo "AWS CLI not available"
                        kubectl version --client || echo "kubectl not available"
                        
                        echo "✅ Setup completed"
                    '''
                }
            }
        }
        
        stage('📥 Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "📂 Repo Info:"
                    git log --oneline -3
                    ls -la
                    find . -name "Dockerfile"
                '''
            }
        }
        
        stage('🏗️ Build Images') {
            parallel {
                stage('Frontend') {
                    steps {
                        sh '''
                            cd frontend
                            docker build -t voting-app:frontend-${BUILD_NUMBER} .
                        '''
                    }
                }
                stage('Backend') {
                    steps {
                        sh '''
                            cd backend
                            docker build -t voting-app:backend-${BUILD_NUMBER} .
                        '''
                    }
                }
                stage('Worker') {
                    steps {
                        sh '''
                            cd worker
                            docker build -t voting-app:worker-${BUILD_NUMBER} .
                        '''
                    }
                }
            }
        }
        
        stage('📤 Push to ECR') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        # ECR Login
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        
                        # Tag and Push
                        docker tag voting-app:frontend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                        docker tag voting-app:backend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                        docker tag voting-app:worker-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                        
                        docker push ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                        docker push ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                        docker push ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                    '''
                }
            }
        }
        
        stage('🚀 Deploy to EKS') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        # Update kubeconfig
                        aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        # Update manifests
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:frontend-.*|image: ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}|g" k8s/frontend.yaml
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:backend-.*|image: ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}|g" k8s/backend.yaml
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:worker-.*|image: ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}|g" k8s/worker.yaml
                        
                        # Deploy
                        kubectl apply -f k8s/
                        kubectl rollout status deployment/frontend
                        kubectl rollout status deployment/backend
                        kubectl rollout status deployment/worker
                    '''
                }
            }
        }
        
        stage('📊 Verify') {
            steps {
                sh '''
                    kubectl get pods
                    kubectl get svc
                '''
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f || true'
        }
    }
}
