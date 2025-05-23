# Projet Hadoop et IA - Composante Hadoop

## Vue d'ensemble
Ce projet implémente un écosystème Hadoop complet pour le traitement de grandes bases de données, incluant l'ingestion de données en temps réel, le prétraitement, et l'intégration avec des APIs d'intelligence artificielle.

## Architecture
```
├── Hadoop Cluster (Docker Compose)
│   ├── NameNode
│   ├── DataNode(s) - Scalable
│   └── Hive Metastore
├── Data Ingestion
│   ├── Web Scraping (Kafka Producer)
│   └── Spark Streaming (Kafka Consumer)
├── Data Preprocessing
│   ├── Text Cleaning & Tokenization
│   └── Image Processing
├── AI API Integration
└── Monitoring & Visualization
```

## Components

### 1. Hadoop Cluster
- Multi-node Hadoop cluster using Docker Compose
- Scalable DataNode architecture
- Integrated Hive for data warehousing

### 2. Data Ingestion
- Real-time web scraping with Kafka
- Spark Streaming for data processing
- Automated data pipeline

### 3. Data Processing
- Text preprocessing and cleaning
- Image conversion to byte arrays
- Data quality validation

### 4. DevOps
- CI/CD pipeline with GitHub Actions
- Ansible automation
- Docker containerization
- Monitoring with Prometheus/Grafana

## Setup Instructions

### Prerequisites
- Docker & Docker Compose
- Python 3.8+
- Ansible (for automation)

### Démarrage rapide
1. Clonez le dépôt: `git clone https://github.com/votre-username/adam_hadoop.git`
2. Installez les dépendances: `pip install -r requirements.txt`
3. Lancez le script de démarrage: `bash start.sh`
4. Vérifiez les services avec les URLs affichées par le script

### Lancement des services individuels
- Pour démarrer uniquement le scraping web: `docker-compose up data-ingestion`
- Pour le traitement Spark: `docker-compose up data-processing`
- Pour l'interaction avec l'API: `docker-compose up api-interaction`
- Pour le tableau de bord: `docker-compose up visualization`

### Accès aux services
- Interface HDFS NameNode: http://localhost:9870
- Interface Hive: http://localhost:10002
- Interface Spark Master: http://localhost:8080
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Tableau de bord: http://localhost:8050

## Project Structure
```
├── docker/                 # Docker configurations
├── ansible/               # Ansible playbooks
├── src/
│   ├── ingestion/         # Data ingestion scripts
│   ├── processing/        # Data processing pipelines
│   ├── api/              # API integration
│   └── visualization/    # Data visualization
├── config/               # Configuration files
├── scripts/              # Utility scripts
└── tests/               # Unit tests
```

## Data Flow
1. Web scraping → Kafka Topics
2. Kafka → Spark Streaming → HDFS/Hive
3. Data preprocessing → Clean datasets
4. API integration → AI model predictions
5. Results storage → Analytics database
6. Visualization → Dashboards

## Monitoring
- Cluster health monitoring
- Data pipeline metrics
- Performance analytics
- Real-time alerts