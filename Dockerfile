FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3.11-dev \
    libsndfile1 libsndfile1-dev \
    portaudio19-dev libportaudio2 \
    ffmpeg rustc cargo git \
    autoconf automake libtool pkg-config \
    alsa-utils libasound2-dev \
    python3-pip \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install espeak-ng
RUN git clone --depth 1 https://github.com/espeak-ng/espeak-ng.git /tmp/espeak-ng \
    && cd /tmp/espeak-ng \
    && ./autogen.sh \
    && ./configure --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/espeak-ng

WORKDIR /app

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Set up audio group and permissions
RUN usermod -a -G audio root

# Set the entrypoint
#ENTRYPOINT ["python", "gravebot_ai.py"]
ENTRYPOINT ["/bin/bash"]