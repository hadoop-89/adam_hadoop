# 🚀 Hadoop Big Data Infrastructure

**Complete Hadoop cluster with real-time web scraping, data processing, and AI integration**

This repository contains the Hadoop infrastructure component of our **Hadoop & AI Project**, designed to handle big data processing, real-time web scraping, and seamless integration with AI services.

## ⚠️ Important Prerequisites for Evaluators

**Before starting, please ensure the following setup:**

### 1. Install Git Bash (Required)
This project uses shell scripts that require Git Bash on Windows:

```bash
# Download and install Git for Windows from:
# https://git-scm.com/download/win

# After installation, always use Git Bash terminal for this project
```

### 2. Set File Permissions (Critical)
After cloning, you **must** give execution rights to script files:

```bash
# Navigate to project directory in Git Bash
cd adam_hadoop

# Grant execution permissions to all scripts
chmod +x scripts/*.sh
chmod +x *.sh
find . -name "*.sh" -exec chmod +x {} \;

# Verify permissions
ls -la scripts/
```

### 3. Docker Desktop Setup
```bash
# Ensure Docker Desktop is running with WSL2 backend
# Minimum requirements:
# - 8GB RAM allocated to Docker
# - 20GB free disk space
# - WSL2 enabled on Windows
```

**⚡ Without these prerequisites, the deployment will fail!**

---

## 📋 Overview

This project implements a production-ready Hadoop ecosystem that includes:

- **Multi-node Hadoop cluster** (1 NameNode + 2 DataNodes)
- **Real-time web scraping** with Kafka streaming
- **Spark processing** for data analytics
- **Hive data warehouse** for structured queries
- **Streamlit dashboard** for real-time monitoring
- **AI API integration** for machine learning workflows

## 🏗️ Architecture

### High-Level System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Sources   │───▶│   Web Scraper   │───▶│      Kafka      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐    ┌─────────▼─────────┐
│   Dashboard     │◀───│  Spark Cluster  │◀───│   Streaming     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐    ┌─────────▼─────────┐
│   Hive/Analytics│◀───│  HDFS Storage   │◀───│   Data Loading   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────▼
                    ┌─────────────────┐
                    │   AI API        │
                    │  Integration    │
                    └─────────────────┘
```

### Detailed Technical Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRESENTATION LAYER                              │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│  Streamlit      │  Hadoop Web UI  │  Spark Web UI   │  Kafka Manager          │
│  Dashboard      │  (Port 9870)    │  (Port 8080)    │  (Port 9000)            │
│  (Port 8501)    │                 │                 │                         │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APPLICATION LAYER                               │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│   Web Scraper   │  Spark Jobs     │  Hive Queries   │  AI Integration         │
│   - Reddit API  │  - Analytics    │  - Data Warehouse│  - REST API Client     │
│   - News RSS    │  - ML Pipeline  │  - SQL Interface│  - Batch Processing     │
│   - Image APIs  │  - Streaming    │  - Reporting    │  - Real-time Inference  │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PROCESSING LAYER                                │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│  Apache Kafka   │  Apache Spark   │  Apache Hive    │  Data Loaders           │
│  - Message      │  - Master Node  │  - Metastore    │  - External Datasets    │
│    Streaming    │  - Worker Nodes │  - Query Engine │  - CSV/JSON Parsers     │
│  - Topic Mgmt   │  - Distributed  │  - JDBC Server  │  - Data Validation      │
│                 │    Computing    │                 │                         │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                               STORAGE LAYER                                  │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│      HDFS       │   PostgreSQL    │  Docker Volumes │  Backup Storage         │
│  - NameNode     │  - Hive Meta    │  - Container    │  - Incremental Backups │
│  - DataNode 1   │  - Metadata     │    Persistence  │  - Configuration Backup │
│  - DataNode 2   │  - Schema Info  │  - Log Storage  │  - Data Export/Import   │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
                                    │
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INFRASTRUCTURE LAYER                               │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│  Docker Engine  │  Networking     │  Monitoring     │  Security               │
│  - Containers   │  - Internal     │  - Health       │  - Network Isolation    │
│  - Orchestration│    Network      │    Checks       │  - Access Control       │
│  - Resource     │  - Port         │  - Metrics      │  - Data Encryption      │
│    Management   │    Mapping      │    Collection   │                         │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────┘
```

### Component Architecture Details

