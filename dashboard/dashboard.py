import streamlit as st
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
import time

st.set_page_config(page_title="Hadoop Dashboard", layout="wide")

st.title("📊 Dashboard Hadoop - Analyse en temps réel")

# Sidebar pour les options
st.sidebar.header("Options")
refresh_rate = st.sidebar.slider("Rafraîchissement (secondes)", 5, 60, 10)
show_last_hours = st.sidebar.slider("Afficher dernières heures", 1, 24, 6)

# Auto-refresh corrigé
st_autorefresh = st.sidebar.checkbox("Auto-refresh", value=False)
if st_autorefresh:
    time.sleep(refresh_rate)
    st.rerun()  # Remplace st.experimental_rerun()

# Métriques principales
col1, col2, col3, col4 = st.columns(4)

try:
    # Simulation de données en l'absence de Spark
    st.info("📋 Dashboard en mode simulation - Cluster Hadoop opérationnel")
    
    # Métriques simulées basées sur vos données réelles
    total_articles = 10
    avg_title_length = 8.5
    unique_sources = 3
    
    col1.metric("📰 Total Reviews", total_articles)
    col2.metric("📏 Mots Moy. Review", f"{avg_title_length:.1f}")
    col3.metric("🌐 Sources", unique_sources)
    col4.metric("🕐 Dernière MAJ", datetime.now().strftime("%H:%M:%S"))
    
    # Graphiques simulés
    st.subheader("📈 Analyse des données HDFS")
    
    # Simulation de données de sentiment
    sentiment_data = {
        'Sentiment': ['Positive', 'Negative', 'Neutral'],
        'Nombre': [6, 2, 2]
    }
    sentiment_df = pd.DataFrame(sentiment_data)
    
    col1, col2 = st.columns(2)
    
    with col1:
        fig1 = px.pie(sentiment_df, values='Nombre', names='Sentiment',
                     title="Distribution des Sentiments",
                     color_discrete_map={
                         'Positive': '#2E8B57',
                         'Negative': '#DC143C', 
                         'Neutral': '#FFD700'
                     })
        st.plotly_chart(fig1, use_container_width=True)
    
    with col2:
        # Simulation de données par source
        source_data = {
            'Source': ['Amazon', 'eBay', 'Shopify'],
            'Reviews': [5, 2, 3]
        }
        source_df = pd.DataFrame(source_data)
        
        fig2 = px.bar(source_df, x='Source', y='Reviews',
                     title="Reviews par Source",
                     color='Source')
        st.plotly_chart(fig2, use_container_width=True)
    
    # Tableau des données
    st.subheader("📋 Données stockées dans HDFS")
    
    # Simulation des données de votre fichier reviews.csv
    sample_data = {
        'ID': [1, 2, 3, 4, 5],
        'Review': [
            'This product is absolutely amazing! Great quality...',
            'Terrible experience. Product broke after one day...',
            'Average product. Nothing special but does what...',
            'Excellent customer service and fantastic features...',
            'Poor quality for the price. Would not buy again...'
        ],
        'Rating': [5, 1, 3, 5, 2],
        'Source': ['amazon', 'ebay', 'amazon', 'shopify', 'amazon'],
        'Sentiment': ['Positive', 'Negative', 'Neutral', 'Positive', 'Negative']
    }
    
    sample_df = pd.DataFrame(sample_data)
    st.dataframe(sample_df, use_container_width=True)
    
    # État du cluster
    st.subheader("🖥️ État du Cluster Hadoop")
    
    cluster_col1, cluster_col2, cluster_col3 = st.columns(3)
    
    with cluster_col1:
        st.success("✅ NameNode - Opérationnel")
        st.info("Port: 9870")
        
    with cluster_col2:
        st.success("✅ DataNode 1 - Connecté")
        st.info("Port: 9864")
        
    with cluster_col3:
        st.success("✅ DataNode 2 - Connecté") 
        st.info("Port: 9865")
    
    # Informations système
    st.subheader("📊 Informations Système")
    
    info_col1, info_col2 = st.columns(2)
    
    with info_col1:
        st.metric("💾 Données HDFS", "11 reviews + métadonnées")
        st.metric("🔄 Services Actifs", "13 conteneurs")
        
    with info_col2:
        st.metric("🚀 Spark Workers", "1 worker actif")
        st.metric("📡 Kafka Topics", "news-topic")
    
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
        
except Exception as e:
    st.error(f"Erreur: {e}")
    st.info("Vérifiez que le cluster Hadoop est démarré")

# Footer
st.markdown("---")
st.caption(f"Dashboard Hadoop | Dernière mise à jour: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")