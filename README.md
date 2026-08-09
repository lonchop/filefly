# FileFly

Native desktop app for Linux and Windows that transfers files between your PC
and your phone over the local network. The PC runs everything; the phone only
scans a QR code and uses its browser. Nothing to install on the phone, no
cloud, no cable.

## Why the phone side is a browser

A browser on Android cannot read or write a folder on the device: the File
System Access API is not exposed on Chrome for Android, and
`<input webkitdirectory>` only yields a one-shot, read-only snapshot. So the
phone can upload files it picks and download files the PC shares — which is
exactly what this app does — but real folder sync would require a native app
on the phone. That is a different product.

## Installing on Linux

```bash
flutter build linux --release
tool/install_linux.sh
```

That installs into `~/.local/share/filefly`, registers the launcher and the
icons, and links `~/.local/bin/filefly` — all under your home directory, no
root. FileFly then shows up in the menu like any other app. Re-run both
commands after changing the code; `tool/uninstall_linux.sh` removes it and
leaves your shared folder and token alone.

## Running from source

```bash
flutter run -d linux
```

The window shows the QR, the pairing link and the shared folder. Scan the QR
with the phone's camera and its browser opens the same file list. Only one
instance runs at a time — launching it again raises the window that is already
open, since only one process can hold the port.

Windows:

```bash
flutter build windows --release   # must be run on Windows
```

## How it works

```
┌─────────────────────────────────────────────┐
│ Flutter desktop UI (native, this window)    │
├─────────────────────────────────────────────┤
│ FileServer — dart:io HttpServer on :8765    │
│   /            token -> cookie -> page      │
│   /api/config  /api/files                   │
│   /api/upload  /api/download  /api/file     │
├─────────────────────────────────────────────┤
│ Shared folder (~/FileFly by default)        │
└─────────────────────────────────────────────┘
             ▲                    ▲
   native client (the app)   phone browser
```

Both sides are clients of the same folder. The desktop UI never goes through
HTTP — it reads and writes the folder directly, and repaints when the server
reports a change.

```
lib/
  main.dart                  # loads the phone page asset, starts the app
  app/palette.dart           # the only place a hex lives; injected into the
                             #   phone page's :root so the two cannot drift
  app/theme.dart             # ThemeData, spacing scale, shared widgets
  server/
    file_server.dart         # HTTP server, routes, auth, shared folder
    lan_addresses.dart       # which IPs a phone can actually reach
    app_paths.dart           # token and settings, per platform convention
  ui/
    home_screen.dart         # layout and state
    widgets/                 # send, connect and shared-files panels
assets/icons/                # app icon, one PNG per hicolor size
assets/web/index.html        # the page phones load, QR encoder bundled offline
tool/install_linux.sh        # user-level install: launcher, icons, symlink
tool/uninstall_linux.sh
```

## Security

- Every request needs the access token; without it the answer is `401`. The
  three exceptions are `/manifest.webmanifest`, `/icon-256.png` and
  `/icon-512.png`: static branding with no user data, served openly because the
  browser fetches them outside the page's cookie context when a phone adds
  FileFly to its home screen, and gating them only yields a blank icon.
- The token lives in the platform config directory (`~/.config/filefly/token`
  on Linux, `%APPDATA%\filefly\token` on Windows), mode `600`, and is reused
  across restarts. Regenerating it per run would invalidate the QR, the saved
  link and the cookie of every phone already paired, with no way back in.
- The first visit to a token URL trades the token for an `HttpOnly`,
  `SameSite=Lax` cookie valid for 30 days and redirects to a clean `/`, so the
  token stops sitting in the address bar and the browser history.
- Upload and download names are reduced to a plain file name, so nothing can
  be written or read outside the shared folder.
- Only interfaces a device on your Wi-Fi can reach are advertised. VPN tunnels
  (WARP, WireGuard, ProtonVPN) and virtual bridges (`lxcbr0`, `docker0`,
  `vEthernet`) are filtered out — their addresses produce a QR no phone can
  open.

### Limits

- Plain HTTP, no TLS. Anyone sniffing the same Wi-Fi sees the token and the
  file contents. Fine for a home network, not for a café.
- The token is a long-lived secret rather than a per-session one. Delete the
  token file to lock every paired device out.
- Uploads are not size-capped: anyone holding the token can fill the folder.

## Tests

```bash
flutter test
```

Covers the token and cookie handshake, stale cookies, uploads, name
collisions, download, delete and path traversal attempts.

## Status

Linux is built, installed and verified end to end: release bundle, desktop
launcher, icon theme, single instance, and the full upload/list/download/delete
cycle from another device on the network.

Windows targets are configured and the code paths are platform-neutral
(`NetworkInterface`, `%APPDATA%`, `explorer`), but a Windows build has to be
produced and tested on Windows.
