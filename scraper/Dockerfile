FROM python:3.9-slim-bullseye

WORKDIR /app

# Update system packages to address vulnerabilities
RUN apt-get update && apt-get upgrade -y && apt-get clean

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY scraper.py .

CMD ["python", "scraper.py"]