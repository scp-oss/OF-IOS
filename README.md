# OF-IOS

Redesigned SwiftUI frontend for [OpenFlux](https://github.com/saharev1/OpenFlux)
— a TCP tunnel with pluggable covert transports (Yandex Docs, VOLGA, Mail.ru,
MAX). This repo is **frontend only**.

## Why frontend-only

The Go backend (transport implementations, SOCKS5 server, tunnel core) is
**not vendored here**. It's fetched straight from the upstream repository at
a pinned commit by [`fetch_backend.sh`](fetch_backend.sh) and built locally
into `ios-app/Lib/liboflux.a` — nothing about the backend ever lives in this
repo's git history. This keeps the split between "what changed here" (the
UI) and "what didn't" (the tunnel/transport logic) honest and easy to audit,
and means backend fixes upstream are picked up just by bumping the pinned
commit in `fetch_backend.sh`, not by copying files around.

## What changed vs. upstream

Only the SwiftUI layer:

- `ios-app/OpenFlux/ContentView.swift` — rebuilt around a single active
  profile + one power control (starts the system VPN directly), a profile
  switcher, an availability check, a collapsible log console, and
  settings / add-edit / about as bottom sheets.
- `ios-app/OpenFlux/Theme.swift` — new; the color/typography tokens behind
  the redesign (light + dark, tracks system appearance).
- `ios-app/OpenFlux/InfoView.swift` — restyled to match, same content/logic.
- `ios-app/project.yml` — deployment target bumped 15.0 → 16.0 (needed for
  native `.presentationDetents` bottom sheets).

`TunnelController.swift`, `VPNController.swift`, `OpenFluxTunnel/PacketTunnelProvider.swift`,
the bridging headers and entitlements are carried over **unmodified** — the
new UI only calls the exact same public methods they already exposed
(`vpn.start(...)`, `vpn.stop()`, `tunnel.stop()`).

One behavior change worth flagging: the redesign's single power button
always brings up the **system VPN** — the old "local SOCKS5 proxy only, no
VPN" mode is no longer reachable from the main screen (though
`TunnelController.swift` — the code for that mode — is still present and
unused, so it can be wired back in as an advanced option later).

## Build

```bash
export XCODE_PATH="<your Xcode.app path>"   # optional, defaults to /Applications/Xcode.app
./fetch_backend.sh                          # clones upstream @ pinned commit, builds liboflux.a
cd ios-app
xcodegen generate                           # brew install xcodegen if you don't have it
open OpenFlux.xcodeproj                      # or xcodebuild ...
```

`project.yml` hardcodes the upstream author's Apple Developer Team
(`8GQH8GQ252`) and bundle id — change `DEVELOPMENT_TEAM` /
`PRODUCT_BUNDLE_IDENTIFIER` before archiving under your own account.

Note: the system VPN (packet-tunnel extension) needs the Network Extension
entitlement, which requires a **paid** Apple Developer Program account — a
free personal team can't get it. It also doesn't run in the iOS Simulator,
only on a physical device. The main-screen UI and the availability check
work fine in the Simulator without either.

## License

GPLv3-or-later, same as upstream (see [LICENSE](LICENSE)) — this repo's own
Swift files are a derivative work of the original app's UI layer.

## Upstream

- Backend + original app: https://github.com/saharev1/OpenFlux
- Pinned commit this repo currently builds against:
  `ef3d6ef281d56a5a792be1a381d004040b68596d` (`ios-testflight` branch)
