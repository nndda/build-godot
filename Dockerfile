FROM ubuntu:22.04

WORKDIR /godot-project

SHELL [ "/bin/bash", "-c" ]

RUN apt update && \
    apt install -y --no-install-recommends \
    git \
    build-essential \
    scons \
    pkg-config \
    libx11-dev \
    libxcursor-dev \
    libxinerama-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libasound2-dev \
    libpulse-dev \
    libudev-dev \
    libxi-dev \
    libxrandr-dev \
    libwayland-dev \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    curl \
    p7zip-full \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3 /usr/bin/python

# Godot source

RUN git clone \
    --quiet \
    --no-progress \
    --depth=1 \
    --branch=4.7-stable \
    https://github.com/godotengine/godot.git /godot-project/src-godot/

# JDK

RUN mkdir --parents /usr/share/sdk/java \
  && curl --fail --location https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.18%2B8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.18_8.tar.gz \
  | tar -xzC /usr/share/sdk/java

ENV JAVA_HOME="/usr/share/sdk/java/jdk-17.0.18+8"

# Android SDK

RUN \
  mkdir --parents /usr/share/sdk/commandlinetools \
  && curl \
    --fail --location https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip \
    -o commandlinetools.zip \
  && unzip commandlinetools.zip \
    -d "/usr/share/sdk/commandlinetools/" \
  && rm commandlinetools.zip \
  && yes | \
    /usr/share/sdk/commandlinetools/cmdline-tools/bin/sdkmanager \
    --sdk_root=/usr/share/sdk/android/ \
      "platform-tools" \
      "build-tools;35.0.1" \
      "platforms;android-35" \
      "cmdline-tools;latest" \
      "cmake;3.10.2.4988404" \
      "ndk;28.1.13356709" \
      --licenses

RUN python /godot-project/src-godot/misc/scripts/install_swappy_android.py

ENV ANDROID_HOME="/usr/share/sdk/android/"
ENV ANDROID_SDK_ROOT=

# Windows

RUN python /godot-project/src-godot/misc/scripts/install_d3d12_sdk_windows.py
