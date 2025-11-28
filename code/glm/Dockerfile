# FROM python:3.10.7-slim
# RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ nano



FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive


# Base utilities and compilers
RUN apt-get update && apt-get install -y --no-install-recommends \
    git g++ python3 python3-pip python3-numpy \
    libeigen3-dev zlib1g-dev libqt5opengl5-dev libgl1-mesa-dev \
    libfftw3-dev libtiff5-dev jq strace curl vim wget unzip bc \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN python3 -m pip install --no-cache-dir -r requirements.txt
ARG version

RUN wget https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v$version.zip -O workbench.zip && unzip workbench.zip -d /usr/local/ && rm workbench.zip 

ENV PATH=$PATH:/usr/local/workbench/bin_linux64

#make it work under singularity 
RUN ldconfig && mkdir -p /N/u /N/home /N/dc2 /N/soft

#https://wiki.ubuntu.com/DashAsBinSh 
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

WORKDIR /src
COPY . .

ENTRYPOINT ["python3", "/src/run.py"]
