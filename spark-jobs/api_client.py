from datetime import datetime
import requests
import json
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

# Configuration
IA_API_URL = "http://ai-api-unified:8001"  # AI Container Name
BATCH_SIZE = 10

def send_to_ia_api(data):
    """Send data to the AI API"""
    try:
        # Endpoint based on data type
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
            print(f"❌ API error: {response.status_code}")
            return None
            
    except Exception as e:
        print(f"❌ API connection error: {e}")
        return None

def process_hdfs_data():
    """Read from HDFS and send to the API"""
    spark = SparkSession.builder \
        .appName("HDFStoAPIProcessor") \
        .getOrCreate()

    # Read data from HDFS
    df = spark.read.parquet("hdfs://namenode:9000/data/streaming/news")

    # Process in batches
    data_collect = df.collect()
    
    results = []
    for i in range(0, len(data_collect), BATCH_SIZE):
        batch = data_collect[i:i+BATCH_SIZE]
        
        for row in batch:
            # Prepare data
            data = {
                'id': row['id'],
                'type': 'text',
                'content': row['title'],
                'metadata': {
                    'source': row['source'],
                    'timestamp': row['timestamp']
                }
            }

            # Send to API
            result = send_to_ia_api(data)
            
            if result:
                results.append({
                    'original_id': row['id'],
                    'analysis': result,
                    'processed_at': datetime.now().isoformat()
                })

    # Save results to HDFS
    results_df = spark.createDataFrame(results)
    results_df.write \
        .mode("append") \
        .parquet("hdfs://namenode:9000/data/ia_results")

    print(f"✅ Processed {len(results)} items and saved to HDFS.")

if __name__ == "__main__":
    process_hdfs_data()