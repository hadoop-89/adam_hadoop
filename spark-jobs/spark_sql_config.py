from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

def create_spark_session():
    """Créer une session Spark optimisée pour HDFS et analytics"""
    spark = SparkSession.builder         .appName("HadoopAnalytics")         .config("spark.sql.adaptive.enabled", "true")         .config("spark.sql.adaptive.coalescePartitions.enabled", "true")         .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")         .config("spark.sql.warehouse.dir", "hdfs://namenode:9000/user/hive/warehouse")         .config("spark.sql.catalogImplementation", "in-memory")         .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")         .getOrCreate()
    
    return spark

def load_existing_data(spark):
    """Charger les bases de données existantes"""
    try:
        # Charger les données texte existantes
        reviews_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/text/existing/")
        reviews_df.createOrReplaceTempView("existing_reviews")
        
        # Charger les données images existantes
        images_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/images/existing/")
        images_df.createOrReplaceTempView("existing_images")
        
        return reviews_df, images_df
    except Exception as e:
        print(f"Erreur lors du chargement: {e}")
        return None, None

def load_scraped_data(spark):
    """Charger les données scrapées"""
    try:
        # Charger les données texte scrapées
        scraped_reviews_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/text/scraped/")
        scraped_reviews_df.createOrReplaceTempView("scraped_reviews")
        
        # Charger les données images scrapées
        scraped_images_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/images/scraped/")
        scraped_images_df.createOrReplaceTempView("scraped_images")
        
        return scraped_reviews_df, scraped_images_df
    except Exception as e:
        print(f"Erreur lors du chargement scraped: {e}")
        return None, None

def create_unified_views(spark):
    """Créer des vues unifiées combinant données existantes et scrapées"""
    try:
        # Vue unifiée des reviews
        spark.sql("""
            CREATE OR REPLACE TEMPORARY VIEW all_reviews AS
            SELECT 
                review_id,
                review_text,
                rating,
                timestamp,
                source,
                COALESCE(product_category, 'unknown') as category,
                'existing' as data_source
            FROM existing_reviews
            
            UNION ALL
            
            SELECT 
                review_id,
                review_text,
                rating,
                timestamp,
                source,
                COALESCE(product_category, 'unknown') as category,
                'scraped' as data_source
            FROM scraped_reviews
        """)
        
        # Vue unifiée des images
        spark.sql("""
            CREATE OR REPLACE TEMPORARY VIEW all_images AS
            SELECT 
                image_id,
                filename,
                category,
                timestamp,
                source,
                size_kb,
                'existing' as data_source
            FROM existing_images
            
            UNION ALL
            
            SELECT 
                image_id,
                filename,
                category,
                timestamp,
                source,
                size_kb,
                'scraped' as data_source
            FROM scraped_images
        """)
        
        print("✅ Vues unifiées créées avec succès")
        return True
    except Exception as e:
        print(f"Erreur lors de la création des vues: {e}")
        return False

if __name__ == "__main__":
    spark = create_spark_session()
    
    # Charger les données
    reviews_df, images_df = load_existing_data(spark)
    scraped_reviews_df, scraped_images_df = load_scraped_data(spark)
    
    # Créer les vues unifiées
    create_unified_views(spark)
    
    print("✅ Configuration Spark SQL terminée")
    
    # Garder la session ouverte
    spark.sparkContext.setLogLevel("WARN")
