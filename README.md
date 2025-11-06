# Three-Tier Voting Application

A simple three-tier web application demonstrating modern application architecture with Jenkins CI/CD pipeline.

## Architecture

This application follows a classic three-tier architecture:

### 1. Presentation Tier (Frontend)
- **Technology**: Python Flask
- **Location**: `/frontend/`
- **Purpose**: User interface for voting
- **Port**: 5000

### 2. Logic Tier (Backend)
- **Technology**: Node.js Express
- **Location**: `/backend/`
- **Purpose**: Results display and API
- **Port**: 4000

### 3. Data Tier (Database & Cache)
- **Database**: PostgreSQL (persistent storage)
- **Cache**: Redis (message queue)
- **Worker**: .NET Core (processes votes)

## Application Flow

1. **User votes** → Frontend (Flask) → Redis queue
2. **Worker processes** → Redis queue → PostgreSQL database
3. **Results display** → Backend (Node.js) → PostgreSQL → User

## Components

### Frontend (Presentation Layer)
- Simple voting interface
- Stores votes in Redis queue
- Prevents duplicate voting per browser

### Backend (Business Logic Layer)
- REST API for vote results
- Real-time results display
- Connects to PostgreSQL for data retrieval

### Worker (Data Processing Layer)
- Processes votes from Redis queue
- Stores votes in PostgreSQL database
- Handles database operations

### Data Layer
- **Redis**: Message queue for vote processing
- **PostgreSQL**: Persistent storage for votes

## CI/CD Pipeline

### Jenkins Pipeline Features
- **Docker-in-Docker (DinD)**: Custom Jenkins agent with Docker, AWS CLI, kubectl
- **Parallel Builds**: Frontend, Backend, Worker built simultaneously
- **ECR Integration**: Images pushed to AWS ECR
- **EKS Deployment**: Automated deployment to Kubernetes cluster

### Pipeline Stages
1. **Environment Setup**: Verify tools (Docker, AWS CLI, kubectl)
2. **Code Checkout**: Clone repository and verify structure
3. **Build Images**: Build Docker images in parallel
4. **Push to ECR**: Tag and push images to AWS ECR
5. **Deploy to EKS**: Update manifests and deploy to Kubernetes
6. **Verification**: Verify deployment status

## Infrastructure

### AWS Resources
- **ECR Repository**: `767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app`
- **EKS Cluster**: `secure-dev-env-cluster`
- **Region**: `us-west-2`

### Kubernetes Manifests
- `k8s/frontend.yaml` - Flask frontend deployment and service
- `k8s/backend.yaml` - Node.js backend deployment and service  
- `k8s/worker.yaml` - .NET worker deployment
- `k8s/database.yaml` - PostgreSQL and Redis deployments

## Access Points
- Voting Interface: Frontend LoadBalancer URL
- Results Display: Backend LoadBalancer URL

## Features

- Real-time vote processing
- Duplicate vote prevention
- Live results updates
- Scalable architecture
- Language diversity (Python, Node.js, C#)
- Automated CI/CD with Jenkins
- Container orchestration with Kubernetes
