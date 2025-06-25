from datetime import datetime
import requests
import json
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

# Configuration
IA_API_URL = "http://ai-api-unified:8001"  # Nom du conteneur IA
BATCH_SIZE = 10

def send_to_ia_api(data):
    """Envoyer les données à l'API IA"""
    try:
        # Endpoint selon le type de données
        if data.get('type') == 'text':
            endpoint = f"{IA_API_URL}/analyze-text"
        else:
            endpoint = f"{IA_API_URL}/analyze-image"
        
        response = requests.post(
            endpoint,
            json=data,
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"❌ Erreur API: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ Erreur connexion API: {e}")
        return None

def process_hdfs_data():
    """Lire depuis HDFS et envoyer à l'API"""
    spark = SparkSession.builder \
        .appName("HDFStoAPIProcessor") \
        .getOrCreate()
    
    # Lire les données depuis HDFS
    df = spark.read.parquet("hdfs://namenode:9000/data/streaming/news")
    
    # Traiter par batch
    data_collect = df.collect()
    
    results = []
    for i in range(0, len(data_collect), BATCH_SIZE):
        batch = data_collect[i:i+BATCH_SIZE]
        
        for row in batch:
            # Préparer les données
            data = {
                'id': row['id'],
                'type': 'text',
                'content': row['title'],
                'metadata': {
                    'source': row['source'],
                    'timestamp': row['timestamp']
                }
            }
            
            # Envoyer à l'API
            result = send_to_ia_api(data)
            
            if result:
                results.append({
                    'original_id': row['id'],
                    'analysis': result,
                    'processed_at': datetime.now().isoformat()
                })
    
    # Sauvegarder les résultats dans HDFS
    results_df = spark.createDataFrame(results)
    results_df.write \
        .mode("append") \
        .parquet("hdfs://namenode:9000/data/ia_results")
    
    print(f"✅ Traité {len(results)} éléments")

if __name__ == "__main__":
    process_hdfs_data()