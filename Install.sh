#!/bin/bash
# ==============================================================================
# Tool Name:    Automated Installer for Flatpak Uninstaller
# Description:  Deploys the uninstaller script to global binaries, creates the 
#               desktop menu item, and makes everything executable.
# ==============================================================================

echo "👀 Verifying file presence..."

# Ensure the uninstaller script actually exists in the current directory
if [ ! -f "flatpak-uninstaller.sh" ]; then
    echo "❌ Error: 'flatpak-uninstaller.sh' not found in this folder."
    echo "Please make sure you are running this script from the directory containing your uninstaller."
    exit 1
fi

echo "🚀 Starting installation..."

# 1. Copy the uninstaller script to the global binary path
echo "📦 Copying uninstaller engine to /usr/local/bin..."
sudo cp flatpak-uninstaller.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/flatpak-uninstaller.sh

# 2. Automatically generate the clean desktop entry in the user's applications folder
echo "🖥️  Creating desktop application menu shortcut..."
APPS_DIR="$HOME/.local/share/applications"
LAUNCHER_FILE="$APPS_DIR/flatpak-uninstaller.desktop"

mkdir -p "$APPS_DIR"

cat << EOF > "$LAUNCHER_FILE"
[Desktop Entry]
Type=Application
Name=Flatpak Uninstaller
Comment=Cleanly remove Flatpak applications with a progress bar
Exec=/usr/local/bin/flatpak-uninstaller.sh
Icon=system-software-install
Terminal=false
Categories=System;Settings;
EOF

# Make the desktop entry shortcut executable by the system
chmod +x "$LAUNCHER_FILE"

# 3. Force the desktop database to refresh and notice the new app
echo "⚙️  Refreshing application menu registry..."
update-desktop-database "$APPS_DIR"

echo "✅ Installation successful! You can now launch the 'Flatpak Uninstaller' directly from your application menu."
