#!/usr/bin/env bash

set -euo pipefail



setup() {

  xtra_flags=""

  echo "::group::Installing core dependencies"

  # Install dependencies
  sudo apt-get update -qq
  sudo apt-get install -qqy \
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
    mingw-w64 \
    g++-multilib \
    gcc-multilib \
    unzip \
    curl

  curl \
    -fsSL https://github.com/ip7z/7zip/releases/download/26.00/7z2600-linux-x64.tar.xz \
    -o 7zip.tar.xz

  mkdir \
    -p "$RUNNER_TEMP/7zip/" && \
    tar \
      -xf 7zip.tar.xz \
      -C "$RUNNER_TEMP/7zip/"

  rm 7zip.tar.xz

  echo "::endgroup::"


  echo "::group::Cloning Godot $GODOT_VERSION source"

  git clone --quiet --no-progress --depth=1 --branch="$GODOT_VERSION" https://github.com/godotengine/godot.git .

  echo "::endgroup::"


  if [[ "$EXPORT_PLATFORM" == "android" ]]; then

    # echo "::group::Installing Android dependencies"

    echo "::group::Installing Java SDK"

    # sudo apt-get install -qqy \
    #   wget \
    #   apt-transport-https \
    #   gpg

    # wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
    #   gpg --dearmor | \
    #   sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null

    # echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
    #   sudo tee /etc/apt/sources.list.d/adoptium.list

    # sudo apt-get update -qq
    # sudo apt-get install -qqy temurin-17-jdk


    curl \
      -fsSL https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.18%2B8/OpenJDK17U-jdk_x64_linux_hotspot_17.0.18_8.tar.gz \
      -o javasdk.tar.gz

    mkdir \
      -p "$RUNNER_TEMP/java-sdk/" && \
      tar \
        -xf javasdk.tar.gz \
        -C "$RUNNER_TEMP/java-sdk/"

    rm javasdk.tar.gz

    export JAVA_HOME="$RUNNER_TEMP/java-sdk/jdk-17.0.18+8/"

    echo "::endgroup::"



    echo "::group::Installing Android SDK"

    curl \
      -fsSL https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip \
      -o commandlinetools.zip

    unzip commandlinetools.zip \
      -d "$RUNNER_TEMP/commandlinetools/"

    rm commandlinetools.zip

    # TODO: try --license

    yes | \
      # JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64/ \
      "$RUNNER_TEMP/commandlinetools/cmdline-tools/bin/sdkmanager" \
      --sdk_root="$RUNNER_TEMP/android-sdk/" \
        "platform-tools" \
        "build-tools;35.0.1" \
        "platforms;android-35" \
        "cmdline-tools;latest" \
        "cmake;3.10.2.4988404" \
        "ndk;28.1.13356709" \
    || true

    export ANDROID_HOME="$RUNNER_TEMP/android-sdk/"

    echo "::endgroup::"



    echo "::group::Installing Swappy Android"

    python ./misc/scripts/install_swappy_android.py

    echo "::endgroup::"

    # echo "::endgroup::"

    echo "JAVA_HOME=$JAVA_HOME" >> "$GITHUB_ENV"
    echo "ANDROID_HOME=$ANDROID_HOME" >> "$GITHUB_ENV"

  fi


  if [[ "$EXPORT_PLATFORM" == "windows" ]]; then

    echo "::group::Installing Direct3D 12 driver"

    python ./misc/scripts/install_d3d12_sdk_windows.py

    xtra_flags+=" d3d12=yes"

    echo "::endgroup::"

  fi


  echo "::group::Cloning Godot project"

  git clone --quiet --no-progress --depth=1 --branch="$GITHUB_REF_NAME" "https://github.com/$GITHUB_REPOSITORY.git" "$RUNNER_TEMP/godot-project/"

  # TODO: turn these two to args

  cp "$RUNNER_TEMP/godot-project/custom.py" . || true
  cp "$RUNNER_TEMP/godot-project/custom.gdbuild" . || true

  if [[ -f "custom.py" ]]; then
    echo "custom.py file detected..."
    xtra_flags+=" profile=custom.py"
  fi

  if [[ -f "custom.gdbuild" ]]; then
    echo "custom.gdbuild file detected..."
    xtra_flags+=" build_profile=custom.gdbuild"
  fi

  echo "::endgroup::"

  echo "EXTRA_FLAGS=$xtra_flags" >> "$GITHUB_ENV"

}



build() {

  export PATH="$RUNNER_TEMP/7zip/:$PATH"

  xtra_flags="$EXTRA_FLAGS"



  if [[ "$EXPORT_PLATFORM" == "windows" ]]; then

    echo "Updating POSIX..."

    xtra_flags+=" use_mingw=yes"

    case "$EXPORT_ARCH" in

      x86_64)
        sudo update-alternatives --set x86_64-w64-mingw32-gcc \
          /usr/bin/x86_64-w64-mingw32-gcc-posix
        sudo update-alternatives --set x86_64-w64-mingw32-g++ \
          /usr/bin/x86_64-w64-mingw32-g++-posix
        ;;

      x86_32)
        sudo update-alternatives --set i686-w64-mingw32-gcc \
          /usr/bin/i686-w64-mingw32-gcc-posix
        sudo update-alternatives --set i686-w64-mingw32-g++ \
          /usr/bin/i686-w64-mingw32-g++-posix
        ;;

    esac

  fi



  # if [[ "$EXPORT_TYPE" == "release" ]]; then

  #   xtra_flags+=" target=template_release production=yes debug_symbols=no lto=full dev_build=no"

  # else

  #   xtra_flags+=" target=template_debug"

  # fi



  if [[ "$EXPORT_PLATFORM" == "android" ]]; then

    # export JAVA_HOME="$RUNNER_TEMP/java-sdk/jdk-17.0.18+8/"
    # export ANDROID_HOME="$RUNNER_TEMP/android-sdk/"
    unset ANDROID_SDK_ROOT
    # xtra_flags+=" generate_android_binaries=yes"

    if [[ "$EXPORT_ARCH" == "arm32-arm64" ]]; then

      scons -j4 platform="$EXPORT_PLATFORM" arch=arm32 $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
      scons -j4 platform="$EXPORT_PLATFORM" arch=arm64 $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no generate_android_binaries=yes

      scons -j4 platform="$EXPORT_PLATFORM" arch=arm32 $xtra_flags target=template_debug
      scons -j4 platform="$EXPORT_PLATFORM" arch=arm64 $xtra_flags target=template_debug generate_android_binaries=yes

    else

      scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
      scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_debug generate_android_binaries=yes

    fi

  else

    scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
    # scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_debug

  fi

  # scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
  # scons -j4 platform="$EXPORT_PLATFORM" arch="$EXPORT_ARCH" $xtra_flags target=template_debug

  7zz a -t7z -mx=9 -m0=lzma2 -mfb=273 -md=256m -mmt=4 -ms=on "$EXPORT_PLATFORM-$EXPORT_ARCH.7z" "./bin/*" -xr!obj -xr!build_deps
  # 7zz a -t7z -mx=9 -m0=lzma2 -mfb=273 -md=256m -mmt=4 -ms=on "$EXPORT_PLATFORM-$EXPORT_TYPE-$EXPORT_ARCH.7z" "./bin/*" -xr!obj -xr!build_deps

}


case "$1" in
  setup)
    setup
    ;;
  build)
    build
    ;;
esac

