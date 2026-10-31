# Gym Tracker

A fully local weight, food and training tracker for iPhone. Nothing is sent
anywhere: there is no networking code in the app at all. Your log lives in the
app's own container with complete file protection, and progress photos sit
beside it, optionally behind Face ID.

Photos are four a day, front and back, relaxed and flexed, and the gallery
filters by any one of those so you can follow a single angle over time. The
photo folder is excluded from iCloud backup, so those images stay on the phone
and nothing uploads. The trade is that losing the phone loses them, so save out
any you want to keep.

It reads the same backup format as the web version, so a backup copied out of
that imports here directly.

## Getting it onto your phone, without a Mac

You need: a GitHub account, a Windows PC once, and your free Apple ID.

### 1. Put this code on GitHub

1. Go to github.com and create a new repository. Public is fine and keeps the
   build minutes free. Call it `bulk-log`.
2. On the new repo's page choose **uploading an existing file**.
3. Drag in everything from this folder, keeping the structure:
   `Sources/`, `.github/`, `project.yml`, `README.md`.
   The `.github` folder matters, so if the browser hides it, use the
   **Add file -> Create new file** box and type
   `.github/workflows/build.yml`, then paste that file's contents in.
4. Commit.

### 2. Let GitHub build it

1. Open the **Actions** tab. The *Build IPA* workflow runs on its own after
   the upload. If it does not, click it and press **Run workflow**.
2. Wait a few minutes. Green tick means it built.
3. Open the finished run and download **GymTracker-ipa** from Artifacts. It
   arrives as a zip, so unzip it to get `GymTracker.ipa`.
4. If it fails, open the failed step and copy the red error text. That is what
   to send back for a fix.

### 3. Install it with SideStore

SideStore signs the app on your phone with your free Apple ID and re-signs it
every week by itself over wifi.

1. Follow the current setup guide at <https://sidestore.io>. The one-time
   pairing step is the part that needs your Windows PC.
2. Once SideStore is running on your phone, open it, choose the `+` button and
   pick `GymTracker.ipa`.
3. It installs as **Gym Tracker** on your home screen.

### What to expect afterwards

- A free Apple ID signature lasts seven days. SideStore refreshes it in the
  background, so normally you do nothing. If your phone is off wifi for a week
  the app refuses to open until you open SideStore and hit refresh.
- Refreshing never touches your data. Only deleting the app does that.
- A free account allows three sideloaded apps at once.
- A paid Apple Developer account stretches the signature to a year if the
  weekly refresh ever becomes annoying.

## Renaming the app

Change one line in `project.yml`:

    INFOPLIST_KEY_CFBundleDisplayName: Gym Tracker

That is the name under the icon on your home screen, and the lock screen reads
it from there too. Spaces are fine.

Leave `PRODUCT_BUNDLE_IDENTIFIER` alone once you have installed it. That is the
app's identity to iOS, so changing it makes the next install a separate app
with an empty log rather than an update of this one.

## Updating it later

Replace the files in the repo, let Actions build again, download the new IPA
and install over the top in SideStore. Installing over the top keeps your data.
Export a backup first anyway, from Plan then Data.

## Layout

| File | What it holds |
| --- | --- |
| `Sources/Model.swift` | The stored shape, and lenient decoding so old backups still open |
| `Sources/Calc.swift` | Dates, formatting, trends, macros, progression |
| `Sources/Store.swift` | Loading, saving, photos, backup and import |
| `Sources/Seed.swift` | The starter plan and the demo history |
| `Sources/Theme.swift` | Colours and the shared building blocks |
| `Sources/Charts.swift` | Weight, intake and strength charts |
| `Sources/*View.swift` | The five screens |
| `project.yml` | Project spec, read by XcodeGen during the build |
| `.github/workflows/build.yml` | The cloud build |
