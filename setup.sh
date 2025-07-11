#!/bin/bash

# This script automates the setup of Steam Link on a Raspberry Pi
# as described in the user's guide.
#
# It must be run on a Raspberry Pi that already has Raspberry Pi OS installed.
#
# Usage:
# curl -sSL [URL_TO_THIS_SCRIPT] | sudo bash

echo "--- Starting Steam Link Setup for user: $USER ---"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run this script with sudo: curl ... | sudo bash"
  exit 1
fi

# --- 1. Install Dependencies ---
echo "⚙️ Installing Steam Link, CEC Utils, and Python EVDEV..."
apt update
apt install steamlink cec-utils python3-evdev -y

# --- 2. Set Steam Link to Autostart ---
echo "⚙️ Creating autostart service for Steam Link..."
loginctl enable-linger $USER

mkdir -p /home/$USER/.config/systemd/user

cat <<EOF > /home/$USER/.config/systemd/user/steamlink.service
[Unit]
Description=Steam Link (User Service)
After=graphical-session.target

[Service]
ExecStart=/usr/bin/steamlink
Restart=always
RestartSec=1
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=PULSE_RUNTIME_PATH=/run/user/1000/pulse
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# --- 3. Set Volume to Max on Boot ---
echo "⚙️ Creating service to set volume to 100%..."
cat <<EOF > /home/$USER/.config/systemd/user/set-volume.service
[Unit]
Description=Set HDMI volume to 100%
After=default.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pactl set-sink-volume 0 100%

[Install]
WantedBy=default.target
EOF

# Fix ownership of user config files
chown -R $USER:$USER /home/$USER/.config

# Enable user services
sudo -u $USER systemctl --user daemon-reload
sudo -u $USER systemctl --user enable steamlink
sudo -u $USER systemctl --user enable set-volume

echo "✅ User services enabled."

# --- 4. Disable Wi-Fi Power Saving ---
echo "⚙️ Creating service to disable Wi-Fi power management..."
cat <<EOF > /etc/systemd/system/wifi-powermanagement-off.service
[Unit]
Description=Disable WiFi Power Management

[Service]
Type=oneshot
ExecStart=/sbin/iw dev wlan0 set power_save off

[Install]
WantedBy=multi-user.target
EOF

# --- 5. Enable CEC Wakeup Script ---
echo "⚙️ Creating CEC wakeup script and service..."
mkdir -p /home/$USER/cec-utils

# Create the Python script
cat <<'EOF' > /home/$USER/cec-utils/cec_wakeup.py
import os
import time
from evdev import InputDevice, list_devices, ecodes

# --- Configuration ---
CEC_COMMAND = "echo 'as' | cec-client -s -d 1"
# How many seconds to wait before another CEC signal can be sent.
# Prevents spamming the TV.
COOLDOWN_SECONDS = 30
RESCAN_INTERVAL = 10
# --- End Configuration ---

# A global variable to track when the last command was sent.
last_sent_time = 0


def find_gamepads():
    """Scans for and returns a list of connected gamepad devices."""
    try:
        devices = [InputDevice(path) for path in list_devices()]
        gamepads = [dev for dev in devices if dev.capabilities().get(ecodes.EV_KEY) and (
            ecodes.BTN_GAMEPAD in dev.capabilities()[ecodes.EV_KEY] or
            ecodes.BTN_A in dev.capabilities()[ecodes.EV_KEY]
        )]
        return gamepads
    except Exception as e:
        print(f"Error listing devices: {e}")
        return []


if __name__ == "__main__":
    print("Smart Timer CEC Service Started.")
    while True:
        gamepads = find_gamepads()

        if not gamepads:
            print(f"No gamepads found. Re-scanning in {RESCAN_INTERVAL} seconds...")
            time.sleep(RESCAN_INTERVAL)
            continue

        print(f"Listening for input on: {[dev.name for dev in gamepads]}")

        for gamepad in gamepads:
            try:
                print(f"--- Now listening continuously on {gamepad.name} ---")
                for event in gamepad.read_loop():
                    if (event.type == ecodes.EV_KEY or
                       (event.type == ecodes.EV_ABS and abs(event.value) > 128)):

                        # --- NEW TIMER LOGIC ---
                        current_time = time.time()
                        if (current_time - last_sent_time) > COOLDOWN_SECONDS:
                            print(f"Input on {gamepad.name}. Cooldown has passed. Sending CEC command.")
                            os.system(CEC_COMMAND)
                            # Update the time the last command was sent.
                            last_sent_time = current_time

            except (OSError, IOError) as e:
                print(f"Controller '{gamepad.name}' disconnected or caused an error: {e}")
                break
EOF

chown -R $USER:$USER /home/$USER/cec-utils

# Create the systemd service for the CEC script
cat <<EOF > /etc/systemd/system/cec-wakeup.service
[Unit]
Description=Smart Timer CEC Controller Service
After=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/python3 /home/$USER/cec-utils/cec_wakeup.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- 6. Enable System Services ---
echo "⚙️ Reloading daemons and enabling system services..."
systemctl daemon-reload
systemctl enable wifi-powermanagement-off.service
systemctl enable cec-wakeup.service

echo "✅ All steps complete! Please reboot the Raspberry Pi for all changes to take effect."