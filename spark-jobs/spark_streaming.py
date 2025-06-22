from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Créer la session Spark
spark = SparkSession.builder \
    .appName("NewsStreamProcessor") \
    .config("spark.sql.adaptive.enabled", "false") \
    .getOrCreate()

print("✅ Spark session créée avec succès!")

# Test simple : créer des données de test
data = [
    ("1", "Breaking: New AI Technology Revolutionizes Healthcare", "https://example.com/1", "2025-06-22T18:46:00", "hackernews"),
    ("2", "Python 3.12 Released with Amazing Features!", "https://example.com/2", "2025-06-22T18:47:00", "hackernews"),
    ("3", "Docker Containers vs Virtual Machines: Performance Comparison", "https://example.com/3", "2025-06-22T18:48:00", "hackernews")
]

schema = StructType([
    StructField("id", StringType()),
    StructField("title", StringType()),
    StructField("url", StringType()),
    StructField("timestamp", StringType()),
    StructField("source", StringType())
])

# Créer un DataFrame de test
df = spark.createDataFrame(data, schema)

print("📄 Données de test créées:")
df.show(truncate=False)

# Prétraitement simple
processed_df = df \
    .withColumn("title_length", length(col("title"))) \
    .withColumn("word_count", size(split(col("title"), " "))) \
    .withColumn("title_cleaned", 
        regexp_replace(
            regexp_replace(col("title"), "http\\S+", ""),  # Enlever URLs
            "[^a-zA-Z0-9\\s]", " "  # Enlever caractères spéciaux
        )
    ) \
    .withColumn("title_cleaned", regexp_replace(col("title_cleaned"), "\\s+", " ")) \
    .withColumn("processed_time", current_timestamp())

print("🔧 Données après prétraitement:")
processed_df.show(truncate=False)

# Test sauvegarde HDFS
try:
    processed_df.write \
        .mode("overwrite") \
        .parquet("hdfs://namenode:9000/data/test/news_sample")
    print("✅ Sauvegarde HDFS réussie!")
except Exception as e:
    print(f"❌ Erreur HDFS: {e}")

# Arrêter Spark
spark.stop()
print("🛑 Test terminé")