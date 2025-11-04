# Three-Tier Voting Application

A simple three-tier web application demonstrating modern application architecture.

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

## Running the Application

### Prerequisites
- Python 3.x
- Node.js
- .NET 6.0
- Redis server
- PostgreSQL database

### Setup

1. **Frontend**:
   ```bash
   cd frontend
   pip install -r requirements.txt
   python app.py
   ```

2. **Backend**:
   ```bash
   cd backend
   npm install
   npm start
   ```

3. **Worker**:
   ```bash
   cd worker
   dotnet run
   ```

### Access Points
- Voting Interface: http://localhost:5000
- Results Display: http://localhost:4000

## Features

- Real-time vote processing
- Duplicate vote prevention
- Live results updates
- Scalable architecture
- Language diversity (Python, Node.js, C#)
