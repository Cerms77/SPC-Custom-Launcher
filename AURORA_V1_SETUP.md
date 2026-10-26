# Aurora Launcher V1.0 — SPC Android TV

Aurora V1.0 is the personalized Flutter/Android TV launcher on the `feature/aurora-home-screen` branch.

## Included

- Automatically opens the finished Aurora home screen at app launch (no START AURORA HOME button).
- Preserves a retry/error screen if startup fails.
- Uses the existing 10 shortcut order and tinted buttons.
- Includes live Prague / New York clocks and three corner controls.
- Includes the native 15-photo dream service (45-second transitions, Prague/Pittsburgh clocks).

## Important: keep the working backup

Leave the original **LTvLauncher** installed. Aurora has its own Android application ID and is not a replacement for the original package.

The Aurora debug application ID remains `com.leanbitlab.ltvL.aurora.diagnostic`, matching the previous working Aurora Diagnostic installation. The production application ID is `com.leanbitlab.ltvL.aurora`, intentionally separate from the stock `com.leanbitlab.ltvL`.

## Installation from the existing GitHub workflow

1. Open the newest successful Actions run on the feature branch.
2. Under Artifacts download `SPC-Aurora-Android-TV-debug-APK`.
3. Unzip the artifact and send the APK to the SPC monitor with LocalSend.
4. Install and open **Aurora Launcher**.
5. If Android rejects the update, uninstall **only the earlier Aurora Diagnostic app**, not LTvLauncher, then install the APK.
6. Check the 10 shortcuts and select **SPC Aurora Photos** under Android screen saver settings.

## Important signing note

GitHub-hosted Flutter debug builds use generated debug signing keys, which can change between Actions runners. This can cause `App not installed` when updating an already installed test app. The fallback is to uninstall only the older Aurora test build before installing the newer one.

For **permanent in-place updates**, create a persistent signing keystore *privately*, back it up somewhere secure, configure a private signing workflow/CI secrets, and sign every future production APK with that same key. Do not commit keystores, private keys, or passwords to this repository. Production and debug APKs use different application IDs and are not interchangeable as updates. Initial migration to the production ID creates a second Aurora installation; uninstall the old diagnostic version only after testing the production build.

The automated workflow currently produces the working **debug test APK**, not a production signed release. Do not advertise it as a fully configured stable-signing release.

## Attribution

This project is based on LTvLauncher / FLauncher and is subject to the upstream project's GPL-3.0 license. See the repository LICENSE and README for attribution.
