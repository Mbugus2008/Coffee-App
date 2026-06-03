---
globs: "**/build.gradle.kts"
description: When modifying Android build files for Flutter projects, follow
  this signing configuration pattern.
---

In Flutter Android projects, configure release signing in `android/app/build.gradle.kts` to support both:
1. **Local development** via `android/key.properties` (keystore file path, passwords)
2. **CI/CD (GitHub Actions)** via environment variables (`ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`)

Use explicit Kotlin imports at the top of the build script: `import java.util.Properties` and `import java.io.File`. Use `Properties()` with `.use { stream -> props.load(stream) }` for stream handling. Always use `File()` instead of `java.io.File()` after importing.