import streamlit as st
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
import time
import requests
import json

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

# Fonction pour lire depuis HDFS via l'API NameNode
@st.cache_data(ttl=60)
def read_hdfs_data():
    """Lire les données depuis HDFS via l'API NameNode"""
    try:
        # Lire reviews existantes
        reviews_url = "http://namenode:9870/webhdfs/v1/data/text/existing/existing_reviews_db.csv?op=OPEN"
        response = requests.get(reviews_url, allow_redirects=True, timeout=10)
        
        if response.status_code == 200:
            # Parser le CSV
            lines = response.text.strip().split('\n')
            if len(lines) > 1:  # Au moins header + 1 ligne
                header = lines[0].split(',')
                data = []
                for line in lines[1:]:
                    if line.strip():
                        data.append(line.split(','))
                
                if data:
                    reviews_df = pd.DataFrame(data, columns=header)
                    # Nettoyer les guillemets
                    for col in reviews_df.columns:
                        if reviews_df[col].dtype == 'object':
                            reviews_df[col] = reviews_df[col].str.strip('"')
                    return reviews_df
        
        return None
    except Exception as e:
        st.error(f"Erreur lecture HDFS: {e}")
        return None

@st.cache_data(ttl=60)
def read_hdfs_images():
    """Lire les métadonnées images depuis HDFS"""
    try:
        images_url = "http://namenode:9870/webhdfs/v1/data/images/existing/existing_images_db.csv?op=OPEN"
        response = requests.get(images_url, allow_redirects=True, timeout=10)
        
        if response.status_code == 200:
            lines = response.text.strip().split('\n')
            if len(lines) > 1:
                header = lines[0].split(',')
                data = []
                for line in lines[1:]:
                    if line.strip():
                        data.append(line.split(','))
                
                if data:
                    images_df = pd.DataFrame(data, columns=header)
                    for col in images_df.columns:
                        if images_df[col].dtype == 'object':
                            images_df[col] = images_df[col].str.strip('"')
                    return images_df
        
        return None
    except Exception as e:
        st.error(f"Erreur lecture images HDFS: {e}")
        return None

# Charger les données réelles
reviews_df = read_hdfs_data()
images_df = read_hdfs_images()

# Métriques principales
col1, col2, col3, col4 = st.columns(4)

if reviews_df is not None:
    total_reviews = len(reviews_df)
    
    # Calculer moyenne rating
    try:
        reviews_df['rating_numeric'] = pd.to_numeric(reviews_df['rating'], errors='coerce')
        avg_rating = reviews_df['rating_numeric'].mean()
    except:
        avg_rating = 0
    
    unique_sources = reviews_df['source'].nunique() if 'source' in reviews_df.columns else 0
    
    col1.metric("📰 Total Reviews", total_reviews)
    col2.metric("⭐ Rating Moyen", f"{avg_rating:.1f}")
    col3.metric("🌐 Sources", unique_sources)
    col4.metric("🕐 Dernière MAJ", datetime.now().strftime("%H:%M:%S"))
    
    # Graphiques avec vraies données
    st.subheader("📈 Analyse des données HDFS")
    
    col1, col2 = st.columns(2)
    
    with col1:
        # Distribution par rating
        if 'rating_numeric' in reviews_df.columns:
            rating_counts = reviews_df['rating_numeric'].value_counts().sort_index()
            fig1 = px.bar(
                x=rating_counts.index, 
                y=rating_counts.values,
                title="Distribution des Ratings",
                labels={'x': 'Rating', 'y': 'Nombre de reviews'}
            )
            st.plotly_chart(fig1, use_container_width=True)
    
    with col2:
        # Distribution par source
        if 'source' in reviews_df.columns:
            source_counts = reviews_df['source'].value_counts()
            fig2 = px.pie(
                values=source_counts.values,
                names=source_counts.index,
                title="Reviews par Source"
            )
            st.plotly_chart(fig2, use_container_width=True)
    
    # Tableau des données réelles
    st.subheader("📋 Données Reviews depuis HDFS")
    st.dataframe(reviews_df.head(10), use_container_width=True)
    
else:
    col1.metric("📰 Total Reviews", "Erreur HDFS")
    col2.metric("⭐ Rating Moyen", "N/A")
    col3.metric("🌐 Sources", "N/A")
    col4.metric("🕐 Statut", "❌ Pas de données")
    
    st.error("🚫 Impossible de charger les données depuis HDFS")
    st.info("Vérifiez que le NameNode est accessible et que les données sont présentes")

# Section Images
if images_df is not None:
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
    
    # Afficher l'espace HDFS si possible
    try:
        hdfs_info_url = "http://namenode:9870/jmx?qry=Hadoop:service=NameNode,name=FSNamesystemState"
        response = requests.get(hdfs_info_url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            if 'beans' in data and len(data['beans']) > 0:
                capacity_gb = data['beans'][0].get('CapacityTotalGB', 0)
                st.metric("💽 Capacité HDFS", f"{capacity_gb:.1f} GB")
            else:
                st.metric("💽 Capacité HDFS", "N/A")
        else:
            st.metric("💽 Capacité HDFS", "N/A")
    except:
        st.metric("💽 Capacité HDFS", "N/A")

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

# Footer
st.markdown("---")
st.caption(f"Dashboard Hadoop | Données réelles HDFS | Dernière mise à jour: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")