#### 1. Data Ingestion Layer
```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA INGESTION PIPELINE                     │
│                                                                 │
│  Web Sources                    Scraper Services               │
│  ┌─────────────┐               ┌─────────────────┐             │
│  │ Reddit API  │──────────────▶│ Reddit Scraper  │             │
│  │ News RSS    │──────────────▶│ News Scraper    │─────────┐   │
│  │ HackerNews  │──────────────▶│ HN Scraper      │         │   │
│  │ Image APIs  │──────────────▶│ Image Scraper   │         │   │
│  └─────────────┘               └─────────────────┘         │   │
│                                                             │   │
│  ┌─────────────────────────────────────────────────────────▼───┤
│  │                    KAFKA MESSAGE BROKER                     │
│  │                                                              │
│  │  Topics:                    Partitions:                     │
│  │  • scraped-text     ────▶   • Partition 0: Reddit          │
│  │  • scraped-images   ────▶   • Partition 1: News            │
│  │  • scraped-metadata ────▶   • Partition 2: Images          │
│  │                                                              │
│  │  Features:                                                   │
│  │  • Message persistence (7 days retention)                   │
│  │  • Automatic scaling and load balancing                     │
│  │  • Consumer group management                                │
│  └──────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

#### 2. Processing and Analytics Layer
```
┌─────────────────────────────────────────────────────────────────┐
│                  DISTRIBUTED PROCESSING LAYER                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    APACHE SPARK CLUSTER                    ││
│  │                                                             ││
│  │  Master Node                 Worker Nodes                  ││
│  │  ┌─────────────┐             ┌──────────┬──────────┐       ││
│  │  │ Resource    │             │ Worker 1 │ Worker 2 │       ││
│  │  │ Manager     │─────────────│ 2GB RAM  │ 2GB RAM  │       ││
│  │  │ Job         │             │ 2 Cores  │ 2 Cores  │       ││
│  │  │ Scheduler   │             └──────────┴──────────┘       ││
│  │  └─────────────┘                                           ││
│  │                                                             ││
│  │  Processing Types:                                          ││
│  │  • Batch Processing    ──── Historical data analysis       ││
│  │  • Stream Processing   ──── Real-time data processing      ││
│  │  • ML Pipelines       ──── Machine learning workflows     ││
│  │  • Data Transformation ──── ETL operations                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                      APACHE HIVE                           ││
│  │                                                             ││
│  │  Components:                                                ││
│  │  • Metastore      ──── Schema and metadata management      ││
│  │  • Query Engine   ──── SQL query processing               ││
│  │  • JDBC Server    ──── External tool connectivity         ││
│  │  • Storage Format ──── Parquet, ORC optimization          ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

