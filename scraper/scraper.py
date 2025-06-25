# scraper/real_scraper.py - VRAI SCRAPING WEB

import requests
import json
import time
import feedparser
from bs4 import BeautifulSoup
from kafka import KafkaProducer
from datetime import datetime, timedelta
import logging
import os
import re
import random

# Configuration logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RealWebScraper:
    """
    Scraper web réel pour récupérer des données texte et images
    Conforme au cahier des charges
    """
    
    def __init__(self):
        # Configuration Kafka
        self.producer = KafkaProducer(
            bootstrap_servers=['kafka:9092'],
            value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode('utf-8'),
            key_serializer=lambda k: str(k).encode('utf-8')
        )
        
        # Configuration scraping
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        
        # Sources à scraper
        self.text_sources = [
            {
                'name': 'hackernews_rss',
                'url': 'https://news.ycombinator.com/rss',
                'type': 'rss'
            },
            {
                'name': 'reddit_technology',
                'url': 'https://www.reddit.com/r/technology.json',
                'type': 'reddit_api'
            },
            {
                'name': 'bbc_news_rss',
                'url': 'http://feeds.bbci.co.uk/news/technology/rss.xml',
                'type': 'rss'
            },
            {
                'name': 'techcrunch_rss',
                'url': 'https://techcrunch.com/feed/',
                'type': 'rss'
            }
        ]
        
        self.image_sources = [
            {
                'name': 'unsplash_technology',
                'base_url': 'https://api.unsplash.com/search/photos',
                'queries': ['technology', 'computer', 'ai', 'robot', 'data'],
                'type': 'unsplash_api'
            },
            {
                'name': 'reddit_earthporn',
                'url': 'https://www.reddit.com/r/EarthPorn.json',
                'type': 'reddit_images'
            }
        ]
        
        # Statistiques
        self.stats = {
            'total_scraped': 0,
            'text_articles': 0,
            'image_metadata': 0,
            'errors': 0
        }
    
    def scrape_hackernews_rss(self):
        """Scraper HackerNews RSS (amélioré)"""
        try:
            logger.info("🔍 Scraping HackerNews RSS...")
            
            feed = feedparser.parse('https://news.ycombinator.com/rss')
            articles = []
            
            for entry in feed.entries[:15]:  # 15 derniers articles
                # Nettoyage du titre
                title = self.clean_text(entry.title)
                
                # Extraction de l'URL et description
                description = getattr(entry, 'description', '') or getattr(entry, 'summary', '')
                
                article = {
                    'id': f"hn_{hash(entry.link)}",
                    'title': title,
                    'content': self.clean_text(description),
                    'url': entry.link,
                    'source': 'hackernews',
                    'category': 'technology',
                    'timestamp': datetime.now().isoformat(),
                    'scraped_at': datetime.now().isoformat(),
                    'word_count': len(title.split()),
                    'data_type': 'text'
                }
                
                articles.append(article)
                
                # Envoyer vers Kafka
                self.send_to_kafka('text-topic', article)
                self.stats['text_articles'] += 1
            
            logger.info(f"✅ HackerNews: {len(articles)} articles scrapés")
            return articles
            
        except Exception as e:
            logger.error(f"❌ Erreur HackerNews: {e}")
            self.stats['errors'] += 1
            return []
    
    def scrape_reddit_technology(self):
        """Scraper Reddit Technology"""
        try:
            logger.info("🔍 Scraping Reddit Technology...")
            
            response = requests.get(
                'https://www.reddit.com/r/technology.json?limit=20',
                headers=self.headers,
                timeout=10
            )
            
            if response.status_code != 200:
                logger.warning(f"Reddit API responded with {response.status_code}")
                return []
            
            data = response.json()
            articles = []
            
            for post in data['data']['children'][:12]:
                post_data = post['data']
                
                # Filtrer les posts avec du contenu
                if post_data.get('selftext') or post_data.get('title'):
                    title = self.clean_text(post_data.get('title', ''))
                    content = self.clean_text(post_data.get('selftext', ''))
                    
                    article = {
                        'id': f"reddit_{post_data['id']}",
                        'title': title,
                        'content': content if content else title,
                        'url': f"https://reddit.com{post_data.get('permalink', '')}",
                        'source': 'reddit_technology',
                        'category': 'technology',
                        'timestamp': datetime.now().isoformat(),
                        'scraped_at': datetime.now().isoformat(),
                        'upvotes': post_data.get('ups', 0),
                        'comments': post_data.get('num_comments', 0),
                        'word_count': len((title + ' ' + content).split()),
                        'data_type': 'text'
                    }
                    
                    articles.append(article)
                    self.send_to_kafka('text-topic', article)
                    self.stats['text_articles'] += 1
            
            logger.info(f"✅ Reddit Technology: {len(articles)} articles scrapés")
            return articles
            
        except Exception as e:
            logger.error(f"❌ Erreur Reddit Technology: {e}")
            self.stats['errors'] += 1
            return []
    
    def scrape_bbc_rss(self):
        """Scraper BBC Technology RSS"""
        try:
            logger.info("🔍 Scraping BBC Technology RSS...")
            
            feed = feedparser.parse('http://feeds.bbci.co.uk/news/technology/rss.xml')
            articles = []
            
            for entry in feed.entries[:10]:
                title = self.clean_text(entry.title)
                description = self.clean_text(getattr(entry, 'description', ''))
                
                article = {
                    'id': f"bbc_{hash(entry.link)}",
                    'title': title,
                    'content': description,
                    'url': entry.link,
                    'source': 'bbc_technology',
                    'category': 'technology',
                    'timestamp': datetime.now().isoformat(),
                    'scraped_at': datetime.now().isoformat(),
                    'published': getattr(entry, 'published', ''),
                    'word_count': len((title + ' ' + description).split()),
                    'data_type': 'text'
                }
                
                articles.append(article)
                self.send_to_kafka('text-topic', article)
                self.stats['text_articles'] += 1
            
            logger.info(f"✅ BBC Technology: {len(articles)} articles scrapés")
            return articles
            
        except Exception as e:
            logger.error(f"❌ Erreur BBC RSS: {e}")
            self.stats['errors'] += 1
            return []
    
    def scrape_techcrunch_rss(self):
        """Scraper TechCrunch RSS"""
        try:
            logger.info("🔍 Scraping TechCrunch RSS...")
            
            feed = feedparser.parse('https://techcrunch.com/feed/')
            articles = []
            
            for entry in feed.entries[:8]:
                title = self.clean_text(entry.title)
                content = self.clean_text(getattr(entry, 'content', [{}])[0].get('value', '') 
                                        if hasattr(entry, 'content') and entry.content 
                                        else getattr(entry, 'summary', ''))
                
                # Extraire les catégories si disponibles
                categories = []
                if hasattr(entry, 'tags'):
                    categories = [tag.term for tag in entry.tags[:3]]
                
                article = {
                    'id': f"tc_{hash(entry.link)}",
                    'title': title,
                    'content': content[:500] + '...' if len(content) > 500 else content,
                    'url': entry.link,
                    'source': 'techcrunch',
                    'category': 'technology',
                    'tags': categories,
                    'timestamp': datetime.now().isoformat(),
                    'scraped_at': datetime.now().isoformat(),
                    'published': getattr(entry, 'published', ''),
                    'word_count': len((title + ' ' + content).split()),
                    'data_type': 'text'
                }
                
                articles.append(article)
                self.send_to_kafka('text-topic', article)
                self.stats['text_articles'] += 1
            
            logger.info(f"✅ TechCrunch: {len(articles)} articles scrapés")
            return articles
            
        except Exception as e:
            logger.error(f"❌ Erreur TechCrunch: {e}")
            self.stats['errors'] += 1
            return []
    
    def scrape_reddit_images(self):
        """Scraper métadonnées d'images depuis Reddit"""
        try:
            logger.info("🖼️ Scraping Reddit images metadata...")
            
            subreddits = ['EarthPorn', 'MachinePorn', 'tech', 'pics']
            all_images = []
            
            for subreddit in subreddits[:2]:  # Limiter pour éviter rate limiting
                response = requests.get(
                    f'https://www.reddit.com/r/{subreddit}.json?limit=15',
                    headers=self.headers,
                    timeout=10
                )
                
                if response.status_code == 200:
                    data = response.json()
                    
                    for post in data['data']['children']:
                        post_data = post['data']
                        
                        # Vérifier si c'est une image
                        url = post_data.get('url', '')
                        if any(url.endswith(ext) for ext in ['.jpg', '.jpeg', '.png', '.gif']):
                            
                            image_metadata = {
                                'id': f"reddit_img_{post_data['id']}",
                                'title': self.clean_text(post_data.get('title', '')),
                                'image_url': url,
                                'thumbnail_url': post_data.get('thumbnail', ''),
                                'source': f'reddit_{subreddit}',
                                'category': self.categorize_image(post_data.get('title', '')),
                                'upvotes': post_data.get('ups', 0),
                                'comments': post_data.get('num_comments', 0),
                                'timestamp': datetime.now().isoformat(),
                                'scraped_at': datetime.now().isoformat(),
                                'subreddit': subreddit,
                                'author': post_data.get('author', 'unknown'),
                                'data_type': 'image_metadata'
                            }
                            
                            all_images.append(image_metadata)
                            self.send_to_kafka('images-topic', image_metadata)
                            self.stats['image_metadata'] += 1
                
                # Pause entre subreddits
                time.sleep(2)
            
            logger.info(f"✅ Reddit Images: {len(all_images)} métadonnées scrapées")
            return all_images
            
        except Exception as e:
            logger.error(f"❌ Erreur Reddit Images: {e}")
            self.stats['errors'] += 1
            return []
    
    def scrape_news_aggregation(self):
        """Scraper d'agrégation de news depuis plusieurs sources"""
        try:
            logger.info("📰 Scraping news aggregation...")
            
            # Sources RSS supplémentaires
            rss_sources = [
                'https://rss.cnn.com/rss/edition.rss',
                'https://feeds.reuters.com/reuters/technologyNews',
                'https://www.engadget.com/rss.xml'
            ]
            
            all_articles = []
            
            for rss_url in rss_sources[:2]:  # Limiter pour performance
                try:
                    feed = feedparser.parse(rss_url)
                    source_name = rss_url.split('//')[1].split('/')[0].replace('www.', '')
                    
                    for entry in feed.entries[:5]:  # 5 par source
                        title = self.clean_text(entry.title)
                        description = self.clean_text(getattr(entry, 'description', ''))
                        
                        article = {
                            'id': f"{source_name}_{hash(entry.link)}",
                            'title': title,
                            'content': description,
                            'url': entry.link,
                            'source': source_name,
                            'category': self.categorize_content(title + ' ' + description),
                            'timestamp': datetime.now().isoformat(),
                            'scraped_at': datetime.now().isoformat(),
                            'published': getattr(entry, 'published', ''),
                            'word_count': len((title + ' ' + description).split()),
                            'data_type': 'text'
                        }
                        
                        all_articles.append(article)
                        self.send_to_kafka('text-topic', article)
                        self.stats['text_articles'] += 1
                    
                    time.sleep(1)  # Pause entre sources
                    
                except Exception as e:
                    logger.warning(f"Erreur source {rss_url}: {e}")
            
            logger.info(f"✅ News Aggregation: {len(all_articles)} articles scrapés")
            return all_articles
            
        except Exception as e:
            logger.error(f"❌ Erreur News Aggregation: {e}")
            self.stats['errors'] += 1
            return []
    
    def clean_text(self, text):
        """Nettoyer le texte scrapé"""
        if not text:
            return ""
        
        # Supprimer les balises HTML
        text = BeautifulSoup(text, 'html.parser').get_text()
        
        # Supprimer les caractères spéciaux
        text = re.sub(r'[\r\n\t]+', ' ', text)
        text = re.sub(r'\s+', ' ', text)
        
        # Supprimer les URLs
        text = re.sub(r'http\S+|www\.\S+', '', text)
        
        return text.strip()
    
    def categorize_content(self, content):
        """Catégoriser le contenu selon des mots-clés"""
        content_lower = content.lower()
        
        categories = {
            'technology': ['ai', 'artificial intelligence', 'machine learning', 'tech', 'software', 'computer', 'digital'],
            'business': ['market', 'business', 'economy', 'finance', 'company', 'startup', 'investment'],
            'science': ['science', 'research', 'study', 'discovery', 'innovation', 'breakthrough'],
            'entertainment': ['movie', 'game', 'entertainment', 'music', 'film', 'gaming'],
            'sports': ['sport', 'football', 'basketball', 'soccer', 'olympic', 'championship'],
            'health': ['health', 'medical', 'medicine', 'doctor', 'hospital', 'disease', 'treatment']
        }
        
        for category, keywords in categories.items():
            if any(keyword in content_lower for keyword in keywords):
                return category
        
        return 'general'
    
    def categorize_image(self, title):
        """Catégoriser les images selon le titre"""
        title_lower = title.lower()
        
        if any(word in title_lower for word in ['nature', 'earth', 'landscape', 'mountain', 'forest']):
            return 'nature'
        elif any(word in title_lower for word in ['tech', 'computer', 'machine', 'robot']):
            return 'technology'
        elif any(word in title_lower for word in ['city', 'urban', 'building', 'architecture']):
            return 'urban'
        elif any(word in title_lower for word in ['car', 'vehicle', 'transport']):
            return 'vehicles'
        else:
            return 'general'
    
    def send_to_kafka(self, topic, data):
        """Envoyer les données vers Kafka"""
        try:
            # Ajouter métadonnées de traçabilité
            data['kafka_topic'] = topic
            data['sent_to_kafka_at'] = datetime.now().isoformat()
            
            self.producer.send(
                topic, 
                key=data['id'],
                value=data
            )
            self.stats['total_scraped'] += 1
            
        except Exception as e:
            logger.error(f"❌ Erreur envoi Kafka: {e}")
            self.stats['errors'] += 1
    
    def run_full_scraping_cycle(self):
        """Cycle complet de scraping"""
        logger.info("🚀 === DÉBUT CYCLE SCRAPING COMPLET ===")
        
        start_time = time.time()
        
        # Scraping textes
        logger.info("📝 Phase 1: Scraping textes...")
        text_results = []
        text_results.extend(self.scrape_hackernews_rss())
        time.sleep(2)
        text_results.extend(self.scrape_reddit_technology())
        time.sleep(2)
        text_results.extend(self.scrape_bbc_rss())
        time.sleep(2)
        text_results.extend(self.scrape_techcrunch_rss())
        time.sleep(2)
        text_results.extend(self.scrape_news_aggregation())
        
        # Scraping images metadata
        logger.info("🖼️ Phase 2: Scraping métadonnées images...")
        image_results = []
        image_results.extend(self.scrape_reddit_images())
        
        duration = time.time() - start_time
        
        # Statistiques finales
        logger.info("📊 === STATISTIQUES CYCLE SCRAPING ===")
        logger.info(f"⏱️ Durée totale: {duration:.1f}s")
        logger.info(f"📝 Articles texte: {self.stats['text_articles']}")
        logger.info(f"🖼️ Métadonnées images: {self.stats['image_metadata']}")
        logger.info(f"📊 Total envoyé Kafka: {self.stats['total_scraped']}")
        logger.info(f"❌ Erreurs: {self.stats['errors']}")
        
        # Résumé par source
        sources_summary = {}
        for article in text_results:
            source = article['source']
            sources_summary[source] = sources_summary.get(source, 0) + 1
        
        logger.info("📋 Résumé par source:")
        for source, count in sources_summary.items():
            logger.info(f"   • {source}: {count} articles")
        
        return {
            'text_articles': text_results,
            'image_metadata': image_results,
            'stats': self.stats,
            'duration': duration
        }

def main():
    """Fonction principale du scraper"""
    logger.info("🚀 Démarrage du scraper web réel...")
    
    scraper = RealWebScraper()
    
    # Configuration depuis variables d'environnement
    scrape_interval = int(os.getenv('SCRAPE_INTERVAL', 300))  # 5 minutes par défaut
    
    logger.info(f"⏰ Intervalle de scraping: {scrape_interval}s")
    
    while True:
        try:
            # Lancer un cycle complet
            results = scraper.run_full_scraping_cycle()
            
            logger.info(f"✅ Cycle terminé. Prochain cycle dans {scrape_interval}s...")
            
            # Attendre avant le prochain cycle
            time.sleep(scrape_interval)
            
        except KeyboardInterrupt:
            logger.info("🛑 Arrêt du scraper...")
            break
        except Exception as e:
            logger.error(f"❌ Erreur dans le cycle principal: {e}")
            time.sleep(60)  # Attendre 1 min en cas d'erreur

if __name__ == "__main__":
    main()