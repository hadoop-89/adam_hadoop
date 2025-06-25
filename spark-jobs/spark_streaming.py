#!/usr/bin/env python3
"""
Real Spark + HDFS test with built-in preprocessing
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import re

def main():
    print("🚀 === SPARK TEST + HDFS + PREPROCESSING ===")
    
    try:
        # Create Spark session with HDFS configuration
        spark = SparkSession.builder \
            .appName("TestSparkHDFS") \
            .config("spark.sql.adaptive.enabled", "false") \
            .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000") \
            .getOrCreate()

        print("✅ Spark session created with HDFS connection")

        # Test data (simulating scraped articles)
        test_data = [
            ("1", "Breaking: New AI Technology Revolutionizes Healthcare https://example.com", "2025-06-22T20:00:00", "hackernews"),
            ("2", "Python 3.12 Released with Amazing Features!", "2025-06-22T20:01:00", "techcrunch"),
            ("3", "Docker vs Kubernetes: Performance Comparison 2025", "2025-06-22T20:02:00", "medium"),
            ("4", "Machine Learning in Production: Best Practices", "2025-06-22T20:03:00", "hackernews"),
            ("5", "Climate Change Data Analysis with Big Data Tools", "2025-06-22T20:04:00", "nature")
        ]
        
        schema = StructType([
            StructField("id", StringType()),
            StructField("title", StringType()),
            StructField("timestamp", StringType()),
            StructField("source", StringType())
        ])
        
        # Create DataFrame
        df = spark.createDataFrame(test_data, schema)
        print(f"✅ DataFrame created with {df.count()} articles")
        
        # === ADVANCED PREPROCESSING ===
        print("🔧 Applying preprocessing...")
        
        # UDF for text cleaning
        def clean_text_udf():
            def clean_text(text):
                if not text:
                    return ""
                # Remove URLs
                text = re.sub(r'http\S+|www\.\S+', '', text)
                # Remove special characters
                text = re.sub(r'[^\w\s]', ' ', text)
                # Remove multiple spaces
                text = ' '.join(text.split())
                return text.lower().strip()
            return udf(clean_text, StringType())
        
        clean_text_func = clean_text_udf()

        # Apply preprocessing
        processed_df = df \
            .withColumn("title_original", col("title")) \
            .withColumn("title_cleaned", clean_text_func(col("title"))) \
            .withColumn("word_count", size(split(col("title_cleaned"), " "))) \
            .withColumn("title_length", length(col("title_original"))) \
            .withColumn("processed_time", current_timestamp()) \
            .withColumn("data_type", lit("text")) \
            .withColumn("ready_for_ia", when(col("word_count") >= 3, True).otherwise(False)) \
            .filter(col("ready_for_ia") == True)

        print("✅ Preprocessing applied")

        # Show results
        print("\n📊 === SPARK RESULTS ===")
        processed_df.select("id", "title_original", "title_cleaned", "word_count", "ready_for_ia").show(truncate=False)

        # === HDFS SAVE TEST ===
        print("💾 HDFS save test...")

        # Save preprocessed data
        processed_df.write \
            .mode("overwrite") \
            .parquet("hdfs://namenode:9000/data/test/news_preprocessed")

        print("✅ HDFS save successful!")

        # Prepare data for AI API
        api_ready_df = processed_df.select(
            col("id"),
            col("data_type"),
            col("title_cleaned").alias("content"),
            struct(
                col("source"),
                col("title_original"),
                col("word_count"),
                col("processed_time")
            ).alias("metadata")
        )

        # Save API queue
        api_ready_df.write \
            .mode("overwrite") \
            .parquet("hdfs://namenode:9000/data/test/api_queue")

        print("✅ AI API queue created!")

        # === HDFS READ TEST ===
        print("🔍 HDFS read test...")
       
        read_df = spark.read.parquet("hdfs://namenode:9000/data/test/news_preprocessed")
        read_count = read_df.count()

        print(f"✅ HDFS read OK - {read_count} articles retrieved")

        # === STATISTICS ===
        stats = processed_df.agg(
            count("*").alias("total"),
            avg("word_count").alias("avg_words"),
            max("word_count").alias("max_words"),
            countDistinct("source").alias("sources")
        ).collect()[0]

        print(f"\n📈 === FINAL STATISTICS ===")
        print(f"Total articles traités: {stats['total']}")
        print(f"Longueur moyenne: {stats['avg_words']:.1f} mots")
        print(f"Longueur maximale: {stats['max_words']} mots") 
        print(f"Sources différentes: {stats['sources']}")
        
        spark.stop()

        print("\n🎉 === ALL TESTS PASSED ===")
        print("✅ Spark is working")
        print("✅ HDFS connected")
        print("✅ Preprocessing integrated")
        print("✅ Save/read HDFS")
        print("✅ Data ready for AI API")

        return True
        
    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)