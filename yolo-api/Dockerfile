# Use an official Python image as a base
FROM python:3.9-slim

# Set the working directory inside the container
WORKDIR /app

# Copy necessary files into the container
COPY app.py /app/app.py
COPY requirements.txt /app/requirements.txt

# Update repositories and install nano and other necessary tools
RUN apt-get update && apt-get install -y nano \
    software-properties-common \
    openssh-server \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-setuptools \
    git \
    libgl1 && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install pytest pytest-flask

# Expose port 8000 for the Flask application
EXPOSE 8000

# Command to keep the container running
# Command to run the Flask application
CMD ["sh", "-c", "python app.py & tail -f /dev/null"]

