import streamlit as st
import pandas as pd
from pyspark.sql import SparkSession
import plotly.express as px
from datetime import datetime, timedelta

st.set_page_config(page_title="Hadoop Dashboard", layout="wide")

# Initialiser Spark
@st.cache_resource
def init_spark():
    return SparkSession.builder \
        .appName("Dashboard") \
        .config("spark.executor.memory", "2g") \
        .getOrCreate()

spark = init_spark()

st.title("📊 Dashboard Hadoop - Analyse en temps réel")

# Sidebar pour les options
st.sidebar.header("Options")
refresh_rate = st.sidebar.slider("Rafraîchissement (secondes)", 5, 60, 10)
show_last_hours = st.sidebar.slider("Afficher dernières heures", 1, 24, 6)

# Auto-refresh
st_autorefresh = st.sidebar.checkbox("Auto-refresh", value=True)
if st_autorefresh:
    st.experimental_rerun()

# Métriques principales
col1, col2, col3, col4 = st.columns(4)

try:
    # Lire les données depuis HDFS
    df = spark.read.parquet("hdfs://namenode:9000/data/streaming/news")
    
    # Convertir en Pandas pour Streamlit
    pdf = df.toPandas()
    
    # Métriques
    total_articles = len(pdf)
    avg_title_length = pdf['title_length'].mean() if 'title_length' in pdf else 0
    unique_sources = pdf['source'].nunique() if 'source' in pdf else 0
    
    col1.metric("📰 Total Articles", total_articles)
    col2.metric("📏 Longueur Moy. Titre", f"{avg_title_length:.1f}")
    col3.metric("🌐 Sources", unique_sources)
    col4.metric("🕐 Dernière MAJ", datetime.now().strftime("%H:%M:%S"))
    
    # Graphiques
    st.subheader("📈 Évolution du flux de données")
    
    if not pdf.empty:
        # Timeline des articles
        pdf['timestamp'] = pd.to_datetime(pdf['timestamp'])
        timeline = pdf.groupby(pdf['timestamp'].dt.hour).size().reset_index(name='count')
        
        fig1 = px.line(timeline, x='timestamp', y='count', 
                      title="Articles par heure",
                      labels={'count': 'Nombre d\'articles', 'timestamp': 'Heure'})
        st.plotly_chart(fig1, use_container_width=True)
        
        # Distribution par source
        col1, col2 = st.columns(2)
        
        with col1:
            source_dist = pdf['source'].value_counts().head(10)
            fig2 = px.pie(values=source_dist.values, names=source_dist.index,
                         title="Répartition par source")
            st.plotly_chart(fig2)
        
        with col2:
            # Longueur des titres
            fig3 = px.histogram(pdf, x='word_count', nbins=20,
                              title="Distribution longueur des titres",
                              labels={'word_count': 'Nombre de mots'})
            st.plotly_chart(fig3)
    
    # Tableau des derniers articles
    st.subheader("📋 Derniers articles traités")
    latest_articles = pdf.nlargest(10, 'timestamp')[['title', 'source', 'timestamp', 'word_count']]
    st.dataframe(latest_articles, use_container_width=True)
    
    # Section résultats IA (si disponibles)
    try:
        ia_df = spark.read.parquet("hdfs://namenode:9000/data/ia_results")
        ia_pdf = ia_df.toPandas()
        
        st.subheader("🤖 Résultats analyse IA")
        st.info(f"Total analyses: {len(ia_pdf)}")
        
        # Afficher quelques résultats
        if not ia_pdf.empty:
            st.dataframe(ia_pdf.head(5))
            
    except:
        st.info("Aucun résultat IA disponible pour le moment")
        
except Exception as e:
    st.error(f"Erreur lecture données: {e}")
    st.info("Vérifiez que le streaming est actif et que des données sont disponibles")

# Footer
st.markdown("---")
st.caption(f"Dashboard Hadoop | Dernière mise à jour: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")