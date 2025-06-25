FROM python:3.9-slim-bullseye

WORKDIR /app

# Install system dependencies for Spark
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    openjdk-11-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install PySpark and Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application files
COPY dashboard.py .

# Port Streamlit
EXPOSE 8501

# Start Streamlit
CMD ["streamlit", "run", "dashboard.py", "--server.port=8501", "--server.address=0.0.0.0"]