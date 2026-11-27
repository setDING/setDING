#!/usr/bin/env bash
# Creates an Android signing key of setDING and stores it as GitHub repository
# secrets for the release workflow:
#
#   release  the release key (make android-keystore, ADR-0021): signs the APK
#            of the GitHub Release and, through Play App Signing, the APKs
#            Google Play delivers (ADR-0067).
#   upload   the Google Play upload key (make android-upload-keystore,
#            ADR-0067): signs only the AAB uploaded to Google Play. Google
#            support can reset a lost upload key; the release key cannot be.
#
# Run once, by the owner (signing keys are a human decision, git workflow section 9).
# Android only installs an update signed with the same key, so this key must never
# be lost or replaced once a release is out: back up the keystore and its
# key.properties (password manager or another safe place).
#
#   tool/release/android-keystore.sh <keystore-path> [release|upload]
#
# Writes <keystore-path> and a properties file next to it (with the password):
# key.properties for the release key (copy it to app/android/ to sign local
# `make apk` builds with it), upload-key.properties and the upload certificate
# (upload-certificate.pem, for the Play Console) for the upload key. Needs
# keytool (JDK), openssl and a logged-in gh.
set -euo pipefail

keystore="${1:?usage: android-keystore.sh <keystore-path> [release|upload]}"
kind="${2:-release}"
case "$kind" in
  release)
    alias=setding
    prefix=ANDROID
    properties="$(dirname "$keystore")/key.properties"
    ;;
  upload)
    alias=upload
    prefix=PLAY_UPLOAD
    properties="$(dirname "$keystore")/upload-key.properties"
    ;;
  *)
    echo "error: unknown key kind '$kind' (release or upload)" >&2
    exit 1
    ;;
esac

if [ -e "$keystore" ]; then
  echo "error: $keystore already exists; never replace a published $kind key" >&2
  exit 1
fi
for tool in keytool openssl gh; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found" >&2; exit 1; }
done
gh auth status >/dev/null

mkdir -p "$(dirname "$keystore")"
umask 077

# PKCS12 keystores use the store password for the key as well.
password="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 32)"

keytool -genkeypair -noprompt \
  -keystore "$keystore" -storetype PKCS12 -storepass "$password" \
  -alias "$alias" -keypass "$password" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=setDING, O=setDING"

cat >"$properties" <<EOF
storeFile=$keystore
storePassword=$password
keyAlias=$alias
keyPassword=$password
EOF

base64 -w 0 "$keystore" | gh secret set "${prefix}_KEYSTORE_BASE64"
printf '%s' "$password" | gh secret set "${prefix}_KEYSTORE_PASSWORD"
printf '%s' "$alias" | gh secret set "${prefix}_KEY_ALIAS"
printf '%s' "$password" | gh secret set "${prefix}_KEY_PASSWORD"

echo
echo "Key ($kind):     $keystore"
echo "Properties:      $properties"
keytool -list -v -keystore "$keystore" -storepass "$password" -alias "$alias" | grep -E 'SHA256:'
echo
echo "GitHub secrets ${prefix}_KEYSTORE_BASE64, ${prefix}_KEYSTORE_PASSWORD,"
echo "${prefix}_KEY_ALIAS and ${prefix}_KEY_PASSWORD are set."
if [ "$kind" = upload ]; then
  certificate="$(dirname "$keystore")/upload-certificate.pem"
  keytool -exportcert -rfc -keystore "$keystore" -storepass "$password" \
    -alias "$alias" -file "$certificate"
  echo "Upload certificate for the Play Console: $certificate"
  echo "Back up the keystore and its properties now (Google support can reset a"
  echo "lost upload key, but that takes days)."
else
  echo "Back up both files now: without this key, installed apps can no longer be"
  echo "updated."
fi
