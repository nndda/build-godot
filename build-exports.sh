set -euo pipefail

# mv "$(realpath "${BASH_SOURCE[0]}")" "$RUNNER_TEMP" # wat

# Install dependencies
sudo apt-get update -qq
sudo apt-get install -qq -y \
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

if [[ "$EXPORT_ARCH" == "arm64" ]]; then

  sudo apt-get install -qq -y \
    clang \
    lld

  xtra_flags+=" use_llvm=yes"

fi

if [[ "$EXPORT_PLATFORM" == "windows" ]]; then
  echo "Updating POSIX..."
  sudo update-alternatives --set x86_64-w64-mingw32-gcc \
    /usr/bin/x86_64-w64-mingw32-gcc-posix
  sudo update-alternatives --set x86_64-w64-mingw32-g++ \
    /usr/bin/x86_64-w64-mingw32-g++-posix

  sudo update-alternatives --set i686-w64-mingw32-gcc \
    /usr/bin/i686-w64-mingw32-gcc-posix
  sudo update-alternatives --set i686-w64-mingw32-g++ \
    /usr/bin/i686-w64-mingw32-g++-posix

  echo "Installing Direct3D 12 driver..."
  python ./misc/scripts/install_d3d12_sdk_windows.py

  xtra_flags+=" use_mingw=yes"
fi

scons platform=$EXPORT_PLATFORM arch=$EXPORT_ARCH lto=full production=yes target=template_release debug_symbols=no $xtra_flags
