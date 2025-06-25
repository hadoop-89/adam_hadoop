import streamlit as st
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
import time
import requests
import json

from kafka import KafkaConsumer
import json
from collections import defaultdict

st.set_page_config(page_title="Hadoop Dashboard", layout="wide")

st.title("📊 Dashboard Hadoop - Analyse en temps réel")

# Sidebar pour les options
st.sidebar.header("Options")
refresh_rate = st.sidebar.slider("Rafraîchissement (secondes)", 5, 60, 10)
show_last_hours = st.sidebar.slider("Afficher dernières heures", 1, 24, 6)

# Auto-refresh
st_autorefresh = st.sidebar.checkbox("Auto-refresh", value=False)
if st_autorefresh:
    time.sleep(refresh_rate)
    st.rerun()

# Fonction pour lire depuis HDFS via l'API NameNode - VERSION CORRIGÉE
@st.cache_data(ttl=60)
def read_hdfs_data():
    """Lire les données depuis HDFS via l'API NameNode - Version corrigée"""
    try:
        # CORRECTION: Utiliser les noms de fichiers réels
        reviews_url = "http://namenode:9870/webhdfs/v1/data/text/existing/amazon_reviews.csv?op=OPEN"
        response = requests.get(reviews_url, allow_redirects=True, timeout=10)
        
        if response.status_code == 200:
            # Parser le CSV Amazon Reviews (format réel)
            lines = response.text.strip().split('\n')
            if len(lines) > 1:  # Au moins header + 1 ligne
                header = lines[0].split(',')
                data = []
                for line in lines[1:100]:  # Limiter à 100 lignes pour performance
                    if line.strip():
                        # Parser CSV avec gestion des guillemets
                        parts = []
                        in_quotes = False
                        current_part = ""
                        
                        for char in line:
                            if char == '"':
                                in_quotes = not in_quotes
                            elif char == ',' and not in_quotes:
                                parts.append(current_part.strip('"'))
                                current_part = ""
                            else:
                                current_part += char
                        
                        if current_part:
                            parts.append(current_part.strip('"'))
                        
                        if len(parts) >= len(header):
                            data.append(parts[:len(header)])
                
                if data:
                    reviews_df = pd.DataFrame(data, columns=header)
                    return reviews_df
        
        return None
    except Exception as e:
        st.error(f"Erreur lecture HDFS reviews: {e}")
        return None

@st.cache_data(ttl=60)
def read_hdfs_images():
    """Lire les métadonnées images depuis HDFS - Version corrigée"""
    try:
        # CORRECTION: Chercher le bon fichier d'images
        images_url = "http://namenode:9870/webhdfs/v1/data/images/existing/intel_images_metadata.csv?op=OPEN"
        response = requests.get(images_url, allow_redirects=True, timeout=10)
        
        if response.status_code == 200:
            lines = response.text.strip().split('\n')
            if len(lines) > 1:
                header = lines[0].split(',')
                data = []
                for line in lines[1:50]:  # Limiter pour performance
                    if line.strip():
                        parts = line.split(',')
                        if len(parts) >= len(header):
                            # Nettoyer les guillemets
                            clean_parts = [part.strip('"') for part in parts[:len(header)]]
                            data.append(clean_parts)
                
                if data:
                    images_df = pd.DataFrame(data, columns=header)
                    return images_df
        
        return None
    except Exception as e:
        st.error(f"Erreur lecture images HDFS: {e}")
        return None

@st.cache_data(ttl=30)  # Cache plus court pour data temps réel
def read_kafka_scraping_data():
    """Lire les données de scraping depuis Kafka"""
    try:
        # Consumer Kafka pour lire les dernières données
        consumer = KafkaConsumer(
            'text-topic',
            'images-topic', 
            bootstrap_servers=['kafka:9092'],
            auto_offset_reset='latest',
            consumer_timeout_ms=5000,  # 5 secondes timeout
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )
        
        scraped_data = {
            'text_articles': [],
            'image_metadata': [],
            'last_update': None
        }
        
        # Lire les messages récents
        message_count = 0
        for message in consumer:
            if message_count >= 50:  # Limiter à 50 messages récents
                break
                
            data = message.value
            
            if message.topic == 'text-topic':
                scraped_data['text_articles'].append(data)
            elif message.topic == 'images-topic':
                scraped_data['image_metadata'].append(data)
                
            scraped_data['last_update'] = data.get('scraped_at', 'Unknown')
            message_count += 1
        
        consumer.close()
        return scraped_data
        
    except Exception as e:
        st.warning(f"Kafka non accessible: {e}")
        return None

