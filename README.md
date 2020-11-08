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

## Setup

1. Run `mix deps.get && mix deps.compile` to fetch and compile dependencies.
2. Edit `config/config.exs` to match your setup.
  * You'll definitely need to update the TV's IP.
  * I use `HDMI_4` as my "screensaver" input — and in fact, I've named it "Screensaver" on the TV itself — but you can change this to any other input.
  * The default configuration only defines a single `HDMI_1` workstation input by default, but you can define as many as you like, bound to different UDP ports, and each with their own idle timeout (in seconds).
3. Run `mix run --no-halt` to launch `lgtv_saver`.

The first time you run this, your TV will prompt you to let the program control the TV; you'll need to accept this before you can continue.

Without any activity info from any workstations, the TV will likely switch to `HDMI_4` (or your configured input) as soon as `idle_time` seconds have passed.  You can send some sample input to test it if you like.  For example, using the excellent `socat` utility:

```sh
# Pretend the console is active:
echo 0 | socat STDIO UDP-SENDTO:127.0.0.1:3232
# Or pretend it's been inactive for a whole day:
echo 86400000 | socat STDIO UDP-SENDTO:127.0.0.1:3232
# Remember to change the IP and port as needed!
```

Now you'll want to set up your client system to send activity info.  See the `examples` directory for how you might do this.

## Waking up from power off

If you leave your TV on a "no signal" input for very long, it's going to automatically turn off.  When the workstation becomes active, you probably want the TV to turn back on and return to that input, so `lgtv_saver` tries to resolve this in one of two ways.

If an input becomes active and `lgtv_saver` thinks the TV has turned off (based on the data it received previously), it will try to issue a power button event.  Since the TV seems to wait several minutes before actually powering off, this may be sufficient to wake the TV up, if it hasn't completely powered off.  (There is a slight risk that this might actually turn the TV off — see [Caveats](#caveats) below.)

Alternatively, you can enable wake-on-LAN support on your TV.  On my 48" CX TV, I found this setting under Settings → Connection → Mobile Connection Management → TV On With Mobile → Turn on via Wi-Fi.  (Yes, this setting applies even if you're using an ethernet cable.)

With wake-on-LAN enabled, the TV will actually power off much quicker (almost immediately), but `lgtv_saver` now has the ability to wake it up from a power off state.  Find your TV's broadcast address — punch your TV's details into [this IP calculator tool](http://jodies.de/ipcalc?host=192.168.2.118&mask1=255.255.255.0&mask2=) if you're unsure — and plug the MAC address and broadcast address into `config/config.exs`.

If you've set up your workstation to send activity immediately upon booting up (e.g. before logging in — see the "wakeup" scripts in `examples`) then this also has the added advantage of turning your TV on when your workstation boots up, provided the TV was last set to that workstation.

## Caveats

When the TV is in the "half powered down" state — where the TV appears off, but the OS and network stack are still functional — the only way I know to wake it up is to simulate a power button event.  Of course, if `lgtv_saver` has misunderstood the state of the TV, this might actually end up turning it off.

If you find your TV turning off unexpectedly, search for `turn_off` in `lib/lgtv_saver/tv.ex` and try commenting out that line.  If that fixes your problem, feel free to let me know by [creating an issue](issues).

## Todo?

* Add tests
* Client script for Mac, Linux

## Legal stuff

Copyright © 2020, Adrian Irving-Beer.

`lgtv_saver` is released under the [Apache 2 License](LICENSE) and is provided with **no warranty**.  I do my best to write secure and resilient code, but I'm not liable if things break.  Be careful with your TV, and don't expose your UDP ports to the internet.
