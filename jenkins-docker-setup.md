# Jenkins Docker Setup

## Problem
Jenkins container doesn't have Docker access and can't install tools with sudo.

## Solution
Mount Docker socket from host to Jenkins container.

## Steps to Fix:

### 1. Stop Jenkins Container
```bash
docker stop jenkins-container-name
```

### 2. Start Jenkins with Docker Socket
```bash
docker run -d \
  --name jenkins \
  -p 31667:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts
```

### 3. Alternative: Update Existing Container
If you can't restart Jenkins, the pipeline will install tools in /tmp directory without sudo.

## Current Pipeline Fix
- ✅ Installs AWS CLI in /tmp/aws-cli (no sudo needed)
- ✅ Installs kubectl in /tmp (no sudo needed)  
- ✅ Uses Docker socket if available
- ✅ Uses full paths to tools