#### 3. Storage Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                     HADOOP DISTRIBUTED FILE SYSTEM             │
│                                                                 │
│  NameNode (Master)              DataNodes (Workers)            │
│  ┌─────────────────┐           ┌────────────┬────────────┐     │
│  │ Metadata        │           │ DataNode1  │ DataNode2  │     │
│  │ • File System   │───────────│ Block      │ Block      │     │
│  │   Tree          │           │ Storage    │ Storage    │     │
│  │ • Block         │           │ 20GB       │ 20GB       │     │
│  │   Locations     │           │ Capacity   │ Capacity   │     │
│  │ • Replication   │           └────────────┴────────────┘     │
│  │   Policies      │                                           │
│  └─────────────────┘                                           │
│                                                                 │
│  Data Organization:                                             │
│  /data/                                                         │
│  ├── text/                                                      │
│  │   ├── existing/     ── Pre-loaded datasets                  │
│  │   ├── scraped/      ── Real-time scraped content            │
│  │   └── processed/    ── Cleaned and analyzed data            │
│  ├── images/                                                    │
│  │   ├── metadata/     ── Image information and tags           │
│  │   └── thumbnails/   ── Generated preview images             │
│  ├── streaming/                                                 │
│  │   ├── raw/          ── Unprocessed stream data              │
│  │   └── processed/    ── Real-time analytics results          │
│  └── analytics/                                                 │
│      ├── reports/      ── Generated analytical reports         │
│      └── models/       ── ML model artifacts                   │
│                                                                 │
│  Features:                                                      │
│  • Automatic replication (factor: 2)                           │
│  • Block size optimization (256MB)                             │
│  • Fault tolerance and recovery                                │
│  • Load balancing across DataNodes                             │
└─────────────────────────────────────────────────────────────────┘
```

#### 4. Data Flow Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                      REAL-TIME DATA FLOW                       │
│                                                                 │
│  1. Data Ingestion                                              │
│     Web Sources ──▶ Scrapers ──▶ Kafka Topics                  │
│                     (Every 5min)  (Message Queue)              │
│                                                                 │
│  2. Stream Processing                                           │
│     Kafka ──▶ Spark Streaming ──▶ Data Validation              │
│              (Real-time)          (Quality Checks)             │
│                                                                 │
│  3. Data Storage                                                │
│     Validated Data ──▶ HDFS ──▶ Hive Tables                    │
│                       (Persistent) (Structured)                │
│                                                                 │
│  4. Analytics & AI                                              │
│     HDFS Data ──▶ Spark Jobs ──▶ AI API ──▶ Results            │
│                  (Batch)         (ML Models)  (Insights)       │
│                                                                 │
│  5. Visualization                                               │
│     Results ──▶ Dashboard ──▶ User Interface                   │
│              (Streamlit)     (Real-time Updates)               │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │                    BATCH DATA FLOW                         │ │
│ │                                                             │ │
│ │  External Data ──▶ Data Loaders ──▶ HDFS                   │ │
│ │  (CSV, JSON)      (Validation)      (Storage)              │ │
│ │                                                             │ │
│ │  HDFS ──▶ Spark Batch Jobs ──▶ Hive ──▶ Reports            │ │
│ │         (Analytics)           (Warehouse) (Dashboard)       │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

#### 5. Monitoring and Observability Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    MONITORING ARCHITECTURE                     │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                  METRICS COLLECTION                        ││
│  │                                                             ││
│  │  System Metrics          Application Metrics               ││
│  │  ┌─────────────┐         ┌─────────────────┐               ││
│  │  │ Docker      │         │ HDFS Stats      │               ││
│  │  │ Containers  │────────▶│ Spark Jobs      │──────────┐    ││
│  │  │ Resource    │         │ Kafka Topics    │          │    ││
│  │  │ Usage       │         │ Scraper Status  │          │    ││
│  │  └─────────────┘         └─────────────────┘          │    ││
│  │                                                       │    ││
│  │                          ┌─────────────────────────────▼────┤│
│  │                          │       STREAMLIT DASHBOARD       ││
│  │                          │                                  ││
│  │                          │ • Real-time cluster health      ││
│  │                          │ • Data processing statistics    ││
│  │                          │ • Performance metrics          ││
│  │                          │ • Alert notifications          ││
│  │                          │ • Interactive data exploration  ││
│  │                          └──────────────────────────────────┘│
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Health Check Endpoints:                                        │
│  • NameNode:    http://localhost:9870/jmx                      │
│  • Spark:       http://localhost:8080/api/v1/status            │
│  • Dashboard:   http://localhost:8501/health                   │
│  • Kafka:       Internal broker health monitoring              │
└─────────────────────────────────────────────────────────────────┘
```

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DOCKER NETWORK TOPOLOGY                   │
│                                                                 │
│  Host Machine (Windows/Linux)                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Docker Internal Network                       ││
│  │              (hadoop-network: 172.20.0.0/16)             ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        ││
│  │  │ NameNode    │  │ DataNode1   │  │ DataNode2   │        ││
│  │  │ 172.20.0.10 │  │ 172.20.0.11 │  │ 172.20.0.12 │        ││
│  │  │ Port: 9870  │  │ Port: 9864  │  │ Port: 9865  │        ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘        ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        ││
│  │  │ Spark       │  │ Kafka       │  │ Hive        │        ││
│  │  │ Master      │  │ Broker      │  │ Server      │        ││
│  │  │ 172.20.0.20 │  │ 172.20.0.30 │  │ 172.20.0.40 │        ││
│  │  │ Port: 8080  │  │ Port: 9092  │  │ Port: 10000 │        ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘        ││
│  │                                                             ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        ││
│  │  │ Dashboard   │  │ Scraper     │  │ Zookeeper   │        ││
│  │  │ 172.20.0.50 │  │ 172.20.0.60 │  │ 172.20.0.35 │        ││
│  │  │ Port: 8501  │  │ Internal    │  │ Port: 2181  │        ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Port Mappings (Host ↔ Container):                             │
│  • 9870  ↔ NameNode Web UI                                     │
│  • 8080  ↔ Spark Master Web UI                                 │
│  • 8501  ↔ Streamlit Dashboard                                 │
│  • 9864  ↔ DataNode1 Web UI                                    │
│  • 9865  ↔ DataNode2 Web UI                                    │
│  • 9000  ↔ Kafka Manager (Optional)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      SECURITY ARCHITECTURE                     │
│                                                                 │
│  Network Security                                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ • Docker internal network isolation                        ││
│  │ • Port-based access control                                ││
│  │ • No external database connections                         ││
│  │ • Container-to-container communication only               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Data Security                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ • HDFS block-level replication                             ││
│  │ • Data integrity checksums                                 ││
│  │ • Automatic backup and recovery                            ││
│  │ • Volume encryption (Docker volumes)                       ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Access Control                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ • Web UI authentication (configurable)                     ││
│  │ • HDFS permission model                                    ││
│  │ • Hive table-level security                                ││
│  │ • API rate limiting for scrapers                           ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

