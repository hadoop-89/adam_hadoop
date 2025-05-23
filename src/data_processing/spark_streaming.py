"""
Spark Streaming application for processing data from Kafka.
"""
import os
import json
import logging
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, udf, explode
from pyspark.sql.types import StructType, StructField, StringType, ArrayType, TimestampType
from pyspark.ml.feature import Tokenizer, StopWordsRemover
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("spark_streaming.log")]
)
logger = logging.getLogger("spark_streaming")

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
KAFKA_TOPIC_RAW = os.environ.get('KAFKA_TOPIC_RAW', 'raw-data')
KAFKA_TOPIC_PROCESSED = os.environ.get('KAFKA_TOPIC_PROCESSED', 'processed-data')

# Define schema for incoming Kafka data
schema = StructType([
    StructField("id", StringType(), True),
    StructField("url", StringType(), True),
    StructField("title", StringType(), True),
    StructField("content", StringType(), True),
    StructField("image_urls", ArrayType(StringType()), True),
    StructField("timestamp", StringType(), True)
])

def create_spark_session():
    """Create a Spark session for streaming."""
    return (SparkSession.builder
            .appName("KafkaStreamProcessor")
            .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.0.0")
            .config("spark.streaming.stopGracefullyOnShutdown", True)
            .getOrCreate())

def process_batch(df, epoch_id):
    """Process each batch of data."""
    try:
        if df.isEmpty():
            logger.info(f"Batch {epoch_id}: No data to process")
            return
        
        logger.info(f"Batch {epoch_id}: Processing {df.count()} records")
        
        # Extract data from Kafka
        parsed_df = df.selectExpr("CAST(value AS STRING)") \
            .select(from_json("value", schema).alias("data")) \
            .select("data.*")
        
        # Clean text data
        cleaned_df = parsed_df.withColumn("clean_content", 
                                        udf(clean_text, StringType())("content"))
        
        # Tokenize text
        tokenizer = Tokenizer(inputCol="clean_content", outputCol="tokens")
        tokenized_df = tokenizer.transform(cleaned_df)
        
        # Remove stopwords
        remover = StopWordsRemover(inputCol="tokens", outputCol="filtered_tokens")
        filtered_df = remover.transform(tokenized_df)
        
        # Process images - extract URLs for later processing
        image_df = filtered_df.select("id", explode("image_urls").alias("image_url"))
        
        # Write the processed data back to Kafka
        (filtered_df.selectExpr("to_json(struct(*)) AS value")
         .write
         .format("kafka")
         .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS)
         .option("topic", KAFKA_TOPIC_PROCESSED)
         .save())
        
        # Save image URLs to HDFS for later processing
        now = datetime.now().strftime("%Y%m%d_%H%M%S")
        (image_df
         .write
         .mode("append")
         .parquet(f"hdfs://namenode:9000/data/image_urls/{now}"))
        
        logger.info(f"Batch {epoch_id}: Processing completed")
        
    except Exception as e:
        logger.error(f"Batch {epoch_id}: Error processing batch: {str(e)}")

def clean_text(text):
    """Clean text by removing special characters and extra whitespace."""
    if text is None:
        return ""
    # Remove special characters
    cleaned = ''.join(c if c.isalnum() or c.isspace() else ' ' for c in text)
    # Remove extra whitespace
    cleaned = ' '.join(cleaned.split())
    return cleaned.lower()

def main():
    """Main function to start the Spark Streaming job."""
    spark = create_spark_session()
    
    logger.info("Starting Spark Streaming job")
    
    # Read from Kafka
    df = (spark
          .readStream
          .format("kafka")
          .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS)
          .option("subscribe", KAFKA_TOPIC_RAW)
          .option("startingOffsets", "latest")
          .load())
    
    # Process the stream
    query = (df
             .writeStream
             .foreachBatch(process_batch)
             .outputMode("update")
             .trigger(processingTime="1 minute")
             .start())
    
    try:
        # Keep the job running until manually terminated
        query.awaitTermination()
    except KeyboardInterrupt:
        logger.info("Stopping Spark Streaming job")
    finally:
        spark.stop()
        logger.info("Spark Streaming job stopped")

if __name__ == "__main__":
    main()
