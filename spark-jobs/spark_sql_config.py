from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

def create_spark_session():
    """Create a Spark session optimized for HDFS and analytics"""
    spark = SparkSession.builder         .appName("HadoopAnalytics")         .config("spark.sql.adaptive.enabled", "true")         .config("spark.sql.adaptive.coalescePartitions.enabled", "true")         .config("spark.hadoop.fs.defaultFS", "hdfs://namenode:9000")         .config("spark.sql.warehouse.dir", "hdfs://namenode:9000/user/hive/warehouse")         .config("spark.sql.catalogImplementation", "in-memory")         .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")         .getOrCreate()
    
    return spark

def load_existing_data(spark):
    """Load existing datasets"""
    try:
        # Load existing text data
        reviews_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/text/existing/")
        reviews_df.createOrReplaceTempView("existing_reviews")

        # Load existing image data
        images_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/images/existing/")
        images_df.createOrReplaceTempView("existing_images")
        
        return reviews_df, images_df
    except Exception as e:
        print(f"Error loading existing data: {e}")
        return None, None

def load_scraped_data(spark):
    """Load scraped data"""
    try:
        # Load scraped text data
        scraped_reviews_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/text/scraped/")
        scraped_reviews_df.createOrReplaceTempView("scraped_reviews")

        # Load scraped image data
        scraped_images_df = spark.read.option("header", "true").csv("hdfs://namenode:9000/data/images/scraped/")
        scraped_images_df.createOrReplaceTempView("scraped_images")
        
        return scraped_reviews_df, scraped_images_df
    except Exception as e:
        print(f"Error loading scraped data: {e}")
        return None, None

def create_unified_views(spark):
    """Create unified views combining existing and scraped data"""
    try:
        # Unified view of reviews
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

        # Unified view of images
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
        
        print("✅ Unified views created successfully")
        return True
    except Exception as e:
        print(f"Error creating views: {e}")
        return False

if __name__ == "__main__":
    spark = create_spark_session()

    # Load data
    reviews_df, images_df = load_existing_data(spark)
    scraped_reviews_df, scraped_images_df = load_scraped_data(spark)

    # Create unified views
    create_unified_views(spark)

    print("✅ Spark SQL configuration complete")

    # Keep the session open
    spark.sparkContext.setLogLevel("WARN")