This architecture provides:
- **Scalability**: Horizontal scaling through additional DataNodes and Spark workers
- **Fault Tolerance**: HDFS replication and Spark job recovery mechanisms
- **Real-time Processing**: Kafka streaming with Spark integration
- **Monitoring**: Comprehensive health checks and performance metrics
- **Security**: Network isolation and data protection
- **Flexibility**: Modular design allowing component replacement and extension

## ⚡ Quick Start

### Prerequisites

- **Git Bash** (mandatory for Windows users)
- Docker Desktop (with WSL2 on Windows)
- 8GB+ RAM recommended
- 20GB+ free disk space

### 1. Clone and Deploy

```bash
# In Git Bash terminal:
git clone https://github.com/hadoop-89/adam_hadoop.git
cd adam_hadoop

# Set permissions (MANDATORY STEP)
chmod +x scripts/*.sh

# Stop everything (all containers) and clean everything (volumes, unused images, cache, orphaned networks, etc.)
docker stop $(docker ps -aq) && docker system prune -af --volumes

# Deploy complete cluster
./scripts/deploy.sh
```

### 2. Verify Deployment

```bash
# Check cluster health
./scripts/deploy.sh --status

# View all services
docker ps

# Check logs if issues occur
docker-compose logs -f
```

### 3. Access Web Interfaces

- **NameNode UI**: http://localhost:9870
- **Spark Master**: http://localhost:8080  
- **Streamlit Dashboard**: http://localhost:8501
- **DataNode1**: http://localhost:9864
- **DataNode2**: http://localhost:9865
- **Kafka Manager**: http://localhost:9000

## 🌐 Real-Time Web Scraping

The scraper continuously collects data from multiple sources:

**Text Sources:**
- HackerNews RSS feeds
- Reddit Technology posts
- BBC Technology news
- TechCrunch articles
- Reuters Technology
- Stack Overflow trending

**Image Sources:**
- Reddit image subreddits (/r/earthporn, /r/cityporn, /r/spaceporn)
- Instagram public feeds (metadata only)
- Unsplash API integration
- Metadata extraction and categorization

**Data Flow:**
```
Web Sources → Scraper → Kafka → Spark Streaming → HDFS → Hive → Dashboard
```

**Scraping Configuration:**
```bash
# Adjust scraping frequency (default: 5 minutes)
export SCRAPE_INTERVAL=300

# Enable/disable specific sources
export ENABLE_REDDIT=true
export ENABLE_NEWS=true
export ENABLE_IMAGES=true
```

## 📊 Data Processing

### HDFS Structure
```
/data/
├── text/
│   ├── existing/     # Pre-loaded datasets (Amazon reviews, news)
│   ├── scraped/      # Real-time scraped articles
│   └── processed/    # Cleaned and processed text
├── images/
│   ├── existing/     # Pre-loaded image metadata
│   ├── scraped/      # Scraped image metadata
│   └── thumbnails/   # Generated thumbnails
├── streaming/        # Real-time Kafka data
│   ├── raw/         # Raw stream data
│   └── processed/   # Stream processing results
├── analytics/       # Spark analytics results
├── ia_results/      # AI analysis results
└── backup/          # Backup and checkpoints
```

### Spark Analytics

```bash
# Run comprehensive analytics on collected data
docker exec spark-master python /opt/spark-jobs/demo_analytics.py

# Real-time streaming analytics
docker exec spark-master python /opt/spark-jobs/streaming_analytics.py

# Text sentiment analysis
docker exec spark-master python /opt/spark-jobs/sentiment_analysis.py

# Image metadata processing
docker exec spark-master python /opt/spark-jobs/image_processing.py

# Test Hadoop ↔ AI integration
docker exec spark-master python /opt/spark-jobs/test_hadoop_ia_integration.py

# Custom analytics (modify parameters)
docker exec spark-master spark-submit \
  --master spark://spark-master:7077 \
  --executor-memory 1g \
  --total-executor-cores 2 \
  /opt/spark-jobs/custom_analytics.py
```

### Hive Queries