@st.cache_data(ttl=60)
def get_scraping_statistics():
    """Statistiques de scraping depuis Kafka"""
    try:
        consumer = KafkaConsumer(
            'text-topic',
            'images-topic',
            bootstrap_servers=['kafka:9092'],
            auto_offset_reset='earliest',
            consumer_timeout_ms=3000,
            value_deserializer=lambda m: json.loads(m.decode('utf-8'))
        )
        
        stats = {
            'total_articles': 0,
            'total_images': 0,
            'sources': defaultdict(int),
            'categories': defaultdict(int),
            'last_hour_count': 0
        }
        
        now = datetime.now()
        one_hour_ago = now - timedelta(hours=1)
        
        for message in consumer:
            data = message.value
            
            if message.topic == 'text-topic':
                stats['total_articles'] += 1
                stats['sources'][data.get('source', 'unknown')] += 1
                stats['categories'][data.get('category', 'general')] += 1
                
                # Compter dernière heure
                try:
                    scraped_time = datetime.fromisoformat(data.get('scraped_at', '').replace('Z', ''))
                    if scraped_time >= one_hour_ago:
                        stats['last_hour_count'] += 1
                except:
                    pass
                    
            elif message.topic == 'images-topic':
                stats['total_images'] += 1
        
        consumer.close()
        return dict(stats)
        
    except Exception as e:
        return {
            'total_articles': 0,
            'total_images': 0,
            'sources': {},
            'categories': {},
            'last_hour_count': 0,
            'error': str(e)
        }

# Fonction de fallback avec données de test
def create_test_data():
    """Créer des données de test si HDFS inaccessible"""
    st.info("🔄 Utilisation de données de test (HDFS inaccessible)")
    
    # Données reviews de test
    test_reviews = pd.DataFrame({
        'Id': range(1, 21),
        'ProductId': [f'B00{i}E4KFG0' for i in range(1, 21)],
        'Score': [5, 1, 3, 5, 2, 5, 3, 5, 2, 5, 4, 3, 2, 5, 1, 4, 5, 3, 2, 4],
        'Summary': [f'Review {i}' for i in range(1, 21)],
        'Text': [f'Sample review text {i}' for i in range(1, 21)]
    })
    
    # Données images de test
    test_images = pd.DataFrame({
        'image_id': range(1, 16),
        'filename': [f'image_{i}.jpg' for i in range(1, 16)],
        'category': ['nature', 'animal', 'vehicle', 'building', 'food'] * 3
    })
    
    return test_reviews, test_images

# Charger les données réelles ou de test
reviews_df = read_hdfs_data()
images_df = read_hdfs_images()

# Si échec, utiliser données de test
if reviews_df is None or images_df is None:
    if reviews_df is None and images_df is None:
        reviews_df, images_df = create_test_data()
    elif reviews_df is None:
        reviews_df, _ = create_test_data()
        reviews_df, _ = create_test_data()
    elif images_df is None:
        _, images_df = create_test_data()

# Métriques principales
col1, col2, col3, col4 = st.columns(4)

