# Recovering dittos lost in the 3.0.0 / 3.0.1 upgrade

If you upgraded to Ditto **3.0.0** or **3.0.1** and your dittos from a previous version
disappeared, this page explains what happened and what you can do.

## What happened

Ditto 3.0.0 shipped a migration step that was supposed to copy your existing dittos
(stored by 2.x in a Core Data SQLite database inside the app's shared container)
into the new SwiftData store used by 3.x. Because of a packaging mistake, the
migration could never actually read the old database — and on the same code path
that decided "there's nothing to migrate" it also removed the old database files
from disk. Anyone who launched 3.0.0 once on top of a 2.x install had their
on-device dittos deleted as a side-effect of that mis-cleanup.

3.0.1 did **not** make things worse. It also did not bring the lost dittos back —
by the time it ran, the source data was already gone.

3.0.2 fixes the underlying bug, will never delete the legacy store again, and
adds a **Recover Old Dittos** menu item so anyone whose 2.x data is still on disk
(for example users who restore an iCloud backup made before they launched 3.0.0)
can pull it into 3.0.2 with one tap.

## Step-by-step: try to recover

### 1. Update to Ditto 3.0.2 from the App Store

Open the App Store, search for Ditto, and install the latest version. Make sure
the version says **3.0.2** or later in Settings → General → iPhone Storage → Ditto.

### 2. Open Ditto and look for the menu item

Open Ditto, tap the menu button (the three-dot circle in the top-left of the main
list), and look for **Recover Old Dittos**. If you see it, tap it. A confirmation
dialog will tell you how many dittos / categories will be imported. Tap **Recover**
and they'll be merged into your current library. Duplicates are skipped.

**If you see "Recover Old Dittos" in the menu — congratulations, your data is
intact on disk and the import will succeed.** You're done.

### 3. If the menu item is missing — restore from iCloud Backup

If 3.0.2 doesn't show the **Recover Old Dittos** menu item, your old database
files are no longer on this device. The remaining option is to restore the device
(or just the Ditto app's data) from an iCloud backup that was taken **before** you
first launched 3.0.0.

#### A. Check that you have a viable backup

1. On the iPhone, open **Settings → Your Name → iCloud → iCloud Backup**.
2. Note the timestamp of the most recent backup.
3. If that timestamp is **older than your first 3.0.0 launch**, the backup still
   contains your dittos. If it's newer, the backup was taken after the data was
   already wiped — restoring from it won't help.

You can also check for older backups on macOS via **System Settings → Apple ID →
iCloud → Manage Account Storage → Backups**.

#### B. Restore the whole device (recommended if your last good backup is recent)

This is the supported Apple flow.

1. Back up anything new you've created since 3.0.0 that you want to keep.
2. **Settings → General → Transfer or Reset iPhone → Erase All Content and
   Settings.**
3. During the setup assistant, choose **Restore from iCloud Backup** and pick the
   backup from before your 3.0.0 launch.
4. Once the device finishes restoring, install **Ditto 3.0.2 first** (do not
   open an older version) from the App Store. On first launch, 3.0.2 will detect
   the legacy database that came back with the restore and offer to migrate it
   automatically. If it doesn't migrate automatically, tap **Recover Old Dittos**
   from the menu.

> ⚠ Do **not** open Ditto 3.0.0 or 3.0.1 again after restoring. 3.0.1 won't
> delete your data, but 3.0.0 will, and the only fixed build is 3.0.2.

#### C. Don't want to erase the device? Try the keyboard-extension trick

Ditto's keyboard extension also has access to the App Group container. On some
devices, if the main app deleted the SQLite file but the keyboard extension was
suspended in memory, the extension may still hold an open file handle that keeps
the data alive in `-shm`/`-wal` files until iOS reclaims them.

This is **not reliable**, but if you want to try before resorting to a full
restore:

1. Do **not** open the Ditto app.
2. From any other app, switch to the Ditto keyboard (globe key → Ditto). If your
   dittos appear in the keyboard, your data is still there. Update to 3.0.2,
   open the app, and tap **Recover Old Dittos**.
3. If the keyboard shows the default presets instead of your data, the data is
   gone from disk and you'll need the iCloud restore in step B.

### 4. If none of the above works

The data is unrecoverable from this device, and you'll need to recreate any
dittos manually. We are very sorry. The bug that caused this has been fixed in
3.0.2 — both the original packaging mistake (the migrator can now read the
legacy database) and the destructive cleanup (the legacy database is never
deleted, on any code path).

## What 3.0.2 changes

- The Core Data model file is now bundled into the main app, so the migrator
  can actually load and read the 2.x SQLite store.
- The migrator opens the legacy store **read-only** and **never** removes it
  from disk under any branch. Even after a successful migration the SQLite
  files stay where they are, so a future bug can't lose data the same way.
- A new **Recover Old Dittos** menu item lets you re-run the migration
  manually from inside the app, independent of the auto-migration flag.
  Duplicates are skipped, so it's safe to tap more than once.
- The migration completion flag has been bumped to a new key, so anyone who
  hit 3.0.0 or 3.0.1 will be retried automatically on first launch of 3.0.2
  — no menu tap required if your data is still on disk.

## How to tell whether 3.0.2 found your old dittos

Open **Console.app** on a Mac with the iPhone connected (or **Settings →
Privacy & Security → Analytics & Improvements → Analytics Data** for a
sysdiagnose), filter by subsystem `io.kern.ditto` and category
`LegacyDataMigrator`. You'll see messages like:

```
LegacyDataMigrator  needsMigration: legacy store present=true
LegacyDataMigrator  runMigration(auto): importing 4 categories / 27 dittos
LegacyDataMigrator  writeMigratedData: inserted 4 new categories, 27 new dittos (skipped 0 duplicates)
```

If you see `legacy store present=false`, the SQLite files aren't on disk and
you'll need an iCloud restore (step 3 above). If you see import counts, your
data is back.