```bash
# Connect to Hive
docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000

# Example queries for text data
USE analytics;
SELECT source, COUNT(*) FROM reviews GROUP BY source;
SELECT category, AVG(rating) FROM reviews GROUP BY category;
SELECT DATE(created_at), COUNT(*) FROM scraped_articles 
  WHERE source='hackernews' GROUP BY DATE(created_at);

# Image metadata queries
SELECT image_category, COUNT(*) FROM image_metadata GROUP BY image_category;
SELECT AVG(file_size), source FROM image_metadata GROUP BY source;

# Streaming data analysis
SELECT hour, COUNT(*) FROM streaming_stats 
  WHERE date = CURRENT_DATE GROUP BY hour ORDER BY hour;

# Performance queries
ANALYZE TABLE reviews COMPUTE STATISTICS;
SHOW TABLE EXTENDED LIKE 'reviews';
```

## 🤖 AI Integration

This Hadoop cluster is designed to work with the companion **AI API repository**:

```bash
# Test AI connectivity
curl http://localhost:8001/health

# Send text data to AI for sentiment analysis
python spark-jobs/api_client.py --type sentiment --data "sample text"

# Send image metadata for classification
python spark-jobs/api_client.py --type classification --data /path/to/image

# Batch processing integration
python spark-jobs/batch_ai_integration.py

# Real-time AI streaming
python spark-jobs/realtime_ai_stream.py
```

The AI integration enables:
- **Sentiment analysis** of scraped text data with real-time scoring
- **Image classification** of collected images using deep learning models
- **Topic modeling** for news articles and social media posts
- **Real-time ML inference** on streaming data with sub-second latency
- **Batch processing** for large datasets with distributed computing
- **Anomaly detection** in streaming data patterns
- **Recommendation systems** based on user behavior data

**AI Pipeline Features:**
- Automatic model retraining based on new data
- A/B testing for different AI models
- Model versioning and rollback capabilities
- Distributed inference across Spark cluster
- GPU acceleration support (if available)

## 📈 Monitoring & Dashboard

The Streamlit dashboard provides real-time insights:

**Main Dashboard Features:**
- **HDFS data statistics** and health metrics with visual charts
- **Real-time scraping activity** with live updates every 30 seconds
- **Kafka topic monitoring** and message counts with throughput graphs
- **Cluster health status** for all services with alert notifications
- **Performance metrics** and resource usage with historical trends
- **Data quality metrics** with validation reports
- **AI model performance** tracking and comparison

**Advanced Dashboard Pages:**
- **Data Explorer**: Interactive data browsing and filtering
- **Analytics Workbench**: Custom query interface
- **System Logs**: Centralized logging with search capabilities
- **Alert Center**: Real-time notifications and issue tracking
- **Resource Monitor**: CPU, memory, and disk usage across cluster

Features:
- Auto-refresh capabilities (configurable intervals)
- Interactive data exploration with drill-down capabilities
- Real-time scraped articles display with sentiment scores
- Image metadata visualization with thumbnail previews
- Export functionality for reports and data
- Dark/light theme support
- Mobile-responsive design

```bash
# Access dashboard components
# Main dashboard: http://localhost:8501
# Metrics API: http://localhost:8501/metrics
# Health check: http://localhost:8501/health
```

## 🛠️ Configuration

### Environment Variables

Create `.env` file for custom configuration:

```bash
# Scraping Configuration
SCRAPE_INTERVAL=300
MAX_ARTICLES_PER_SOURCE=100
ENABLE_IMAGE_SCRAPING=true

# Kafka Configuration  
KAFKA_RETENTION_HOURS=168
KAFKA_PARTITIONS=3
KAFKA_REPLICATION_FACTOR=1

# Spark Configuration
SPARK_WORKER_MEMORY=2G
SPARK_WORKER_CORES=2
SPARK_EXECUTOR_MEMORY=1G

# HDFS Configuration
DFS_REPLICATION=2
DFS_BLOCKSIZE=134217728

# Dashboard Configuration
DASHBOARD_REFRESH_INTERVAL=30
ENABLE_ALERTS=true
LOG_LEVEL=INFO
```

### Scaling DataNodes

Modify `docker-compose.yml` to add more DataNodes:

```yaml
datanode3:
  build:
    context: ./hadoop-datanode
  container_name: datanode3
  hostname: datanode3
  ports:
    - "9866:9864"
    - "9876:9866"
  volumes:
    - datanode3-data:/hadoop/dfs/data
  environment:
    - CLUSTER_NAME=hadoop-cluster
  networks:
    - hadoop-network

volumes:
  datanode3-data:
```

### Scraper Configuration

Advanced scraper settings in `scraper/config.py`:

```python
# Source-specific configurations
REDDIT_CONFIG = {
    'subreddits': ['technology', 'programming', 'MachineLearning'],
    'limit': 50,
    'time_filter': 'day'
}

NEWS_CONFIG = {
    'sources': ['bbc', 'techcrunch', 'reuters'],
    'categories': ['technology', 'business', 'science'],
    'language': 'en'
}

IMAGE_CONFIG = {
    'min_resolution': (800, 600),
    'max_file_size': '10MB',
    'allowed_formats': ['jpg', 'png', 'webp']
}
```

