<div align="center">

  ![macOS](https://img.shields.io/badge/macOS-15.0%2B-lightgrey?logo=apple)
  ![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20%2B%20Intel-blueviolet)
  ![Version](https://img.shields.io/github/v/release/zinc75/JackMoebius?label=version&color=blue)
  ![License](https://img.shields.io/badge/license-Proprietary-red)
  ![Trial](https://img.shields.io/badge/trial-14%20days-informational)

  <img src="docs/assets/favicon.png" width="128" alt="JackMoebius icon">
  <h1>JackMoebius</h1>
  <p>The modern bridge between macOS audio apps and JACK.<br>
  Route any CoreAudio application into JACK — and JACK back into any app — <strong>per application, bidirectionally</strong>.</p>

    <p>
    <img src="docs/assets/notarized-badge.png" width="15" alt="">
    <strong>Signed &amp; notarized by Apple</strong>
  </p>

  **[Documentation](https://zinc75.github.io/JackMoebius/)** · **[Download trial](https://github.com/zinc75/JackMoebius/releases/latest)** · **[Buy a license](https://STORE_URL)**

</div>

---

## What it is

JackMoebius exposes each macOS application as a **routable JACK client**. It brings
back the idea of the historical *JackRouter* for modern macOS (15+), built on a
per-app **AudioServerPlugIn** virtual driver plus a Swift daemon that bridges
CoreAudio to JACK.

- **Bidirectional** — an app's **output** flows into JACK, and JACK can feed an
  app's **input** (process a live instrument and send it back into a call, for example).
- **Per application** — one JACK box per exposed app; output and input are independent
  and get their own persistent channel reservations.
- **Transparent to the app** — no plug-in, no reconfiguration inside the app: its
  audio simply appears in the JACK graph.
- **Universal** — Apple Silicon + Intel, macOS 15+.
- **Scriptable** — a `jackmoebius` command-line tool and a documented IPC protocol.

Best when controlled from the **[JackMate](https://zinc75.github.io/JackMate)** GUI
(free), which manages the JACK graph and the JackMoebius routing visually — but it
runs standalone from the CLI too.

## Download & install

1. **[Download the latest `.dmg`](https://github.com/zinc75/JackMoebius/releases/latest)** and open it.
2. Run **Install JackMoebius.pkg**. macOS installs a system audio driver, so you'll be
   **asked to reboot** at the end.
3. Start a **JACK** server (via [JackMate](https://zinc75.github.io/JackMate)), then activate JackMoebius.

> 🛡️ **Signed and notarized by Apple.** The driver and daemon are Developer ID signed and
> the installer is notarized + stapled, so it opens with **no Gatekeeper warnings**.
>
> Requires a running **JACK** server. Designed to be driven by **[JackMate](https://zinc75.github.io/JackMate)**.

## Documentation

Full documentation — how it works, the IPC protocol, and the CLI reference — lives at
**[zinc75.github.io/JackMoebius](https://zinc75.github.io/JackMoebius/)**.

## Requirements

| | Minimum |
|---|---|
| macOS | 15.0 (Sequoia) |
| Architecture | Apple Silicon or Intel |
| JACK | JACK2 (`jackd` / `jackdmp`) installed and running |
| GUI (recommended) | [JackMate](https://zinc75.github.io/JackMate) |

## License

JackMoebius is **proprietary software**, distributed with a **14-day free trial**.
Continued use requires a license — **one purchase covers all future versions**
(see the EULA). Buy a license: **[STORE_URL](https://STORE_URL)**.

Copyright © 2026 Éric Bavu. All rights reserved.
