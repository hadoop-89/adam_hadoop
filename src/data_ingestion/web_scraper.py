"""
Script for web scraping and ingesting data into Kafka.
"""
import time
import json
import logging
from datetime import datetime
from kafka import KafkaProducer
from bs4 import BeautifulSoup
import requests
import hashlib
import os
import sys

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("data_scraper.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("data_scraper")

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
KAFKA_TOPIC_RAW = os.environ.get('KAFKA_TOPIC_RAW', 'raw-data')

class WebScraper:
    def __init__(self, urls):
        """Initialize the web scraper with a list of URLs to scrape."""
        self.urls = urls
        self.producer = self._create_kafka_producer()
        
    def _create_kafka_producer(self):
        """Create a Kafka producer instance."""
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                retries=5
            )
            return producer
        except Exception as e:
            logger.error(f"Failed to create Kafka producer: {str(e)}")
            raise

    def scrape_url(self, url):
        """Scrape content from a URL."""
        try:
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            
            # Create BeautifulSoup object
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # Extract title
            title = soup.title.text if soup.title else "No title"
            
            # Extract main text content
            paragraphs = soup.find_all('p')
            text_content = ' '.join([p.text for p in paragraphs])
            
            # Extract image URLs
            images = soup.find_all('img')
            image_urls = [img.get('src', '') for img in images if img.get('src', '')]
            
            # Create a document ID based on URL
            doc_id = hashlib.md5(url.encode()).hexdigest()
            
            # Create document
            document = {
                'id': doc_id,
                'url': url,
                'title': title,
                'content': text_content,
                'image_urls': image_urls,
                'timestamp': datetime.now().isoformat()
            }
            
            return document
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error scraping URL {url}: {str(e)}")
            return None

    def process_and_send(self, document):
        """Process scraped document and send to Kafka."""
        if not document:
            return False
        
        try:
            # Send document to Kafka
            future = self.producer.send(
                KAFKA_TOPIC_RAW,
                key=document['id'].encode('utf-8'),
                value=document
            )
            # Block until a single message is sent (or timeout)
            record_metadata = future.get(timeout=10)
            logger.info(f"Sent document to Kafka: {document['id']}, "
                        f"topic: {record_metadata.topic}, "
                        f"partition: {record_metadata.partition}, "
                        f"offset: {record_metadata.offset}")
            return True
        except Exception as e:
            logger.error(f"Error sending document to Kafka: {str(e)}")
            return False

    def run_scraper(self, interval=60):
        """Run the scraper continuously with a specified interval between runs."""
        logger.info("Starting web scraper...")
        while True:
            try:
                for url in self.urls:
                    document = self.scrape_url(url)
                    if document:
                        self.process_and_send(document)
                
                logger.info(f"Completed scraping cycle. Sleeping for {interval} seconds.")
                time.sleep(interval)
            except KeyboardInterrupt:
                logger.info("Stopping the scraper...")
                break
            except Exception as e:
                logger.error(f"Error in scraping cycle: {str(e)}")
                time.sleep(interval)

    def close(self):
        """Close the Kafka producer."""
        if self.producer:
            self.producer.close()
            logger.info("Kafka producer closed")

if __name__ == "__main__":
    # URLs to scrape - utilisation de sites Web publics pour les tests
    urls_to_scrape = [
        "https://en.wikipedia.org/wiki/Apache_Hadoop",
        "https://en.wikipedia.org/wiki/Apache_Kafka",
        "https://en.wikipedia.org/wiki/Apache_Spark"
    ]
    
    logger.info("Démarrage du Web Scraper avec les URLs suivantes:")
    for url in urls_to_scrape:
        logger.info(f"  - {url}")
    
    scraper = WebScraper(urls_to_scrape)
    
    try:
        logger.info("Scraping démarré. Appuyez sur Ctrl+C pour arrêter.")
        scraper.run_scraper(interval=60)  # Scrape every minute
    except KeyboardInterrupt:
        logger.info("Scraper interrupted by user")
    finally:
        scraper.close()
