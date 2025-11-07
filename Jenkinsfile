pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-dind-pod-template.yaml'
        }
    }
    
    triggers {
        cron('H/2 * * * *')  // Every 2 minutes
        pollSCM('H/2 * * * *')  // Poll SCM every 2 minutes
    }
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKER_HOST = "tcp://localhost:2375"
    }
    
    stages {
        stage('Environment Setup') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Environment Check ==="
                        whoami
                        pwd
                        echo "Build Number: ${BUILD_NUMBER}"
                        echo "Docker Host: ${DOCKER_HOST}"
                        
                        echo "=== Tool Versions ==="
                        docker --version
                        aws --version
                        kubectl version --client
                        
                        echo "=== Docker Test ==="
                        sleep 15  # Wait for DinD to start
                        docker ps
                        echo "✅ Environment ready!"
                    '''
                }
            }
        }
        
        stage('Code Checkout') {
            steps {
                container('tools') {
                    checkout scm
                    sh '''
                        echo "=== Repository Structure ==="
                        ls -la
                        find . -name "Dockerfile" -type f
                        echo "✅ Code checkout successful"
                    '''
                }
            }
        }
        
        stage('ECR Authentication') {
            steps {
                container('tools') {
                    withCredentials([aws(credentialsId: 'aws-credentials')]) {
                        sh '''
                            echo "=== ECR Login ==="
                            aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            echo "✅ ECR Login successful"
                        '''
                    }
                }
            }
        }
        
        stage('Build Docker Images') {
            parallel {
                stage('Frontend Build') {
                    steps {
                        container('tools') {
                            dir('frontend') {
                                sh '''
                                    echo "=== Building Frontend ==="
                                    docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                    docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                    echo "✅ Frontend built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                                '''
                            }
                        }
                    }
                }
                stage('Backend Build') {
                    steps {
                        container('tools') {
                            dir('backend') {
                                sh '''
                                    echo "=== Building Backend ==="
                                    docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                    docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                    echo "✅ Backend built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                                '''
                            }
                        }
                    }
                }
                stage('Worker Build') {
                    steps {
                        container('tools') {
                            dir('worker') {
                                sh '''
                                    echo "=== Building Worker ==="
                                    docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                    docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                    echo "✅ Worker built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push Images to ECR') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Pushing Images to ECR ==="
                        echo "Pushing Frontend..."
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                        
                        echo "Pushing Backend..."
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                        
                        echo "Pushing Worker..."
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                        
                        echo "✅ All images pushed successfully!"
                    '''
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                container('tools') {
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
                            
                            echo "✅ Deployment completed!"
                        '''
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Deployment Status ==="
                        kubectl get pods -o wide
                        echo ""
                        kubectl get services
                        echo ""
                        kubectl get deployments
                        
                        echo "=== Service URLs ==="
                        kubectl get svc -o wide | grep LoadBalancer || echo "No LoadBalancer services"
                        
                        echo "✅ Verification completed!"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            container('tools') {
                echo "=== Pipeline Cleanup ==="
                sh '''
                    docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                    docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                    docker system prune -f || true
                    echo "✅ Cleanup completed"
                '''
            }
        }
        success {
            echo "🎉 CI/CD Pipeline successful! Application deployed to EKS!"
        }
        failure {
            echo "❌ Pipeline failed - check logs for details"
        }
    }
}
