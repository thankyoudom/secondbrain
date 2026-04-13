---
title: Perfect—let’s break this down in two parts:
date: 2025-04-07
source-folder: Notes
tags: [:needs-review: :has-table:]
---

# Perfect—let’s break this down in two parts:

---

## **PART 1: Deep Guide on Panning – Instrument Placement in the Stereo Field**

Think of the stereo field as a **3D space**:
- **Left to Right** = Panning
- **Front to Back** = Volume & Reverb
- **Top to Bottom** = Frequency content

### **Core Panning Guidelines (General)**

| Element | Pan Position | Notes |
|--------|--------------|-------|
| **Kick** | Center (0%) | Power source, must hit equally in both ears |
| **Snare/Clap** | Center or slight off (L5-R5) | Core rhythmic focus |
| **Hi-Hats** | Slight Left or Right (L10–L30 or R10–R30) | Create groove; alternate pans for realism |
| **Percussion** | Wide (L20–R60) | Adds energy; use automation for interest |
| **Bass** | Center | Low-end needs mono compatibility |
| **Lead Vocals / Melody** | Center | Emotional anchor of the track |
| **Backing Vocals / Chops** | L20–L80 & R20–R80 | Mirror for space; automate width |
| **Pads / Ambient FX** | Wide (L50–R90) | Use stereo imaging to float them around |
| **Chords / Keys / Arps** | Spread (L30–R30 or L40–R60) | Layer and offset to avoid clutter |
| **FX (sweeps, risers)** | Moving across field | Pan or automate sweep for interest |

---

### **Pro Tips**
- **Keep low frequencies (below ~150Hz) in mono.**
Use tools like *Ozone Imager* (free) to monitor stereo width.

- Use **hard L/R panning** (100% L/R) for doubled guitars or backing vocals to maximize width.

- **Balance energy**: For every element you pan left, try to pan something else right with similar frequency content or energy.

- Check your mix in **mono** often to catch phase issues.

---

## **PART 2: Industry-Standard Mixing Template (DAW-Agnostic)**

### **Routing Structure**
```
Tracks ? Groups (Buses) ? Master Bus
```

---

### **Track Groups (Color Code for Speed)**
1. **Drums (Group: Drum Bus)**
- Kick
- Snare
- Hi-Hats
- Percussion
- Overheads (if using drum loops or live kits)

2. **Bass (Group: Bass Bus)**
- Sub Bass
- Mid Bass
- 808

3. **Melody (Group: Instrumental Bus)**
- Chords (Keys, Pads)
- Leads (Synths, Samples, Instruments)
- Arpeggios
- Stabs

4. **Vocals (Group: Vocal Bus)**
- Lead Vocal
- Doubles
- Harmonies
- Adlibs

5. **FX (Group: FX Bus)**
- Risers
- Downlifters
- Ambience
- Textures / Noise

6. **Sends/Returns**
- Reverb Send
- Delay Send
- Parallel Compression Bus
- Sidechain Compression Bus

7. **Master Bus (Final Output)**
- Very light compression / saturation (optional pre-mastering)
- Loudness meter (e.g., Youlean)
- Stereo/Phase scope (e.g., SPAN)

---

### **Signal Flow Example**
```
Kick ? Drum Bus ? Master
Bass ? Bass Bus ? Master
Lead Synth ? Instrumental Bus ? Master
Vocals ? Vocal Bus ? Master
FX ? FX Bus ? Master

Reverb/Delay Sends ? Blend into respective groups
Parallel Compression ? Return to Master Bus
```

---

### **Plugin Chain Suggestions per Bus**

#### **Drum Bus**
- EQ (cut boxy mids, brighten hats)
- Bus Compressor (e.g., MJUC Jr or DC1A)
- Saturation (e.g., IVGI)
- Transient Designer (soften snare/kick peaks)

#### **Bass Bus**
- EQ (low-pass highs, cut mud)
- Compression (smooth levels)
- Optional saturation (e.g., subtle tape sim)

#### **Instrument Bus**
- EQ (balance mids, remove mud)
- Stereo Width (subtle MS processing)
- Reverb send

#### **Vocal Bus**
- EQ (de-mud, boost air)
- Compression (level control)
- De-Esser (5–8kHz)
- Delay/Reverb Sends

#### **Master Bus (Optional)**
- Bus Compressor (1.5:1 ratio, ~2dB GR)
- Gentle Saturation
- Loudness Meter
- No limiter or hard clipping!

---

Would you like a downloadable mix template (e.g., for Ableton, FL, or Logic)? And do you want a visual chart for panning layout or stereo field illustration?
