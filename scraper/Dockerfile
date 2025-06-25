FROM python:3.9-slim-bullseye

WORKDIR /app

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copier et installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copier le nouveau scraper
COPY scraper.py scraper.py

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV SCRAPE_INTERVAL=300

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import requests; requests.get('http://kafka:9092')" || exit 1

# Commande de démarrage
CMD ["python", "scraper.py"]
