---
title: Yes, fully doable on Linux. Let’s walk through it step by step. The…
date: 2026-03-12
source-folder: Notes
tags: [:needs-review: :has-links: :has-table:]
review-reasons: has-links
---

# Yes, fully doable on Linux. Let’s walk through it step by step. The…

Yes, fully doable on Linux. Let’s walk through it step by step. The key thing first: which NAOqi version is your Pepper running? That determines which Choregraphe you need. We’ll figure that out as part of Step 1.

Step 1 — Find out what’s on your Pepper
When you’re with the robot, press the chest button once — Pepper will say its IP address. Then open a browser and go to:

[<PEPPER_IP](http://<PEPPER_IP)>:8080

This shows you the web dashboard. Look for the NAOqi version — it’ll be either 2.5.x or 2.9.x. That’s your fork in the road.

Step 2 — Download Choregraphe (do this tonight)
If NAOqi 2.5 (most common for older Peppers):
Download Choregraphe 2.5.10.7 for Linux 64-bit. The license key is publicly known:

654e-4564-153c-6518-2f44-7562-206e-4c60-5f47-5f45

The download used to live on Aldebaran’s cloud but is now tricky to find officially. Your best bet is to search “choregraphe-suite-2.5.10.7-linux64” — universities and community mirrors host it. The University of Auckland CARES lab has a demo guide on GitHub that links resources.
### If NAOqi 2.9 (newer Peppers)
You’d use Android Studio with the Pepper SDK plugin instead of Choregraphe — different workflow entirely. Let me know if this is your case and we’ll pivot.

Step 3 — Install Choregraphe on Linux
### Once you have the .run file

chmod +x choregraphe-suite-2.5.10.7-linux64.run
sudo ./choregraphe-suite-2.5.10.7-linux64.run

It installs to /opt/Softbank Robotics/Choregraphe Suite 2.5/. Then launch it:

cd choregraphe-suite-2.5.10.7-linux64
./choregraphe

You’ll likely hit a libz error on modern Ubuntu. If you see something about ZLIB_1.2.9 not found, fix it with:

cd "/opt/Softbank Robotics/Choregraphe Suite 2.5/lib/"
sudo mv libz.so.1 libz.so.1.old
sudo ln -s /lib/x86_64-linux-gnu/libz.so.1 .

### Also install these if needed

sudo apt install libgl-dev libxt6 libxaw7

Step 4 — Connect to Pepper
In Choregraphe: Connection ? Connect to… ? enter Pepper’s IP and port 9559. You’ll see a 3D robot model animate to match the real Pepper — that’s your confirmation it’s working.

Step 5 — Build your clinic demo behavior
Once connected, you’ll drag blocks from the box library on the left. For a clinic greeting demo, your flow is just:

[Start] ? [Say: "Welcome to the clinic..."] ? [Animated Say] ? [Show Image on Tablet] ? [End]

Use Animated Say instead of plain Say — it automatically adds gestures, which looks much more natural and impressive for a demo.

Two things to tell me so I can make this more specific:
|  | 1. | Do you know yet whether it’s NAOqi 2.5 or 2.9? |
| --- | --- | --- |
|  | 2. | What’s the demo scenario — is Pepper greeting patients at a front desk, or something else? |
That’ll let me give you the exact behavior blocks and script to build tonight.????????????????
