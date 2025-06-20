FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# 🔹 Installer Java, unzip, curl et Python
RUN apt update && apt install -y \
    openjdk-8-jdk \
    unzip \
    curl \
    wget \
    python3 \
    python3-pip \
    procps \
    nano

# 🔹 Installer Kaggle CLI
RUN pip3 install kaggle

# 🔹 Variables pour Java
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 🔹 Préparer les dossiers
RUN mkdir -p /datasets/text /datasets/images

# 🔹 Ajouter le script + credentials Kaggle
COPY load_db_hdfs.sh .
COPY kaggle.json /root/.kaggle/kaggle.json
RUN chmod 600 /root/.kaggle/kaggle.json
RUN chmod +x load_db_hdfs.sh

CMD ["./load_db_hdfs.sh"]
