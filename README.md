# `lgtv_saver`

Got an LG OLED TV hooked up to your PC?  Worried about screen burn-in?  Can't rely on the screensaver or power settings?  Then this script has you covered.

## Why?

I recently upgraded to an LG OLED TV as a monitor for my Windows gaming PC.  I also use OBS to capture game replays, and I have it always running a replay buffer, similar to (and as a much better replacement for) Nvidia's "ShadowPlay" tool.

However, OBS unfortunately disables the screensaver and all power saving features.  I can't find any way around that — nobody responded to [my request to add an option to allow screensavers](https://obsproject.com/forum/threads/can-we-have-an-option-to-allow-screensavers.130777/), and a quick browsing of the source code didn't turn up anything I could easily disable.

To avoid mishaps where I accidentally leave my PC looking at a static screen — or worse, a screen that's mostly static, but just active enough to prevent LG's automatic dimming — I decided to come up with a more direct solution.

## How?

When your computer is idle for too long, `lgtv_saver` will switch to a different input — ideally an unused one (so you get the "no signal" screen), or one displaying a black screen.

When your computer becomes active again, it will automatically switch back.  (It also tracks manual input changes, so it won't change back if you've changed to a different input in the mean time.)

To track idle activity, it sets up a UDP port listener.  You should regularly send your current idle time (in milliseconds) as packets to that port.  This can be done via various scripting utilities, such as AutoHotKey, PowerShell, etc.

Because it uses UDP packets to track idle time, you can put `lgtv_saver` on any computer on your network — an always-on server, a Raspberry Pi, etc — and you can use any OS for your workstation computer.  And if your workstation stops sending activity updates, `lgtv_saver` will assume it's inactive and protect your screen accordingly.

## Server setup

1. Run `mix deps.get && mix deps.compile` to fetch and compile dependencies.
2. Edit `config/config.exs` to match your setup.
  * You'll definitely need to update the TV's IP.
  * I use `HDMI_4` as my "screensaver" input — and in fact, I've named it "Screensaver" on the TV itself — but you can change this to any other input.
  * The default configuration only defines a single `HDMI_1` workstation input by default, but you can define as many as you like, bound to different UDP ports, and each with their own idle timeout (in seconds).
3. Run `mix run --no-halt` to launch `lgtv_saver`.

The first time you run this, your TV will prompt you to let the program control the TV; you'll need to accept this before you can continue.

## Client setup

Without any activity info from any workstations, the TV will switch to your configured `saver_input` as soon as `idle_time` seconds have passed.  To keep this from happening, you'll need to set up some means to report user activity to the server.

### Example: `socat`

One easy way to mark your system as active is just to send a simple `0` ("I'm active now") via UDP.  You can use `socat` to send this:

```sh
# Pretend the console is active:
echo 0 | socat STDIO UDP-SENDTO:127.0.0.1:3232
# Or pretend it's been inactive for a whole day:
echo 86400000 | socat STDIO UDP-SENDTO:127.0.0.1:3232
```

Or alternatively, netcat:

```sh
# Pretend the console is active:
echo 0 | nc -u 127.0.0.1 3232
# Or pretend it's been inactive for a whole day:
echo 86400000 | nc -u 127.0.0.1 3232
```

These can be useful as part of a wake-on-LAN script — see [`scripts/wakeup.sh`](scripts/wakeup.sh) for an example.

### On Windows

#### AutoHotKey

The [`scripts/ahk`](scripts/ahk) directory contains AutoHotKey scripts that can be used as clients on Windows systems:

 * [`scripts/ahk/lgtv_saver.ahk`](scripts/ahk/lgtv_saver.ahk) — Regularly reports keyboard and mouse idle time.
 * [`scripts/ahk/lgtv_saver_wakeup.ahk`](scripts/ahk/lgtv_saver_wakeup.ahk) — Set up Task Scheduler to run this on boot, before the login screen.  It will wake up the screen so you can log in.
 * [`scripts/ahk/lgtv_keepalive.ahk`](scripts/ahk/lgtv_keepalive.ahk) — If you plan to idle for a while but don't want the screensaver kicking in, run this to pretend the system is active.  (Running this script will automatically kill `lgtv_saver.ahk`, and running `lgtv_saver.ahk` automatically kills this script in return.)

