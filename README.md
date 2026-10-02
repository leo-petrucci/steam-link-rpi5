# Steam Link on RaspberryPi

This is a guide on how to get the best experience out of installing Steam Link on a RaspberryPi. The aim is to get it to be as close as possible to the original Steam Link hardware.

## Why?

The original Steam Link hardware is now almost 10 years old, and while in many cases it still works perfectly fine it is definitely starting to show its age. Specifically the Steam Link:

- struggles with high hz controller inputs
- is unable to process higher than 1080p 60fps video
- doesn't support 6ghz Wi-Fi bands
- is getting harder to find!

The RaspberryPi 5 on the other hand is a great little machine and while installing the Steam Link app is very straight forward there's a lot that can be improved regarding the experience of using it.

## About the RaspberryPi

If you're not familiar with the RaspberryPi it's quite simple: It's a small all-in-one power efficient computer. It runs Linux and can be used for a variety of things. Many people use it as a home server, but in our case we'll just keep it connected to our TV like a console.

## What do you need?

- [A RaspberryPi 5](https://www.raspberrypi.com/products/raspberry-pi-5/). 2GB of ram is more than enough.
- A mouse and keyboard for setup
    - Unless you know how to use SSH
- A Micro HDMI to whatever-your-tv-uses cable
- An SD card
    - Even something as small as 8GB will be fine
- Something to plug your SD card into your PC/Laptop

## Setting up the Raspberry Pi 

I recommend following this guide. The setup looks exactly the same. 

> [!CAUTION]
> As of the 11 July 2025 an automatic update to something completely unrelated to Steam Link causes video to stop sharing. When the RaspberryPi asks you to "Update Software" **MAKE SURE TO SKIP IT**

https://www.youtube.com/watch?v=DRJAILbqjy0

## Using the terminal

A lot of these changes must be made using a terminal, I know it sounds daunting but it's mostly copy-pase! 

You can find the terminal from your start menu or by pressing CTRL + ALT + T.

## Installing Steam Link

Installing Steam Link is very straight forward. 

```
sudo apt install steamlink
```

## Setting Steam Link to autostart

In the terminal run:

```
sudo loginctl enable-linger $USER
```

Then create a folder:

```
mkdir -p ~/.config/systemd/user
```

Open an editor for the service file:

```
nano ~/.config/systemd/user/steamlink.service
```

Then paste:

```
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
```

> [!TIP]
> The Steam Link app can be closed by pressing ESC or B. If you don't have a controller connected it can be difficult to restart it. So to ensure its **ALWAYS** open we include `Restart=always` which will reopen the app after it's been closed.

Then to activate this run:

```
systemctl --user daemon-reload && systemctl --user enable steamlink
```

## Run Steam Link in a fullscreen session with Cage

The desktop autostart above runs Steam Link on the normal desktop. To use a clean, single-app Wayland session instead, run Steam Link with Cage. Cage fills the display with one application. Kanshi sets the display mode.

This setup follows the [Raspberry Pi forum instructions](https://forums.raspberrypi.com/viewtopic.php?p=2345558#p2345558). The forum recommends Kanshi instead of `wlr-randr` for display mode management.

Install Cage and Kanshi:

```
sudo apt install cage kanshi
```

Create a Kanshi profile. Change the output, resolution, and refresh rate to values supported by your display:

```
mkdir -p ~/.config/kanshi
nano ~/.config/kanshi/config
```

For example:

```
profile {
    output HDMI-A-1 enable mode 1920x1080@60.000 position 0,0 transform normal
}
```

Create a script that starts Kanshi and restarts Steam Link if it exits:

```
mkdir -p ~/steamlink-utils
nano ~/steamlink-utils/steamlink-cage.sh
```

Paste this script:

```
#!/bin/bash

kanshi &
sleep 5
while true; do
        steamlink
        sleep 5
done
```

Make the script executable:

```
chmod +x ~/steamlink-utils/steamlink-cage.sh
```

Create a system service so Cage can start on the console terminal at boot:

```
sudo nano /etc/systemd/system/steamlink-cage.service
```

Paste this service. Change `leonardo` if your Linux user has a different name:

```
[Unit]
Description=Steam Link Kiosk (Cage on tty1)
After=systemd-logind.service network-online.target
Wants=network-online.target
Conflicts=getty@tty1.service

[Service]
User=leonardo
Group=leonardo
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
StandardInput=tty
StandardOutput=journal
StandardError=journal
PAMName=login
Environment=XDG_RUNTIME_DIR=/run/user/%U
WorkingDirectory=/home/leonardo
ExecStart=/usr/bin/cage -s /home/leonardo/steamlink-utils/steamlink-cage.sh
Restart=always
RestartSec=3
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
```

If you enabled the desktop user service above, disable it so it does not start a second Steam Link process:

```
systemctl --user disable --now steamlink.service
```

Enable and start the Cage service:

```
sudo systemctl daemon-reload
sudo systemctl enable --now steamlink-cage.service
```

## Set volume to max

By default the volume of your Rpi will be at 40%. Just in case something causes it to reset, we'll create a service that sets it to max, that way you can just adjust the volume from your TV. Run:

```
nano ~/.config/systemd/user/set-volume.service
```

Then paste:
```
[Unit]
Description=Set HDMI volume to 100%
After=default.target

[Service]
Type=oneshot
ExecStart=/usr/bin/pactl set-sink-volume 0 100%

[Install]
WantedBy=default.target
```

Then to activate this run:
```
systemctl --user daemon-reload && systemctl --user enable set-volume
```


## Disable Wi-Fi power saving

The RaspberryPi comes with a powersaving mode for Wi-Fi. If you're planning to use Steam Link on Wi-Fi then disabling powersaving is a must to get a good stream. Run:

```
sudo nano /etc/systemd/system/wifi-powermanagement-off.service
```

Then paste:
```
[Unit]
Description=Disable WiFi Power Management

[Service]
Type=oneshot
ExecStart=/sbin/iw dev wlan0 set power_save off

[Install]
WantedBy=multi-user.target
```

Then run:
```
sudo systemctl daemon-reload && sudo systemctl enable wifi-powermanagement-off.service
```

## Enable CEC

CEC a signal that we can send to TVs so that they know to turn on or switch to a specific source . Here we use it to automatically switch to the HDMI the RaspberryPi is connected to whenever an input from the controller is received.

This is by no means necessary, but I find it makes the UX much better.

Install:
```
sudo apt install cec-utils -y
```

Then:
```
sudo apt install python3-evdev
```

Then create the service:
```
sudo nano /etc/systemd/system/cec-wakeup.service
```

Paste:
```
[Unit]
Description=Smart Timer CEC Controller Service
After=network-online.target

[Service]
Type=simple
User=leonardo
ExecStart=/usr/bin/python3 /home/leonardo/cec-utils/cec_wakeup.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then we're actually going to create the script itself:
```
mkdir ~/cec-utils && nano ~/cec-utils/cec_wakeup.py
```

Then paste:
```
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
                        #else:
                        #    remaining_time = COOLDOWN_SECONDS - (current_time - last_sent_time)
                        #    print(f"Input on {gamepad.name}. In cooldown. Ignoring for {remaining_time:.1f} more seconds.")

            except (OSError, IOError) as e:
                print(f"Controller '{gamepad.name}' disconnected or caused an error: {e}")
                break
```

> [!NOTE]
> The above script constantly listens for controller buttons being pressed. Won't work for mouse or keyboard. If you know what you're doing feel free to modify it!

Then we'll enable it:
```
sudo systemctl daemon-reload && sudo systemctl enable cec-wakeup.service
```
