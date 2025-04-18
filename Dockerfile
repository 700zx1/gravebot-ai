FROM python:3.11-slim

# Install build deps + espeak-ng build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential python3.11-dev libsndfile1 libsndfile1-dev \
      portaudio19-dev libportaudio2 ffmpeg rustc cargo git \
      autoconf automake libtool pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build and install eSpeak-NG
RUN git clone --depth 1 https://github.com/espeak-ng/espeak-ng.git /tmp/espeak-ng \
 && cd /tmp/espeak-ng \
 && ./autogen.sh \
 && ./configure --prefix=/usr/local \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /tmp/espeak-ng

WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt

COPY . .
