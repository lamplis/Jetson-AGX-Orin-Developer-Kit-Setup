#!/bin/bash

set -e

# Define installation paths
INSTALL_DIR="/opt/cursor"
APPIMAGE_PATH="$INSTALL_DIR/cursor.AppImage"
ICON_PATH="$INSTALL_DIR/cursor-icon.png"
DESKTOP_ENTRY_PATH="/usr/share/applications/cursor.desktop"

# Create installation directory
sudo mkdir -p "$INSTALL_DIR"

# Download the latest ARM64 AppImage of Cursor IDE
echo "Downloading Cursor IDE AppImage..."
sudo wget -O "$APPIMAGE_PATH" "https://downloads.cursor.com/production/latest/linux/aarch64/Cursor-latest-aarch64.AppImage"

# Make the AppImage executable
sudo chmod +x "$APPIMAGE_PATH"

# Download Cursor icon
echo "Downloading Cursor icon..."
sudo wget -O "$ICON_PATH" "https://raw.githubusercontent.com/getcursor/cursor/main/assets/icon.png"

# Create a desktop entry for Cursor IDE
echo "Creating desktop entry..."
sudo bash -c "cat > $DESKTOP_ENTRY_PATH" <<EOL
[Desktop Entry]
Name=Cursor IDE
Exec=$APPIMAGE_PATH --no-sandbox
Icon=$ICON_PATH
Type=Application
Categories=Development;IDE;
EOL

# Update desktop database
sudo update-desktop-database

echo "Cursor IDE installation complete. You can launch it from the application menu."
