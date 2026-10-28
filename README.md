# Iraq Maps — Flutter Android project

This project creates an Arabic maps app using OpenStreetMap, GPS, place search, and route directions.

## Build APK using GitHub from your phone

1. Extract `IraqMaps_Fixed.zip` on your phone.
2. Create a repository on GitHub named `IraqMaps`.
3. Upload the *contents* of the `IraqMaps` folder to the repository root. Make sure `pubspec.yaml`, `lib/`, `android/` manifest, and `.github/` are at the repository root (not nested inside another `IraqMaps` folder).
4. Open the repository on GitHub and choose **Actions**.
5. Select **Build Iraq Maps APK**, then tap **Run workflow**. If it doesn't appear, first push/commit the files to the `main` branch.
6. Wait for the workflow to finish with a green check mark.
7. Open the successful run, scroll to **Artifacts**, and download `iraq-maps-apk`.
8. Extract the downloaded artifact and install `app-release.apk`. Android may ask you to allow installation from that source.

## Important

- The APK is built by GitHub Actions; it is not included in this ZIP.
- This app currently requires internet for map tiles, place search, and route requests. It does not include offline maps.
- If the workflow fails again, open the failed **Build release APK** step and send the first actual error lines, not the final `exit code 1` line.
