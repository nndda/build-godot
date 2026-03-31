set -euo pipefail

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


curl -L https://github.com/ip7z/7zip/releases/download/26.00/7z2600-linux-x64.tar.xz -o 7zip.tar.xz
mkdir -p "$RUNNER_TEMP/7zip/" && tar -xf 7zip.tar.xz -C "$RUNNER_TEMP/7zip/"
export PATH="$RUNNER_TEMP/7zip/:$PATH"
rm 7zip.tar.xz

xtra_flags=""


git clone --quiet --no-progress --depth=1 --branch="$GODOT_VERSION" https://github.com/godotengine/godot.git .
git clone --quiet --no-progress --depth=1 --branch="$GITHUB_REF_NAME" https://github.com/$GITHUB_REPOSITORY.git "$RUNNER_TEMP/godot-project/"


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


if [[ "$EXPORT_PLATFORM" == "android" ]]; then

  sudo apt-get install -qqy \
    wget \
    apt-transport-https \
    gpg

  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
  echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
  sudo apt-get update -qq
  sudo apt-get install -qqy temurin-17-jdk

  curl https://dl.google.com/android/repository/commandlinetools-linux-14742923_latest.zip -o commandlinetools.zip
  unzip commandlinetools.zip -d "$RUNNER_TEMP/commandlinetools/"
  rm commandlinetools.zip
  yes | JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64 "$RUNNER_TEMP/commandlinetools/cmdline-tools/bin/sdkmanager" --sdk_root="$RUNNER_TEMP/android-sdk/" "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmdline-tools;latest" "cmake;3.10.2.4988404" "ndk;28.1.13356709" || true

  export ANDROID_HOME="$RUNNER_TEMP/android-sdk/"

  python ./misc/scripts/install_swappy_android.py

fi


# if [[ "$EXPORT_ARCH" == "arm64" ]]; then

#   sudo apt-get install -qq -y \
#     clang \
#     mingw-w64 \
#     lld

#   xtra_flags+=" use_llvm=yes"

# fi


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

  echo "Installing Direct3D 12 driver..."
  python ./misc/scripts/install_d3d12_sdk_windows.py

  xtra_flags+=" d3d12=yes"

fi

if [[ "$EXPORT_TYPE" == "release" ]]; then

  xtra_flags+=" target=template_release production=yes debug_symbols=no lto=full"

else

  xtra_flags+=" target=template_debug production=no debug_symbols=yes lto=none"

fi


if [[ "$EXPORT_PLATFORM" == "android" ]]; then

  scons -j4 platform=$EXPORT_PLATFORM arch=$EXPORT_ARCH $xtra_flags generate_android_binaries=yes

else

  scons -j4 platform=$EXPORT_PLATFORM arch=$EXPORT_ARCH $xtra_flags

fi

7zz a -t7z -mx=9 -m0=lzma2 -mfb=273 -md=256m -mmt=4 -ms=on "$EXPORT_PLATFORM-$EXPORT_ARCH.7z" "./bin/" -xr!obj -xr!build_deps
