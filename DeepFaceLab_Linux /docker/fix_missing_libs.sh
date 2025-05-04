#!/usr/bin/env bash
set -e

# Where the libraries are expected
LIB_DIR="/usr/lib/aarch64-linux-gnu"

echo "[fix_missing_libs.sh] Checking and fixing missing libraries if needed..."

# Ensure the system knows about the library path
# echo "$LIB_DIR" > /etc/ld.so.conf.d/aarch64-libs.conf
# export LD_LIBRARY_PATH="$LIB_DIR:$LD_LIBRARY_PATH"
# ldconfig

# List of critical libs needed by DeepFaceLab and OpenCV
declare -A libs=(
    ["libavcodec"]="libavcodec.so.58"
    ["libavformat"]="libavformat.so.58"
    ["libavutil"]="libavutil.so.56"
    ["libswscale"]="libswscale.so.5"
    ["libopenblas"]="libopenblas.so.0"
    ["libcudnn.so.9.3.0"]="libcudnn.so.8"
    ["libopenblas"]="libcblas.so.3"

    #["libQt5Core"]="libQt5Core.so.5"
    #["libQt5Core"]="libQt5Core-9e162752.so.5.15.0"
    #["libQt5Gui"]="libQt5Gui.so.5"
    #["libQt5Gui"]="libQt5Gui-61c96aa3.so.5.15.0"
    #["libQt5Test"]="libQt5Test-32fc1c2a.so.5.15.0"
    #["libQt5Widgets"]="libQt5Widgets.so.5"
    #["libQt5Widgets"]="libQt5Widgets-b1296c1e.so.5.15.0"
    
    #["libtesseract-dev"]="libtesseract.so.4"
    #["liblept.so"]="liblept.so.5"
    #ln -sf libtesseract.so libtesseract.so.4
    #apt-get install --reinstall libtesseract4
    #apt-get install --reinstall liblept5

)

for name in "${!libs[@]}"; do
    real_lib="$LIB_DIR/${libs[$name]}"
    if [ ! -e "$real_lib" ]; then
        echo "  [WARN] Expected $real_lib not found, skipping..."
        continue
    fi

    for orphan in $(find $LIB_DIR -maxdepth 1 -name "${name}-*.so*" || true); do
        if [ ! -e "$orphan" ]; then
            echo "  [INFO] Creating missing symlink: $orphan -> $real_lib"
            ln -sf "$real_lib" "$orphan"
        fi
    done
done

echo "[fix_missing_libs.sh] Done."

