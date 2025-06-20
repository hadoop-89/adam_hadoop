FROM python:3.9-slim-bullseye

WORKDIR /app

# Installer les dépendances système pour Spark
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    openjdk-11-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Installer PySpark et les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier l'application
COPY dashboard.py .

# Port Streamlit
EXPOSE 8501

# Lancer Streamlit
CMD ["streamlit", "run", "dashboard.py", "--server.port=8501", "--server.address=0.0.0.0"]