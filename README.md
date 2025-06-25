# 🚀 Hadoop Big Data Infrastructure

**Complete Hadoop cluster with real-time web scraping, data processing, and AI integration**

This repository contains the Hadoop infrastructure component of our **Hadoop & AI Project**, designed to handle big data processing, real-time web scraping, and seamless integration with AI services.

## 📋 Overview

This project implements a production-ready Hadoop ecosystem that includes:

- **Multi-node Hadoop cluster** (1 NameNode + 2 DataNodes)
- **Real-time web scraping** with Kafka streaming
- **Spark processing** for data analytics
- **Hive data warehouse** for structured queries
- **Streamlit dashboard** for real-time monitoring
- **AI API integration** for machine learning workflows

## 🏗️ Architecture

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

## ⚡ Quick Start

### Prerequisites

- Docker Desktop (with WSL2 on Windows)
- 8GB+ RAM recommended
- 20GB+ free disk space

### 1. Clone and Deploy

```bash
git clone https://github.com/hadoop-89/hadoop-cluster.git
cd hadoop-cluster

# Deploy complete cluster
./scripts/deploy.sh
```

### 2. Verify Deployment

```bash
# Check cluster health
./scripts/deploy.sh --status

# View all services
docker ps
```

### 3. Access Web Interfaces

- **NameNode UI**: http://localhost:9870
- **Spark Master**: http://localhost:8080  
- **Streamlit Dashboard**: http://localhost:8501
- **DataNode1**: http://localhost:9864
- **DataNode2**: http://localhost:9865

## 🌐 Real-Time Web Scraping

The scraper continuously collects data from multiple sources:

**Text Sources:**
- HackerNews RSS feeds
- Reddit Technology posts
- BBC Technology news
- TechCrunch articles
- Reuters Technology

**Image Sources:**
- Reddit image subreddits
- Metadata extraction and categorization

**Data Flow:**
```
Web Sources → Scraper → Kafka → Spark Streaming → HDFS → Hive → Dashboard
```

## 📊 Data Processing

### HDFS Structure
```
/data/
├── text/
│   ├── existing/     # Pre-loaded datasets (Amazon reviews)
│   └── scraped/      # Real-time scraped articles
├── images/
│   ├── existing/     # Pre-loaded image metadata
│   └── scraped/      # Scraped image metadata
├── streaming/        # Real-time Kafka data
├── processed/        # Spark processed data
└── ia_results/       # AI analysis results
```

### Spark Analytics

```bash
# Run analytics on collected data
docker exec spark-master python /opt/spark-jobs/demo_analytics.py

# Test Hadoop ↔ AI integration
docker exec spark-master python /opt/spark-jobs/test_hadoop_ia_integration.py
```

### Hive Queries

```bash
# Connect to Hive
docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000

# Example queries
USE analytics;
SELECT source, COUNT(*) FROM reviews GROUP BY source;
SELECT category, AVG(rating) FROM reviews GROUP BY category;
```

## 🤖 AI Integration

This Hadoop cluster is designed to work with the companion **AI API repository**:

```bash
# Test AI connectivity
curl http://localhost:8001/health

# Send data to AI for analysis
python spark-jobs/api_client.py
```

The AI integration enables:
- **Sentiment analysis** of scraped text data
- **Image classification** of collected images
- **Real-time ML inference** on streaming data
- **Batch processing** for large datasets

## 📈 Monitoring & Dashboard

The Streamlit dashboard provides real-time insights:

- **HDFS data statistics** and health metrics
- **Real-time scraping activity** with live updates
- **Kafka topic monitoring** and message counts
- **Cluster health status** for all services
- **Performance metrics** and resource usage

Features:
- Auto-refresh capabilities
- Interactive data exploration
- Real-time scraped articles display
- Image metadata visualization

## 🛠️ Configuration

### Scaling DataNodes

Modify `docker-compose.yml` to add more DataNodes:

```yaml
datanode3:
  build:
    context: ./hadoop-datanode
  container_name: datanode3
  ports:
    - "9866:9864"
  # ... rest of configuration
```

### Scraper Configuration