### Kafka Topics Management

```bash
# List current topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Create new topic with custom partitions
docker exec kafka kafka-topics --bootstrap-server localhost:9092 \
  --create --topic custom-topic --partitions 6 --replication-factor 1

# Modify topic configuration
docker exec kafka kafka-configs --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name scraped-data \
  --alter --add-config retention.ms=604800000

# Monitor topic performance
docker exec kafka kafka-consumer-perf-test \
  --bootstrap-server localhost:9092 --topic scraped-data \
  --messages 1000 --threads 1
```

## 🔧 Advanced Operations

### Cluster Management

```bash
# Clean restart (preserves data)
./scripts/deploy.sh --clean

# Fresh deployment (removes all data - USE WITH CAUTION)
./scripts/deploy.sh --fresh

# Debug mode with verbose logging
./scripts/deploy.sh --debug

# Ordered deployment for troubleshooting
./scripts/deploy.sh --ordered

# Scale specific services
./scripts/deploy.sh --scale spark-worker=3

# Backup cluster state
./scripts/backup.sh --full

# Restore from backup
./scripts/restore.sh --backup-id 20231215_143022
```

### Data Loading and Migration

```bash
# Load external datasets
docker-compose run --rm data-loader

# Bulk data import from local files
docker exec namenode hdfs dfs -put /local/data/* /data/external/

# Export data for external processing
docker exec namenode hdfs dfs -get /data/processed /local/export/

# Data migration between clusters
./scripts/migrate_data.sh --source cluster1 --target cluster2

# Incremental backup
./scripts/backup.sh --incremental --since yesterday
```

### Performance Optimization

```bash
# Optimize HDFS blocks
docker exec namenode hdfs balancer -threshold 5

# Compact Hive tables
docker exec hive-server hive -e "ALTER TABLE reviews COMPACT 'major';"

# Spark performance tuning
docker exec spark-master spark-submit \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --conf spark.sql.adaptive.skewJoin.enabled=true \
  /opt/spark-jobs/optimized_job.py

# Monitor cluster performance
./scripts/performance_monitor.sh --duration 3600
```

## 🚨 Troubleshooting

### Common Issues and Solutions

**NameNode Safe Mode Issues:**
```bash
# Check safe mode status
docker exec namenode hdfs dfsadmin -safemode get

# Force leave safe mode (use carefully)
docker exec namenode hdfs dfsadmin -safemode leave

# Check block reports
docker exec namenode hdfs dfsadmin -report
```

**DataNodes Not Connecting:**
```bash
# Verify network connectivity
docker exec namenode hdfs dfsadmin -report

# Check DataNode logs
docker logs datanode1 --tail 50
docker logs datanode2 --tail 50

# Restart specific DataNode
docker-compose restart datanode1

# Check HDFS health
docker exec namenode hdfs fsck / -files -blocks -locations
```

**Kafka Connectivity Issues:**
```bash
# Test Kafka broker connectivity
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Check consumer lag
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --describe --all-groups

# Reset consumer group (if stuck)
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --group scraper-group --reset-offsets \
  --to-earliest --topic scraped-data --execute

# Monitor Kafka performance
docker exec kafka kafka-log-dirs \
  --bootstrap-server localhost:9092 --describe --json
```

**Spark Job Failures:**
```bash
# Check Spark application logs
docker exec spark-master spark-submit \
  --deploy-mode client --driver-java-options "-Dlog4j.debug=true" \
  /opt/spark-jobs/failing_job.py

# Monitor Spark resources
curl http://localhost:8080/api/v1/applications

# Clear Spark checkpoints
docker exec spark-master rm -rf /tmp/spark-checkpoints/*

# Restart Spark cluster
docker-compose restart spark-master spark-worker1 spark-worker2
```

**Dashboard Not Loading:**
```bash
# Check Streamlit logs
docker logs dashboard --tail 50

# Verify port availability
netstat -an | grep 8501

# Restart dashboard with debug mode
docker-compose up dashboard --build

# Test dashboard health endpoint
curl http://localhost:8501/health
```

### Health Checks and Monitoring

```bash
# Complete cluster health check
./scripts/health_check.sh --comprehensive

# Individual service health
curl http://localhost:9870/jmx              # NameNode JMX
curl http://localhost:8501/metrics          # Dashboard metrics
curl http://localhost:8080/api/v1/status    # Spark status

# Resource usage monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Disk usage analysis
docker exec namenode hdfs dfs -du -h /data
docker system df -v
```

