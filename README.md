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
systemctl --user daemon-reload
```

```
systemctl --user enable steamlink
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
systemctl --user daemon-reload
```

```
systemctl --user enable set-volume
```

## Enable CEC

CEC a signal that we can send to TVs so that they know to switch to a specific source. Here we use it to automatically switch to the HDMI the RaspberryPi is connected to whenever an input from the controller is received.