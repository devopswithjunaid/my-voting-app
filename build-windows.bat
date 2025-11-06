@echo off
echo 🏗️ Building Jenkins Agent with Docker, AWS CLI, kubectl...

REM Login to DockerHub (enter your token when prompted)
docker login -u devopswithjunaid

REM Build the image
docker build -f Dockerfile.jenkins-agent -t jenkins-agent-dind:latest .

REM Tag for DockerHub
docker tag jenkins-agent-dind:latest devopswithjunaid/jenkins-agent-dind:latest

REM Push to DockerHub
docker push devopswithjunaid/jenkins-agent-dind:latest

echo ✅ Image built and pushed successfully!