You'll want to edit these to change the server IP and port, and you'll also probably want to compile them to executables (right click on the file and select "Compile script") to make them portable and easier to use.

#### DS4Windows

These scripts cover mouse and keyboard activity, but what about gamepads?  Using a gamepad typically means not touching the keyboard or mouse, which causes AutoHotKey to report to the server that you're idle, and (usually at some critical moment) the screensaver kicks in and your screen goes blank.

While you can use `lgtv_keepalive.ahk` to prevent this, there is an easier way, as long as you're using a PS4 or PS5 controller.  [DS4Windows](https://ds4-windows.com/) is a software suite that lets you do a bunch of things with PlayStation controllers, including sending all controller activity over the network — and `lgtv_saver` can be set up to listen for this network traffic.

To use this, make sure you configure `ds4_port` in the appropriate `bindings` config section.  Then, in DS4Windows' configuration, check off "enable OSC server" and "send realtime data", and input the IP and port of your `lgtv_saver` server.

Any traffic received this way will mark the system as active (overriding the idle time reported by AutoHotKey), so you should now be able to seamlessly switch between keyboard & mouse or gamepad without needing to remember to enable the `lgtv_keepalive.ahk`.

### On Mac / Linux

I don't currently have a solution for reporting Mac and Linux idle time to `lgtv_saver`.  If you come up with something, please feel free to [create an issue / PR!](../../issues/new)

## Waking up from power off

If you leave your TV on a "no signal" input for very long, it's going to automatically turn off.  When the workstation becomes active, you probably want the TV to turn back on and return to that input, so `lgtv_saver` tries to resolve this in one of two ways.

If an input becomes active and `lgtv_saver` thinks the TV has turned off (based on the data it received previously), it will try to issue a power button event.  Since the TV seems to wait several minutes before actually powering off, this may be sufficient to wake the TV up, if it hasn't completely powered off.  (There is a slight risk that this might actually turn the TV off — see [Caveats](#caveats) below.)

Alternatively, you can enable wake-on-LAN support on your TV.  On my 48" CX TV, I found this setting under Settings → Connection → Mobile Connection Management → TV On With Mobile → Turn on via Wi-Fi.  (Yes, this setting applies even if you're using an ethernet cable.)

With wake-on-LAN enabled, the TV will actually power off much quicker (almost immediately), but `lgtv_saver` now has the ability to wake it up from a power off state.  Find your TV's broadcast address — punch your TV's details into [this IP calculator tool](http://jodies.de/ipcalc?host=192.168.2.118&mask1=255.255.255.0&mask2=) if you're unsure — and plug the MAC address and broadcast address into `config/config.exs`.

If you've set up your workstation to send activity immediately upon booting up (e.g. before logging in — see the "[`wakeup.sh`](scripts/wakeup.sh)" script in `examples`) then this also has the added advantage of turning your TV on when your workstation boots up, provided the TV was last set to that workstation.

## Caveats

When the TV is in the "half powered down" state — where the TV appears off, but the OS and network stack are still functional — the only way I know to wake it up is to simulate a power button event.  Of course, if `lgtv_saver` has misunderstood the state of the TV, this might actually end up turning it off.

If you find your TV turning off unexpectedly, search for `turn_off` in `lib/lgtv_saver/tv.ex` and try commenting out that line.  If that fixes your problem, feel free to let me know by [creating an issue](../../issues/new).

## Legal stuff

Copyright © 2023, Adrian Irving-Beer.

`lgtv_saver` is released under the [Apache 2 License](LICENSE) and is provided with **no warranty**.  I do my best to write secure and resilient code, but I'm not liable if things break.  Be careful with your TV, and don't expose your UDP ports to the internet.
