#!/usr/bin/env bash
# Creates the Android release key of setDING and stores it as GitHub repository
# secrets for the release workflow (make android-keystore, ADR-0021).
#
# Run once, by the owner (signing keys are a human decision, git workflow section 9).
# Android only installs an update signed with the same key, so this key must never
# be lost or replaced once a release is out: back up the keystore and its
# key.properties (password manager or another safe place).
#
#   tool/release/android-keystore.sh <keystore-path>
#
# Writes <keystore-path> and key.properties next to it (with the password). Copy
# that key.properties to app/android/ to sign local `make apk` builds with the
# release key. Needs keytool (JDK), openssl and a logged-in gh.
set -euo pipefail

keystore="${1:?usage: android-keystore.sh <keystore-path>}"
alias=setding
properties="$(dirname "$keystore")/key.properties"

if [ -e "$keystore" ]; then
  echo "error: $keystore already exists; never replace a published release key" >&2
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

base64 -w 0 "$keystore" | gh secret set ANDROID_KEYSTORE_BASE64
printf '%s' "$password" | gh secret set ANDROID_KEYSTORE_PASSWORD
printf '%s' "$alias" | gh secret set ANDROID_KEY_ALIAS
printf '%s' "$password" | gh secret set ANDROID_KEY_PASSWORD

echo
echo "Release key:    $keystore"
echo "key.properties: $properties"
keytool -list -v -keystore "$keystore" -storepass "$password" -alias "$alias" | grep -E 'SHA256:'
echo
echo "GitHub secrets ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS"
echo "and ANDROID_KEY_PASSWORD are set. Back up both files now: without this key,"
echo "installed apps can no longer be updated."
