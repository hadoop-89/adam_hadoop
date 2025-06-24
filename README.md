# 🚀 Projet Hadoop - Cluster & Traitement de Données  

## 📌 Description  
Ce projet met en place un cluster Hadoop sous Docker avec 1 NameNode et 2 DataNodes. Il intègre également un pipeline de chargement de données depuis Kaggle vers HDFS, facilitant ainsi le traitement de données texte et image via Hadoop et Spark.  

## 🏗️ Technologies utilisées  
- **Hadoop 3.2.1** (HDFS)  
- **Docker & Docker-Compose**  
- **Ansible** (automatisation)  
- **Kaggle API** (import de datasets)  
- **Spark / Hive** (traitement des données)  

## 📂 Architecture  
Le cluster est constitué de trois conteneurs Docker :  
- 🖥️ **NameNode** : Gestion du système de fichiers distribué  
- 📦 **DataNode1 & DataNode2** : Stockage et traitement des données  

## 🚀 Installation et Démarrage  

### 1️⃣ Prérequis  
Avant de commencer, assurez-vous d'avoir :
- **WSL2 + Ubuntu** installé sous Windows
- **Docker Desktop** configuré avec WSL
- **Kaggle CLI** installé (`pip install kaggle`)
- Des identifiants Kaggle disponibles via un fichier `~/.kaggle/kaggle.json` ou
  les variables d'environnement `KAGGLE_USERNAME` et `KAGGLE_KEY`

### 2️⃣ Démarrer le cluster Hadoop  
```bash  
docker-compose up -d  
```  
Cela lance les conteneurs Hadoop en arrière-plan.  

### 3️⃣ Vérifier l'état du cluster  
```bash  
docker ps  
```  
Vous devriez voir `namenode`, `datanode1` et `datanode2` en cours d'exécution.  

### 4️⃣ Charger les bases de données Kaggle
Assurez-vous que vos identifiants Kaggle sont disponibles (fichier `kaggle.json`
monté dans le conteneur ou variables `KAGGLE_USERNAME` et `KAGGLE_KEY`).
Lancer ensuite le script d'importation :
```bash  
chmod +x load_db_kaggle.sh  
./load_db_kaggle.sh  
```  
Cela va :  
✔️ Télécharger les datasets (textes et images) depuis Kaggle  
✔️ Extraire et stocker les fichiers en local  
✔️ Copier les données dans HDFS  

## 🔍 Accès aux interfaces  
- **Interface HDFS NameNode** : [localhost:9870](http://localhost:9870)  
- **Spark UI (si activé)** : [localhost:8080](http://localhost:8080)  
- **Hive Metastore (si configuré)** : Port 10000  

## 📌 Prochaines Étapes  
✔️ Intégration Spark/Hive pour l’analyse des données  
✔️ Mise en place d’un flux Kafka pour ingestion temps réel  
✔️ Ajout d’une API Flask pour traitement IA avec YOLO  

## 🛠️ Développement  
Clonez le projet et modifiez `docker-compose.yml` ou `load_db_kaggle.sh` pour adapter le cluster et les datasets.  
```bash  
git clone https://github.com/votre-repo/projet-hadoop.git  
cd projet-hadoop  
```  