### Log Analysis

```bash
# Centralized log collection
./scripts/collect_logs.sh --output /tmp/cluster_logs/

# Search across all logs
./scripts/search_logs.sh --pattern "ERROR" --since "2023-12-15"

# Real-time log monitoring
docker-compose logs -f --tail 10 namenode datanode1 spark-master

# Export logs for analysis
./scripts/export_logs.sh --format json --timerange last_hour
```

## 📊 Performance Tuning

### Resource Allocation

Optimize Docker resource allocation in `docker-compose.yml`:

```yaml
spark-master:
  environment:
    - SPARK_WORKER_MEMORY=4G
    - SPARK_WORKER_CORES=4
    - SPARK_DRIVER_MEMORY=2G
  deploy:
    resources:
      limits:
        memory: 6G
        cpus: '4.0'
      reservations:
        memory: 4G
        cpus: '2.0'
```

### HDFS Configuration

Optimize HDFS performance in `hadoop-namenode/hdfs-site.xml`:

```xml
<property>
    <name>dfs.replication</name>
    <value>2</value>
</property>
<property>
    <name>dfs.block.size</name>
    <value>268435456</value> <!-- 256MB blocks -->
</property>
<property>
    <name>dfs.datanode.max.transfer.threads</name>
    <value>8192</value>
</property>
```

### Kafka Performance Tuning

```bash
# Optimize Kafka for throughput
docker exec kafka kafka-configs --bootstrap-server localhost:9092 \
  --entity-type brokers --entity-name 1 \
  --alter --add-config num.network.threads=8,num.io.threads=16

# Batch processing optimization
docker exec kafka kafka-configs --bootstrap-server localhost:9092 \
  --entity-type topics --entity-name scraped-data \
  --alter --add-config batch.size=32768,linger.ms=10
```

## 🔗 Integration Points

This Hadoop cluster integrates with:

- **AI API Repository**: RESTful ML inference and batch processing
- **External data sources**: Real-time web scraping with rate limiting
- **Analytics tools**: Jupyter notebooks, Tableau, Power BI connectors
- **Monitoring systems**: Prometheus, Grafana, ELK stack integration
- **Cloud platforms**: AWS S3, Azure Blob, Google Cloud Storage
- **CI/CD pipelines**: Jenkins, GitLab CI, GitHub Actions
- **Message queues**: RabbitMQ, Apache Pulsar compatibility

### API Endpoints

```bash
# Cluster status API
GET http://localhost:9870/webhdfs/v1/?op=LISTSTATUS

# Spark job submission API  
POST http://localhost:8080/api/v1/submissions/create

# Dashboard API
GET http://localhost:8501/api/metrics
GET http://localhost:8501/api/data/recent

# Health check endpoints
GET http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=FSNamesystemState
```

## 📚 Documentation

