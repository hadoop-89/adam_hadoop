"""
Initialize HBase tables required for the visualization dashboard.
"""
import os
import logging
import happybase

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("init_hbase.log")]
)
logger = logging.getLogger("init_hbase")

# Configuration
HBASE_HOST = os.environ.get('HBASE_HOST', 'hbase')
HBASE_PORT = int(os.environ.get('HBASE_PORT', 9090))

def init_hbase_tables():
    """Initialize HBase tables for visualization."""
    try:
        # Connect to HBase
        connection = happybase.Connection(HBASE_HOST, HBASE_PORT)
        logger.info("Connected to HBase")
        
        # Get list of existing tables
        tables = connection.tables()
        tables = [t.decode('utf-8') for t in tables]
        logger.info(f"Existing tables: {tables}")
        
        # Create text_results table if it doesn't exist
        if 'text_results' not in tables:
            logger.info("Creating 'text_results' table")
            connection.create_table(
                'text_results',
                {
                    'metadata': dict(),  # Document metadata
                    'classification': dict(),  # Classification results
                    'summary': dict(),  # Summary results
                    'sentiment': dict()  # Sentiment results
                }
            )
        else:
            logger.info("'text_results' table already exists")
        
        # Create image_results table if it doesn't exist
        if 'image_results' not in tables:
            logger.info("Creating 'image_results' table")
            connection.create_table(
                'image_results',
                {
                    'metadata': dict(),  # Image metadata
                    'detection': dict(),  # Object detection results
                }
            )
        else:
            logger.info("'image_results' table already exists")
        
        # Add some sample data for testing
        try:
            text_table = connection.table('text_results')
            text_table.put(
                b'sample_text_1', 
                {
                    b'metadata:url': b'https://en.wikipedia.org/wiki/Hadoop',
                    b'metadata:title': b'Apache Hadoop',
                    b'metadata:timestamp': b'2025-05-23T10:00:00Z',
                    b'summary:text': b'Apache Hadoop is an open-source software framework for distributed storage and processing of datasets.',
                    b'classification:category': b'Technology',
                    b'sentiment:score': b'0.75'
                }
            )
            
            image_table = connection.table('image_results')
            image_table.put(
                b'sample_image_1',
                {
                    b'metadata:url': b'https://upload.wikimedia.org/wikipedia/commons/0/0e/Hadoop_logo.svg',
                    b'metadata:timestamp': b'2025-05-23T10:05:00Z',
                    b'detection:objects': b'["logo", "text"]'
                }
            )
            
            logger.info("Added sample data for testing")
        except Exception as e:
            logger.error(f"Failed to add sample data: {str(e)}")
        
        # Close connection
        connection.close()
        logger.info("HBase tables initialized successfully")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize HBase tables: {str(e)}")
        return False

if __name__ == "__main__":
    init_hbase_tables()
