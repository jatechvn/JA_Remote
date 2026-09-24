# OTA LAN Update package

JA Remote only offers an OTA package when the same LAN folder contains both
the ZIP file and `version.json`. The SHA-256 value is mandatory: unsigned
packages are blocked before the update dialog is shown.

Create the Windows release ZIP with this layout at its root (or under one
single parent folder):

```text
ja_remote.exe
flutter_windows.dll
data/
```

Calculate the ZIP checksum on the release machine:

```powershell
(Get-FileHash .\JA_Remote_v1.2.2_Windows_x64.zip -Algorithm SHA256).Hash.ToLower()
```

Place the package and this manifest in the configured SMB folder. Replace the
example checksum with the command result exactly; it must be 64 hexadecimal
characters.

```json
{
  "version": "1.2.2+5",
  "fileName": "JA_Remote_v1.2.2_Windows_x64.zip",
  "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "releaseDate": "2026-09-21",
  "releaseNotes": "Bug fixes and improvements"
}
```

The app copies the ZIP locally, validates its checksum, rejects unsafe or
oversized archives, checks the required Flutter payload, then starts the
existing backup-and-rollback updater. SMB passwords in `update_config.json`
are protected with Windows DPAPI after the next configuration save.
