from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import sys
import os

# Add the path to import the configuration
sys.path.append('/opt/spark-jobs')
from spark_sql_config import create_spark_session, load_existing_data, load_scraped_data, create_unified_views

def run_analytics_demo():
    """Complete demonstration of analytics with Spark SQL"""
    print("🚀 === SPARK SQL ANALYTICS DEMO ===")

    # Create Spark session
    spark = create_spark_session()
    
    try:
        # Load data
        print("📊 Loading data...")
        reviews_df, images_df = load_existing_data(spark)
        scraped_reviews_df, scraped_images_df = load_scraped_data(spark)

        # Create unified views
        create_unified_views(spark)
        
        print("\n📈 === ANALYTICS BUSINESS ===")

        # Analytics 1: Distribution by source
        print("\n🏪 1. Distribution of reviews by source:")
        spark.sql("""
            SELECT 
                source,
                COUNT(*) as total_reviews,
                ROUND(AVG(CAST(rating as DOUBLE)), 2) as avg_rating,
                SUM(CASE WHEN CAST(rating as INT) >= 4 THEN 1 ELSE 0 END) as positive_reviews,
                data_source
            FROM all_reviews 
            GROUP BY source, data_source
            ORDER BY total_reviews DESC
        """).show()

        # Analytics 2: Temporal analysis
        print("\n📅 2. Temporal analysis of reviews:")
        spark.sql("""
            SELECT 
                DATE(timestamp) as date,
                COUNT(*) as daily_reviews,
                ROUND(AVG(CAST(rating as DOUBLE)), 2) as daily_avg_rating,
                data_source
            FROM all_reviews 
            GROUP BY DATE(timestamp), data_source
            ORDER BY date DESC
        """).show()

        # Analytics 3: Satisfaction analysis
        print("\n⭐ 3. Satisfaction analysis:")
        spark.sql("""
            SELECT 
                CASE 
                    WHEN CAST(rating as INT) >= 4 THEN 'Satisfied'
                    WHEN CAST(rating as INT) = 3 THEN 'Neutral'
                    ELSE 'Unsatisfied'
                END as satisfaction_level,
                COUNT(*) as count,
                ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM all_reviews), 1) as percentage
            FROM all_reviews
            GROUP BY 
                CASE 
                    WHEN CAST(rating as INT) >= 4 THEN 'Satisfied'
                    WHEN CAST(rating as INT) = 3 THEN 'Neutral'
                    ELSE 'Unsatisfied'
                END
            ORDER BY count DESC
        """).show()

        # Analytics 4: Image category analysis
        print("\n🖼️ 4. Distribution of image categories:")
        spark.sql("""
            SELECT 
                category,
                COUNT(*) as image_count,
                ROUND(AVG(size_kb), 2) as avg_size_kb,
                data_source
            FROM all_images
            GROUP BY category, data_source
            ORDER BY image_count DESC
        """).show()

        # Analytics 5: Comparison of existing vs scraped data
        print("\n🔄 5. Comparison of existing vs scraped data:")
        spark.sql("""
            SELECT 
                data_source,
                COUNT(*) as total_reviews,
                ROUND(AVG(CAST(rating as DOUBLE)), 2) as avg_rating,
                MIN(timestamp) as earliest_review,
                MAX(timestamp) as latest_review
            FROM all_reviews
            GROUP BY data_source
        """).show()

        # Analytics 6: Top sources by performance
        print("\n🎯 6. Performance by source (all data):")
        spark.sql("""
            SELECT 
                source,
                COUNT(*) as total_reviews,
                ROUND(AVG(CAST(rating as DOUBLE)), 2) as avg_rating,
                ROUND(100.0 * SUM(CASE WHEN CAST(rating as INT) >= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) as satisfaction_rate,
                COUNT(DISTINCT category) as categories_count
            FROM all_reviews
            GROUP BY source
            ORDER BY satisfaction_rate DESC, total_reviews DESC
        """).show()

        # Save analytics results
        print("\n💾 Saving analytics results...")

        # Create a summary of the analytics
        summary_df = spark.sql("""
            SELECT 
                'total_reviews' as metric,
                CAST(COUNT(*) as STRING) as value
            FROM all_reviews
            
            UNION ALL
            
            SELECT 
                'avg_rating' as metric,
                CAST(ROUND(AVG(CAST(rating as DOUBLE)), 2) as STRING) as value
            FROM all_reviews
            
            UNION ALL
            
            SELECT 
                'unique_sources' as metric,
                CAST(COUNT(DISTINCT source) as STRING) as value
            FROM all_reviews
            
            UNION ALL
            
            SELECT 
                'total_images' as metric,
                CAST(COUNT(*) as STRING) as value
            FROM all_images
        """)
        
        # Save to HDFS
        summary_df.write.mode("overwrite").csv("hdfs://namenode:9000/data/analytics_summary")
        
        print("\n✅ === DEMONSTRATION COMPLETE ===")
        print("🎯 Spark SQL configured and functional")
        print("📊 Analytics saved to HDFS")
        print("🚀 Ready for the presentation!")
        
    except Exception as e:
        print(f"❌ Error during demonstration: {e}")
        import traceback
        traceback.print_exc()
    finally:
        spark.stop()

if __name__ == "__main__":
    run_analytics_demo()
