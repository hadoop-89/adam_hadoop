FROM python:3.9-slim-bullseye

WORKDIR /app

# Install the necessary system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the new scraper
COPY scraper.py scraper.py

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV SCRAPE_INTERVAL=300

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import requests; requests.get('http://kafka:9092')" || exit 1

# Startup command
CMD ["python", "scraper.py"]