### Official Documentation
- [Hadoop Official Documentation](https://hadoop.apache.org/docs/)
- [Spark Programming Guide](https://spark.apache.org/docs/latest/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Hive User Guide](https://cwiki.apache.org/confluence/display/Hive/Home)

### Project-Specific Guides
- [Deployment Guide](./docs/deployment.md)
- [Troubleshooting Guide](./docs/troubleshooting.md)
- [API Reference](./docs/api_reference.md)
- [Performance Tuning](./docs/performance.md)

## 🏆 Project Structure

```
adam_hadoop/
├── ansible/                 # Automated deployment and configuration
│   ├── playbooks/          # Ansible playbooks for cluster setup
│   ├── inventory/          # Environment configurations
│   └── roles/              # Reusable Ansible roles
├── dashboard/               # Streamlit monitoring dashboard  
│   ├── pages/              # Multi-page dashboard components
│   ├── components/         # Reusable UI components
│   ├── utils/              # Dashboard utilities
│   └── app.py              # Main dashboard application
├── data-loader/            # External dataset loading
│   ├── loaders/            # Different data source loaders
│   ├── transformers/       # Data transformation scripts
│   └── validators/         # Data quality validation
├── docs/                   # Comprehensive documentation
│   ├── api/                # API documentation
│   ├── deployment/         # Deployment guides
│   └── troubleshooting/    # Issue resolution guides
├── hadoop-namenode/        # NameNode configuration
│   ├── config/             # Hadoop configuration files
│   └── scripts/            # NameNode-specific scripts
├── hadoop-datanode/        # DataNode configuration
│   ├── config/             # DataNode configurations
│   └── scripts/            # DataNode-specific scripts
├── hive-config/            # Hive warehouse setup
│   ├── schemas/            # Database schemas
│   ├── tables/             # Table definitions
│   └── queries/            # Sample queries
├── monitoring/             # Monitoring and alerting
│   ├── prometheus/         # Prometheus configuration
│   ├── grafana/           # Grafana dashboards
│   └── alerts/            # Alert configurations
├── scraper/                # Real-time web scraping
│   ├── sources/            # Different data source scrapers
│   ├── processors/         # Data processing modules
│   └── config/             # Scraper configurations
├── spark-jobs/             # Spark analytics jobs
│   ├── batch/              # Batch processing jobs
│   ├── streaming/          # Real-time streaming jobs
│   ├── ml/                 # Machine learning pipelines
│   └── utils/              # Common utilities
├── scripts/                # Deployment and management scripts
│   ├── deploy.sh           # Main deployment script
│   ├── backup.sh           # Backup utilities
│   ├── restore.sh          # Restore utilities
│   └── health_check.sh     # Health monitoring
├── tests/                  # Test suites
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── performance/        # Performance tests
├── docker-compose.yml      # Complete service orchestration
├── docker-compose.dev.yml  # Development environment
├── docker-compose.prod.yml # Production environment
├── .env.example            # Environment variables template
├── Makefile               # Build and management commands
└── README.md              # This comprehensive guide
```

## 🎯 Use Cases

This infrastructure supports diverse applications:

### Academic and Research
- **Big data research projects** with distributed computing capabilities
- **Machine learning experiments** with large-scale datasets
- **Data mining studies** on social media and news content
- **Performance benchmarking** of big data technologies
- **Educational demonstrations** of Hadoop ecosystem components

### Business Applications
- **Real-time analytics** for streaming web content and social media
- **Content aggregation** for news and media companies
- **Market sentiment analysis** from social media and news sources
- **Data warehousing** for business intelligence and reporting
- **ETL pipelines** for data integration and transformation

### Technical Applications  
- **Proof of concept** for big data architectures
- **Development platform** for Spark and Hadoop applications
- **Testing environment** for data processing algorithms
- **Integration platform** for AI and ML workflows
- **Monitoring solution** for distributed systems

### Advanced Use Cases
- **Real-time recommendation systems** based on user behavior
- **Fraud detection** using streaming analytics
- **IoT data processing** for sensor data analysis
- **Log analysis** for security and compliance monitoring
- **A/B testing platform** for data-driven decision making

## 🤝 Contributing

We welcome contributions to improve this Hadoop infrastructure:

### Getting Started
1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Set up development environment (`./scripts/setup_dev.sh`)
4. Make your changes with comprehensive tests
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open Pull Request with detailed description

### Contribution Guidelines
- Follow existing code style and conventions
- Add comprehensive tests for new features
- Update documentation for any changes
- Ensure all tests pass before submitting PR
- Include performance impact analysis for major changes

### Areas for Contribution
- Additional data source scrapers
- New Spark analytics jobs
- Dashboard improvements and new visualizations
- Performance optimizations
- Documentation enhancements
- Test coverage improvements
- Security enhancements
- Cloud deployment templates

## 📄 License

This project is part of an academic assignment and is intended for educational purposes. 

**License Terms:**
- Educational use permitted
- Commercial use requires permission
- Attribution required for academic papers
- No warranty provided
- Subject to university academic integrity policies

## 🚀 What's Next?

### Planned Enhancements
- **Multi-machine cluster deployment** with Kubernetes orchestration
- **Elasticsearch integration** for advanced search and analytics capabilities
- **Cloud storage integration** (AWS S3, Azure Blob Storage, Google Cloud Storage)
- **Advanced ML pipelines** with MLflow experiment tracking
- **Real-time alerting system** with Slack/Teams integration
- **Security enhancements** with Kerberos authentication
- **Data governance** with Apache Atlas integration
- **Stream processing** with Apache Flink integration

### Performance Improvements
- **GPU acceleration** for AI workloads
- **Columnar storage** with Apache Parquet optimization
- **Caching layer** with Redis for frequently accessed data
- **Load balancing** for high-availability deployments
- **Auto-scaling** based on workload demands

### Monitoring and Observability
- **Distributed tracing** with Jaeger
- **Advanced metrics** with Prometheus and Grafana
- **Log aggregation** with ELK stack
- **Anomaly detection** in system metrics
- **Capacity planning** tools and forecasting

---

**🎓 Ready to explore big data? Follow the prerequisites above, then deploy your cluster with `./scripts/deploy.sh` and start your data journey! 🚀**

**📧 For questions or issues, please create a GitHub issue with detailed logs and system information.**
