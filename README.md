Arbchar — minimal Bluetooth chat (Android)

Contents:
- pubspec.yaml
- lib/main.dart
- .github/workflows/build.yml

How to use (GitHub Actions method):
1. Create a new public GitHub repository (e.g. arbchar).
2. Upload the contents of this ZIP (all files and folders) to the repo root.
   - If mobile web upload fails, upload files in small batches or use git from a PC/Termux.
3. In the repository, go to Actions, open the workflow 'Build Flutter APK' and Run workflow.
4. Download the artifact `app-release.apk` when the workflow finishes.
Note: This project requires Android devices to test Bluetooth. GitHub Actions will run `flutter create .` to generate android/ folder before building.
