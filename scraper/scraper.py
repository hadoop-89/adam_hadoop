import requests
import json
import time
from kafka import KafkaProducer
from datetime import datetime
import feedparser

# Configuration Kafka
producer = KafkaProducer(
    bootstrap_servers=['kafka:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

def scrape_hackernews():
    """Scrape simple du RSS de HackerNews"""
    try:
        # RSS feed de HackerNews
        feed = feedparser.parse('https://news.ycombinator.com/rss')
        
        for entry in feed.entries[:10]:  # Limiter à 10 articles
            article = {
                'id': entry.link,
                'title': entry.title,
                'url': entry.link,
                'timestamp': datetime.now().isoformat(),
                'source': 'hackernews'
            }
            
            # Envoyer vers Kafka
            producer.send('news-topic', article)
            print(f"✅ Article envoyé: {article['title'][:50]}...")
            
    except Exception as e:
        print(f"❌ Erreur scraping: {e}")

def main():
    print("🚀 Démarrage du scraper...")
    while True:
        scrape_hackernews()
        print("⏳ Pause de 5 minutes...")
        time.sleep(300)  # Scrape toutes les 5 minutes

if __name__ == "__main__":
    main()