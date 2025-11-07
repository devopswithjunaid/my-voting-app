pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-dind-pod-template.yaml'
            defaultContainer 'tools'
        }
    }

    triggers {
        // Check for changes every 2 minutes
        pollSCM('H/2 * * * *')
    }

    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY       = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY     = 'voting-app'
        EKS_CLUSTER_NAME   = 'secure-dev-env-cluster'
        IMAGE_TAG          = "${BUILD_NUMBER}"
        DOCKER_HOST        = 'tcp://localhost:2375'
    }

    stages {
        stage('Environment Setup') {
            steps {
                sh '''
                    echo "=== Environment Check ==="
                    whoami
                    pwd
                    echo "Build Number: ${BUILD_NUMBER}"

                    echo "=== Tool Versions ==="
                    docker --version
                    aws --version
                    kubectl version --client

                    echo "=== Docker Test ==="
                    # Allow DinD time to start
                    sleep 15
                    docker ps || true
                    echo "Environment ready"
                '''
            }
        }

        stage('Code Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "=== Repository Structure ==="
                    ls -la
                    echo "Code checkout successful"
                '''
            }
        }

        stage('ECR Authentication') {
            steps {
                withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh '''
                        echo "=== ECR Login ==="
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} \
                          | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        echo "ECR Login successful"
                    '''
                }
            }
        }

        stage('Build Docker Images') {
            parallel {
                stage('Frontend Build') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "=== Building Frontend ==="
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                echo "Frontend built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Backend Build') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "=== Building Backend ==="
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                echo "Backend built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Worker Build') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "=== Building Worker ==="
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                echo "Worker built: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
            }
        }

        stage('Push Images to ECR') {
            steps {
                sh '''
                    echo "=== Pushing Images to ECR ==="
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                    echo "All images pushed successfully"
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[ $class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials', accessKeyVariable: 'AWS_ACCESS_KEY_ID', secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
                    sh '''
                        echo "=== Configuring kubectl ==="
                        aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}

                        echo "=== Updating Kubernetes Manifests ==="
                        sed -i "s|image: .*voting-app:frontend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}|" k8s/frontend.yaml
                        sed -i "s|image: .*voting-app:backend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}|" k8s/backend.yaml
                        sed -i "s|image: .*voting-app:worker.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}|" k8s/worker.yaml

                        echo "=== Deploying to EKS ==="
                        kubectl apply -f k8s/database.yaml
                        kubectl apply -f k8s/frontend.yaml
                        kubectl apply -f k8s/backend.yaml
                        kubectl apply -f k8s/worker.yaml

                        echo "=== Waiting for deployments ==="
                        kubectl rollout status deployment/frontend --timeout=300s || true
                        kubectl rollout status deployment/backend --timeout=300s || true
                        kubectl rollout status deployment/worker --timeout=300s || true
                        echo "Deployment completed"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=== Deployment Status ==="
                    kubectl get pods -o wide
                    echo ""
                    kubectl get services
                    echo ""
                    kubectl get deployments
                    echo ""
                    echo "=== LoadBalancer services (if any) ==="
                    kubectl get svc -o wide | grep LoadBalancer || echo "No LoadBalancer services"
                    echo "Verification completed"
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
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker system prune -f || true
                echo "Cleanup completed"
            '''
        }
        success {
            echo "CI/CD pipeline successful. Application deployed to EKS"
        }
        failure {
            echo "Pipeline failed - check logs for details"
        }
    }
}
