FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# 🔹 Install Java, unzip, curl and Python
RUN apt update && apt install -y \
    openjdk-8-jdk \
    unzip \
    curl \
    wget \
    python3 \
    python3-pip \
    procps \
    nano \
    dos2unix

# 🔹 Install Kaggle CLI
RUN pip3 install kaggle

# 🔹 Variables for Java
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 🔹 Prepare directories
RUN mkdir -p /datasets/text /datasets/images

# 🔹 Copy and fix script (Windows->Linux conversion)
COPY load_db_hdfs.sh ./load_db_hdfs.sh
RUN dos2unix ./load_db_hdfs.sh && chmod +x ./load_db_hdfs.sh

# 🔹 Prepare Kaggle configuration folder
ENV KAGGLE_CONFIG_DIR=/root/.kaggle
RUN mkdir -p "$KAGGLE_CONFIG_DIR"

# 🔹 Fix SERVER_PID issue
ENV SERVER_PID=""

CMD ["./load_db_hdfs.sh"]