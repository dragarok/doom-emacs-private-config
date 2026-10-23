#!/bin/sh
# Build and sign Emacs Home -- no Gradle, just the SDK's own tools.
#   ./build.sh            -> out/emacs-home.apk
#   ./build.sh install    -> also adb install it
# Signed with GNU Emacs's java/emacs.keystore (public password emacs1): the
# key Emacs and Termux on the phone carry, which the shared user requires.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-$HOME/Library/Android/sdk}
BT=$SDK/build-tools/36.0.0
JAR=$SDK/platforms/android-36/android.jar
KS=${EMACS_KEYSTORE:-$HOME/Downloads/emacs.keystore}
VERSION=${VERSION:-$(git rev-list --count HEAD -- . 2>/dev/null || echo 1)}

rm -rf out && mkdir -p out/classes
"$BT/aapt2" link -o out/unsigned.apk -I "$JAR" --manifest AndroidManifest.xml \
  --min-sdk-version 26 --target-sdk-version 28 \
  --version-code "$((VERSION + 1))" --version-name "0.$VERSION"
javac --release 17 -nowarn -cp "$JAR" -d out/classes $(find src -name '*.java')
"$BT/d8" --min-api 26 --lib "$JAR" --output out $(find out/classes -name '*.class')
(cd out && zip -qj unsigned.apk classes.dex)
"$BT/zipalign" -f 4 out/unsigned.apk out/aligned.apk
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:emacs1 \
  --out out/emacs-home.apk out/aligned.apk
echo "built out/emacs-home.apk"
if [ "$1" = install ]; then
  adb install -r out/emacs-home.apk
  # Draw the floating clock over apps, and read which app is in front.
  adb shell appops set dev.alok.emacshome SYSTEM_ALERT_WINDOW allow
  adb shell appops set dev.alok.emacshome GET_USAGE_STATS allow
  adb shell pm grant dev.alok.emacshome android.permission.POST_NOTIFICATIONS || true
  # The clock's island above the status bar (IslandAccess), added to the
  # accessibility services already on rather than replacing them.
  ISLAND=dev.alok.emacshome/dev.alok.emacshome.IslandAccess
  ON=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
  case "$ON" in
    *"$ISLAND"*) ;;
    null|"") adb shell settings put secure enabled_accessibility_services "$ISLAND" ;;
    *) adb shell settings put secure enabled_accessibility_services "$ON:$ISLAND" ;;
  esac
  adb shell settings put secure accessibility_enabled 1
fi
exit 0