if reviews_df is not None and len(reviews_df) > 0:
    total_reviews = len(reviews_df)
    
    # Calculer moyenne rating (Score pour Amazon)
    try:
        if 'Score' in reviews_df.columns:
            reviews_df['rating_numeric'] = pd.to_numeric(reviews_df['Score'], errors='coerce')
            avg_rating = reviews_df['rating_numeric'].mean()
        elif 'rating' in reviews_df.columns:
            reviews_df['rating_numeric'] = pd.to_numeric(reviews_df['rating'], errors='coerce')
            avg_rating = reviews_df['rating_numeric'].mean()
        else:
            avg_rating = 0
    except:
        avg_rating = 0
    
    # Sources uniques
    source_cols = [col for col in reviews_df.columns if 'source' in col.lower()]
    unique_sources = reviews_df[source_cols[0]].nunique() if source_cols else 1
    
    col1.metric("📰 Total Reviews", total_reviews)
    col2.metric("⭐ Rating Moyen", f"{avg_rating:.1f}")
    col3.metric("🌐 Sources", unique_sources)
    col4.metric("🕐 Dernière MAJ", datetime.now().strftime("%H:%M:%S"))
    
    # Graphiques avec vraies données
    st.subheader("📈 Analyse des données HDFS (Vraies données)")
    
    col1, col2 = st.columns(2)
    
    with col1:
        # Distribution par rating
        if 'rating_numeric' in reviews_df.columns:
            rating_counts = reviews_df['rating_numeric'].value_counts().sort_index()
            fig1 = px.bar(
                x=rating_counts.index, 
                y=rating_counts.values,
                title="Distribution des Ratings Amazon",
                labels={'x': 'Rating', 'y': 'Nombre de reviews'}
            )
            st.plotly_chart(fig1, use_container_width=True)
    
    with col2:
        # Top produits ou autre analyse
        if 'ProductId' in reviews_df.columns:
            top_products = reviews_df['ProductId'].value_counts().head(5)
            fig2 = px.pie(
                values=top_products.values,
                names=top_products.index,
                title="Top 5 Produits"
            )
            st.plotly_chart(fig2, use_container_width=True)
    
    # Tableau des données réelles
    st.subheader("📋 Données Reviews depuis HDFS (Échantillon)")
    # Afficher seulement les colonnes importantes
    display_cols = ['Id', 'Score', 'Summary', 'Text']
    available_cols = [col for col in display_cols if col in reviews_df.columns]
    if available_cols:
        st.dataframe(reviews_df[available_cols].head(10), use_container_width=True)
    else:
        st.dataframe(reviews_df.head(10), use_container_width=True)
    
else:
    col1.metric("📰 Total Reviews", "Erreur HDFS")
    col2.metric("⭐ Rating Moyen", "N/A")
    col3.metric("🌐 Sources", "N/A")
    col4.metric("🕐 Statut", "❌ Pas de données")
    
    st.error("🚫 Impossible de charger les données depuis HDFS")
    st.info("💡 Vérifications suggérées:")
    st.code("""
# 1. Vérifier que HDFS contient les données
docker exec namenode hdfs dfs -ls /data/text/existing/

# 2. Vérifier le contenu
docker exec namenode hdfs dfs -cat /data/text/existing/amazon_reviews.csv | head -3

# 3. Vérifier l'API NameNode
curl http://localhost:9870/webhdfs/v1/data/text/existing/?op=LISTSTATUS
    """)

# Section Images
if images_df is not None and len(images_df) > 0:
    st.subheader("🖼️ Métadonnées Images depuis HDFS")
    
    if 'category' in images_df.columns:
        category_counts = images_df['category'].value_counts()
        fig3 = px.bar(
            x=category_counts.values,
            y=category_counts.index,
            orientation='h',
            title="Images par Catégorie"
        )
        st.plotly_chart(fig3, use_container_width=True)
    
    st.dataframe(images_df.head(5), use_container_width=True)

# ============ NOUVELLE SECTION SCRAPING WEB ============
st.subheader("🌐 Scraping Web en Temps Réel")

# Onglets pour séparer les vues
tab1, tab2, tab3 = st.tabs(["📊 Statistiques", "📝 Articles Récents", "🖼️ Images Récentes"])

