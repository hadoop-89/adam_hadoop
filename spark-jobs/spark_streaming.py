from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import json

# Créer la session Spark
spark = SparkSession.builder \
    .appName("NewsStreamProcessor") \
    .config("spark.sql.adaptive.enabled", "false") \
    .getOrCreate()

# Schéma des données
schema = StructType([
    StructField("id", StringType()),
    StructField("title", StringType()),
    StructField("url", StringType()),
    StructField("timestamp", StringType()),
    StructField("source", StringType())
])

# Lire depuis Kafka
df = spark \
    .readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "kafka:9092") \
    .option("subscribe", "news-topic") \
    .option("startingOffsets", "latest") \
    .load()

# Parser les données JSON
parsed_df = df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

# Prétraitement simple
processed_df = parsed_df \
    .withColumn("title_length", length(col("title"))) \
    .withColumn("word_count", size(split(col("title"), " "))) \
    .withColumn("processed_time", current_timestamp())

# Sauvegarder dans HDFS
query = processed_df \
    .writeStream \
    .outputMode("append") \
    .format("parquet") \
    .option("path", "hdfs://namenode:9000/data/streaming/news") \
    .option("checkpointLocation", "hdfs://namenode:9000/checkpoints/news") \
    .trigger(processingTime='30 seconds') \
    .start()

# Afficher en console pour debug
console_query = processed_df \
    .writeStream \
    .outputMode("append") \
    .format("console") \
    .trigger(processingTime='10 seconds') \
    .start()

# Attendre la fin
query.awaitTermination()