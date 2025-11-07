pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: tools
    image: devopswithjunaid/jenkins-agent-dind:latest
    command:
    - cat
    tty: true
    env:
    - name: DOCKER_HOST
      value: "tcp://localhost:2375"
  - name: dind
    image: docker:24.0-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    args:
    - --insecure-registry=767225687948.dkr.ecr.us-west-2.amazonaws.com
    - --host=tcp://0.0.0.0:2375
'''
        }
    }
    
    triggers {
        pollSCM('H/2 * * * *')
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
                        
                        echo "=== Tool Versions ==="
                        docker --version
                        aws --version
                        kubectl version --client
                        
                        echo "=== Docker Test ==="
                        sleep 10
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
                        echo "✅ Code checkout successful"
                    '''
                }
            }
        }
        
        stage('Test Build') {
            steps {
                container('tools') {
                    sh '''
                        echo "=== Test Stage ==="
                        echo "Pipeline is working!"
                        echo "✅ Test completed"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline Cleanup ==="
        }
        success {
            echo "🎉 Pipeline successful!"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