Adjust scraping intervals in `scraper/real_scraper.py`:

```python
# Environment variables
SCRAPE_INTERVAL = int(os.getenv('SCRAPE_INTERVAL', 300))  # 5 minutes default
```

### Kafka Topics

```bash
# List current topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Create new topic
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic new-topic
```

## 🔧 Advanced Operations

### Cluster Management

```bash
# Clean restart
./scripts/deploy.sh --clean

# Fresh deployment (removes all data)
./scripts/deploy.sh --fresh

# Debug mode
./scripts/deploy.sh --debug

# Ordered deployment for troubleshooting
./scripts/deploy.sh --ordered
```

### Data Loading

```bash
# Load external datasets
docker-compose run --rm data-loader

# Manual HDFS operations
docker exec namenode hdfs dfs -put /local/file /hdfs/path
docker exec namenode hdfs dfs -ls /data
```

### Backup and Recovery

```bash
# Backup HDFS data
docker exec namenode hdfs dfs -get /data /backup/location

# Export cluster configuration
docker-compose config > cluster-backup.yml
```

## 🚨 Troubleshooting

### Common Issues

**NameNode not starting:**
```bash
# Check logs
docker logs namenode

# Restart with clean slate
./scripts/deploy.sh --fresh
```

**DataNodes not connecting:**
```bash
# Verify network connectivity
docker exec namenode hdfs dfsadmin -report

# Check DataNode logs
docker logs datanode1
docker logs datanode2
```

**Kafka connectivity issues:**
```bash
# Test Kafka broker
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Restart Kafka services
docker-compose restart zookeeper kafka
```

### Health Checks

```bash
# Complete cluster health
./scripts/deploy.sh --status

# Individual service health
curl http://localhost:9870  # NameNode
curl http://localhost:8501  # Dashboard
curl http://localhost:8080  # Spark
```

## 📊 Performance Tuning

### Resource Allocation

Adjust memory settings in `docker-compose.yml`:

```yaml
spark-master:
  environment:
    - SPARK_WORKER_MEMORY=2G
    - SPARK_WORKER_CORES=2
```

### HDFS Configuration

Modify replication factor in `hadoop-namenode/hdfs-site.xml`:

```xml
<property>
    <name>dfs.replication</name>
    <value>2</value>  <!-- Adjust based on DataNode count -->
</property>
```

## 🔗 Integration Points

This Hadoop cluster integrates with:

- **AI API Repository**: For ML inference and analysis
- **External data sources**: Via web scraping
- **Analytics tools**: Through Hive and Spark interfaces
- **Monitoring systems**: Via REST APIs and dashboards

## 📚 Documentation

- [Hadoop Official Documentation](https://hadoop.apache.org/docs/)
- [Spark Programming Guide](https://spark.apache.org/docs/latest/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Hive User Guide](https://cwiki.apache.org/confluence/display/Hive/Home)

## 🏆 Project Structure

```
hadoop-cluster/
├── ansible/                 # Automated deployment
├── dashboard/               # Streamlit monitoring dashboard  
├── data-loader/            # External dataset loading
├── hadoop-namenode/        # NameNode configuration
├── hadoop-datanode/        # DataNode configuration
├── hive-config/            # Hive warehouse setup
├── scraper/                # Real-time web scraping
├── spark-jobs/             # Spark analytics jobs
├── scripts/                # Deployment and management scripts
├── docker-compose.yml      # Complete service orchestration
└── README.md              # This file
```

## 🎯 Use Cases

This infrastructure supports:

- **Real-time data analytics** for streaming web content
- **Machine learning pipelines** with AI integration
- **Data warehousing** for business intelligence
- **Research projects** requiring big data processing
- **Educational purposes** for learning Hadoop ecosystem

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is part of an academic assignment and is intended for educational purposes.

## 🚀 What's Next?

- Scale to multi-machine cluster deployment
- Add Elasticsearch for advanced search capabilities
- Integrate with cloud storage (S3, Azure Blob)
- Implement advanced ML pipelines
- Add real-time alerting and monitoring

---

**Ready to process big data? Deploy your cluster with `./scripts/deploy.sh` and start exploring! 🚀**