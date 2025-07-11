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