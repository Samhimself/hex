#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_bundle=$("$root/scripts/build-app.sh")
install_dir="/Applications"
installed_bundle="$install_dir/$(basename "$source_bundle")"
source_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_bundle/Contents/Info.plist")

stop_bundle() {
  bundle="$1"
  [ -d "$bundle" ] || return 0
  executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")
  executable="$bundle/Contents/MacOS/$executable_name"
  if ! LC_ALL=C pgrep -f "$executable" >/dev/null; then
    return 0
  fi
  LC_ALL=C pkill -TERM -f "$executable" || true
  attempts=30
  while LC_ALL=C pgrep -f "$executable" >/dev/null; do
    if [ "$attempts" -eq 0 ]; then
      echo "Timed out waiting for $executable to stop." >&2
      exit 1
    fi
    attempts=$((attempts - 1))
    sleep 1
  done
}

mkdir -p "$install_dir"
if [ -e "$installed_bundle" ] || [ -L "$installed_bundle" ]; then
  existing_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_bundle/Contents/Info.plist" 2>/dev/null || true)
  # A local test build may replace only Hex Test. The release may also replace
  # the retired Kit-signed Rust Hex identity.
  case "$source_id:$existing_id" in
    anomaly.hex:anomaly.hex | anomaly.hex:com.kitlangton.hex2 | anomaly.hex.test:anomaly.hex.test) ;;
    *)
      echo "Refusing to replace $installed_bundle: its bundle identifier is $existing_id, not $source_id." >&2
      exit 1
      ;;
  esac
fi
staged_bundle="$install_dir/.$(basename "$source_bundle").installing"
rm -rf "$staged_bundle"
/usr/bin/ditto "$source_bundle" "$staged_bundle"
# The first local install may still be running directly from target/app.
# Stop it too so `open` cannot reactivate that copy instead of /Applications.
stop_bundle "$source_bundle"
stop_bundle "$installed_bundle"
rm -rf "$installed_bundle"
mv "$staged_bundle" "$installed_bundle"
/usr/bin/open "$installed_bundle"
echo "$installed_bundle"
