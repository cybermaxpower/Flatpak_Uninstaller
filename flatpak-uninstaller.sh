#!/bin/bash
# ==============================================================================
# Tool Name:    Flatpak Uninstaller
# Description:  A graphical utility to browse, select, and cleanly uninstall
#               Flatpak applications (both User and System scopes) via Zenity.
# Usage:        flatpak-uninstaller.sh
# ==============================================================================

export GDK_BACKEND=wayland,x11
export GSK_RENDERER=cairo
export LC_ALL=C

# ==============================================================================
# 1. FRONT-LOADED DISCLAIMER & WARNING
# Pure plain-text execution to completely eliminate GTK window parsing crashes.
# ==============================================================================

zenity --question --title="Flatpak Uninstaller Disclaimer" --icon-name=dialog-warning --text="WARNING: IMPORTANT SAFETY DISCLAIMER\n\nThis utility is provided 'as is'. While removing Flatpaks is completely safe for your core operating system, uninstalling packages will permanently delete local user settings, configurations, or saved data files associated with that application.\n\nDo you wish to proceed responsibly?" --width=450

if [ $? -ne 0 ]; then
    echo "User declined disclaimer. Exiting."
    exit 0
fi

# Temporary files to hold raw data
LIST_DATA=$(mktemp)
UNINSTALL_LOG=$(mktemp)

# Cleanup on exit
trap 'rm -f "$LIST_DATA" "$UNINSTALL_LOG"' EXIT

# 2. Fetch installed flatpaks into a readable format for Zenity
flatpak list --columns=name,application,installation | tail -n +1 > "$LIST_DATA"

# If nothing is installed, tell the user and exit safely
if [ ! -s "$LIST_DATA" ] || [ "$(cat "$LIST_DATA" | wc -l)" -le 0 ]; then
    zenity --info --title="Flatpak Uninstaller" --text="No Flatpak applications detected on your system." --width=350
    exit 0
fi

# 3. Build the dynamic Zenity list box
ZENITY_ARGS=(
    --list --radiolist
    --title="Flatpak Uninstaller"
    --text="Select an application to uninstall from your system:"
    --width=800 --height=450
    --column="Select" --column="Application Name" --column="Application ID" --column="Scope"
)

# Parse our flatpak list file into Zenity arguments
while IFS=$'\t' read -r name id scope; do
    [ -z "$name" ] && continue
    ZENITY_ARGS+=(FALSE "$name" "$id" "$scope")
done < "$LIST_DATA"

# Launch the selection window
SELECTED_ROW=$(zenity "${ZENITY_ARGS[@]}")

# Exit if user hits Cancel or doesn't select anything
if [ $? -ne 0 ] || [ -z "$SELECTED_ROW" ]; then
    echo "Uninstallation cancelled by user."
    exit 0
fi

# Extract the Application ID and Scope cleanly using the selected Name
APP_NAME="$SELECTED_ROW"
APP_ID=$(grep "^$APP_NAME"$'\t' "$LIST_DATA" | cut -f2)
APP_SCOPE=$(grep "^$APP_NAME"$'\t' "$LIST_DATA" | cut -f3)

# Configure the correct scope flags based on where it was found
if [ "$APP_SCOPE" = "system" ]; then
    SCOPE_FLAG="--system"
else
    SCOPE_FLAG="--user"
fi

# 4. Final Quick Confirmation
zenity --question \
    --title="Confirm Target" \
    --text="Are you sure you want to remove $APP_NAME from your $APP_SCOPE environment?" \
    --width=420

if [ $? -ne 0 ]; then
    exit 0
fi

# 5. RUN UNINSTALLER WITH LIVE STREAM PROGRESS BAR
flatpak uninstall $SCOPE_FLAG -y --noninteractive "$APP_ID" 2>&1 | tr '\r' '\n' | tee "$UNINSTALL_LOG" | while read -r line; do
    [ -z "$line" ] && continue
    
    if [[ "$line" == *"Uninstalling"* || "$line" == *"Removing"* ]]; then
        echo "50"
        echo "# Purging execution variables and shortcuts..."
    elif [[ "$line" == *"Removing unused"* || "$line" == *"Cleaning"* ]]; then
        echo "75"
        echo "# Scrubbing detached configurations..."
    fi
done | zenity --progress \
    --title="Removing Flatpak" \
    --text="Deconstructing application environment..." \
    --percentage=10 \
    --auto-close \
    --no-cancel \
    --width=470

UNINSTALL_EXIT_STATUS=${PIPESTATUS[0]}

# 6. POST-UNINSTALL VALIDATION
if [ $INSTALL_EXIT_STATUS=$UNINSTALL_EXIT_STATUS ]; then
    # Clean up leftover unused runtime runtimes to save storage space automatically
    flatpak uninstall --unused -y --noninteractive >/dev/null 2>&1
    
    zenity --info --title="Success" --text="Application has been cleanly wiped from your system!" --width=380
    exit 0
else
    ERROR_MSG=$(cat "$UNINSTALL_LOG" | tail -n 2)
    zenity --error --title="Uninstallation Failed" --text="The engine hit an error trying to remove the package.\n\nDetails:\n$ERROR_MSG" --width=420
    exit 1
fi