with tab1:
    st.markdown("### 📈 Statistiques de Scraping")
    
    # Lire les stats
    scraping_stats = get_scraping_statistics()
    
    # Métriques principales
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("📰 Total Articles", scraping_stats.get('total_articles', 0))
    with col2:
        st.metric("🖼️ Total Images", scraping_stats.get('total_images', 0))
    with col3:
        st.metric("🕐 Dernière Heure", scraping_stats.get('last_hour_count', 0))
    with col4:
        sources_count = len(scraping_stats.get('sources', {}))
        st.metric("🌐 Sources Actives", sources_count)
    
    # Graphiques de répartition
    if scraping_stats.get('sources'):
        col1, col2 = st.columns(2)
        
        with col1:
            # Graphique sources
            sources_data = scraping_stats['sources']
            fig1 = px.pie(
                values=list(sources_data.values()),
                names=list(sources_data.keys()),
                title="Répartition par Source"
            )
            st.plotly_chart(fig1, use_container_width=True)
        
        with col2:
            # Graphique catégories
            categories_data = scraping_stats['categories']
            if categories_data:
                fig2 = px.bar(
                    x=list(categories_data.keys()),
                    y=list(categories_data.values()),
                    title="Articles par Catégorie"
                )
                st.plotly_chart(fig2, use_container_width=True)
    else:
        st.info("📊 Pas de données de scraping trouvées dans Kafka")

with tab2:
    st.markdown("### 📝 Articles Scrapés Récemment")
    
    # Lire les données récentes
    scraped_data = read_kafka_scraping_data()
    
    if scraped_data and scraped_data['text_articles']:
        articles = scraped_data['text_articles'][-10:]  # 10 derniers
        
        for i, article in enumerate(reversed(articles)):
            with st.expander(f"📰 {article.get('title', 'Sans titre')[:60]}..."):
                col1, col2 = st.columns([3, 1])
                
                with col1:
                    st.write(f"**Source:** {article.get('source', 'Unknown')}")
                    st.write(f"**Catégorie:** {article.get('category', 'general')}")
                    st.write(f"**Contenu:** {article.get('content', 'Pas de contenu')[:200]}...")
                    if article.get('url'):
                        st.write(f"**URL:** {article['url']}")
                
                with col2:
                    st.write(f"🕐 {article.get('scraped_at', 'Unknown')[:19]}")
                    st.write(f"📊 {article.get('word_count', 0)} mots")
                    if 'upvotes' in article:
                        st.write(f"👍 {article['upvotes']} upvotes")
        
        if scraped_data.get('last_update'):
            st.success(f"✅ Dernière mise à jour: {scraped_data['last_update'][:19]}")
    else:
        st.warning("⚠️ Aucun article récent trouvé dans Kafka")
        st.info("💡 Le scraper est peut-être en cours de démarrage")

with tab3:
    st.markdown("### 🖼️ Métadonnées Images Récentes")
    
    if scraped_data and scraped_data['image_metadata']:
        images = scraped_data['image_metadata'][-8:]  # 8 dernières
        
        # Affichage en grille
        cols = st.columns(2)
        
        for i, img_data in enumerate(reversed(images)):
            col = cols[i % 2]
            
            with col:
                with st.container():
                    st.markdown(f"**🖼️ {img_data.get('title', 'Sans titre')[:40]}**")
                    st.write(f"**Source:** {img_data.get('source', 'Unknown')}")
                    st.write(f"**Catégorie:** {img_data.get('category', 'general')}")
                    
                    if img_data.get('thumbnail_url') and img_data['thumbnail_url'] != 'self':
                        try:
                            st.image(img_data['thumbnail_url'], width=200)
                        except:
                            st.write("🖼️ Miniature non disponible")
                    
                    if 'upvotes' in img_data:
                        st.write(f"👍 {img_data['upvotes']} | 💬 {img_data.get('comments', 0)}")
                    
                    st.write(f"🕐 {img_data.get('scraped_at', 'Unknown')[:19]}")
                    st.markdown("---")
    else:
        st.warning("⚠️ Aucune métadonnée d'image récente")

# Indicateur de statut du scraper
st.markdown("### 🤖 Statut du Scraper")

try:
    # Test de connectivité Kafka
    test_consumer = KafkaConsumer(
        bootstrap_servers=['kafka:9092'],
        consumer_timeout_ms=2000
    )
    test_consumer.close()
    
    st.success("✅ Scraper connecté à Kafka")
    
    # Afficher quelques métriques temps réel
    if scraped_data and scraped_data.get('last_update'):
        try:
            last_update = datetime.fromisoformat(scraped_data['last_update'].replace('Z', ''))
            time_diff = datetime.now() - last_update
            
            if time_diff.total_seconds() < 600:  # Moins de 10 min
                st.success(f"🟢 Scraper actif (dernière activité: {int(time_diff.total_seconds())}s)")
            else:
                st.warning(f"🟡 Scraper ralenti (dernière activité: {int(time_diff.total_seconds()/60)}min)")
        except:
            st.info("🔄 Scraper en cours de démarrage...")
    else:
        st.info("🔄 Scraper en cours de démarrage...")
        
except Exception as e:
    st.error("❌ Scraper déconnecté de Kafka")
    st.error(f"Détails: {str(e)}")

# Instructions pour voir les logs
with st.expander("🔧 Debug Scraper"):
    st.code("""
# Voir les logs du scraper
docker logs scraper -f

# Redémarrer le scraper
docker-compose restart scraper

# Voir les topics Kafka
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Lire directement depuis Kafka
docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic text-topic --from-beginning
    """, language="bash")

# État du cluster
st.subheader("🖥️ État du Cluster Hadoop")

cluster_col1, cluster_col2, cluster_col3 = st.columns(3)

# Test de connectivité réelle
@st.cache_data(ttl=30)
def check_services():
    services_status = {}
    
    services = {
        "NameNode": "http://namenode:9870",
        "DataNode1": "http://datanode1:9864", 
        "DataNode2": "http://datanode2:9864"
    }
    
    for name, url in services.items():
        try:
            response = requests.get(url, timeout=5)
            services_status[name] = response.status_code == 200
        except:
            services_status[name] = False
    
    return services_status

services_status = check_services()

with cluster_col1:
    status = "✅ Opérationnel" if services_status.get("NameNode", False) else "❌ Hors ligne"
    st.metric("NameNode", status)
    
with cluster_col2:
    status = "✅ Connecté" if services_status.get("DataNode1", False) else "❌ Hors ligne"
    st.metric("DataNode 1", status)
    
with cluster_col3:
    status = "✅ Connecté" if services_status.get("DataNode2", False) else "❌ Hors ligne"
    st.metric("DataNode 2", status)

# Informations système réelles
st.subheader("📊 Informations HDFS")

info_col1, info_col2 = st.columns(2)

with info_col1:
    if reviews_df is not None:
        st.metric("💾 Reviews HDFS", len(reviews_df))
    else:
        st.metric("💾 Reviews HDFS", "Erreur")
    
    all_services = sum(services_status.values())
    st.metric("🔄 Services Actifs", f"{all_services}/3")
    
with info_col2:
    if images_df is not None:
        st.metric("🖼️ Images HDFS", len(images_df))
    else:
        st.metric("🖼️ Images HDFS", "Erreur")
    
    # Statut général
    if all_services >= 2:
        st.metric("📈 Statut Cluster", "✅ Opérationnel")
    else:
        st.metric("📈 Statut Cluster", "⚠️ Dégradé")

# Footer avec liens
st.markdown("---")
st.markdown("### 🔗 Liens Utiles")

link_col1, link_col2, link_col3 = st.columns(3)

with link_col1:
    st.markdown("[📊 HDFS Web UI](http://localhost:9870)")
    
with link_col2:
    st.markdown("[⚡ Spark UI](http://localhost:8080)")
    
with link_col3:
    st.markdown("[📈 Dashboard](http://localhost:8501)")

# Debug info
with st.expander("🔧 Informations de Debug"):
    st.write("**État des données:**")
    st.write(f"- Reviews DF: {reviews_df is not None and len(reviews_df) > 0}")
    st.write(f"- Images DF: {images_df is not None and len(images_df) > 0}")
    st.write(f"- Services: {services_status}")
    
    if reviews_df is not None:
        st.write("**Colonnes Reviews:**", list(reviews_df.columns))
    if images_df is not None:
        st.write("**Colonnes Images:**", list(images_df.columns))

# Footer
st.markdown("---")
st.caption(f"Dashboard Hadoop | Données réelles HDFS + Scraping temps réel | Dernière mise à jour: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")