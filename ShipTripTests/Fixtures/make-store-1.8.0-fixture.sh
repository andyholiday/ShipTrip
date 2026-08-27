#!/bin/bash
#
# make-store-1.8.0-fixture.sh
#
# Erzeugt die eingefrorene 1.8.0-Store-Fixture fuer den Migrations-Beweis aus
# ADR-003 ("Fixture-Plan", Schritte 1-2). Braucht das Build-Token — laeuft im
# Test-Build-Spawn, nicht im Modell-Spawn.
#
# Ablauf:
#   1. Wegwerf-Simulator anlegen (neuestes iPhone der neuesten iOS-Runtime).
#   2. ShipTrip am 1.8.0-Stand (Commit 92d19e1) als Debug-App bauen.
#   3. Installieren und mit -uiTestingResetAndLoadDemoData starten: der Store
#      bekommt die Beispielreise.
#   4. Optional (--manual-pause): der Operator legt im laufenden Simulator eine
#      manuelle Reise mit Fotos an und bestaetigt mit Enter.
#   5. default.store (+ -wal/-shm) aus dem App-Container nach
#      ShipTripTests/Fixtures/store-1.8.0/ kopieren.
#
# Danach: Dateien committen (sie sind nicht gitignored) — die Tests in
# JournalStoreFixtureMigrationTests laufen ab dann statt zu skippen.
#
# Aufruf:  ./ShipTripTests/Fixtures/make-store-1.8.0-fixture.sh [--manual-pause]

set -euo pipefail

LEGACY_COMMIT="92d19e1"
BUNDLE_ID="com.andre.ShipTrip"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/store-1.8.0"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKTREE_DIR="${TMPDIR:-/tmp}/shiptrip-1.8.0-fixture-$$"
MANUAL_PAUSE="no"

if [[ "${1:-}" == "--manual-pause" ]]; then
  MANUAL_PAUSE="yes"
fi

echo "==> Wegwerf-Simulator anlegen"
DEVTYPE=$(xcrun simctl list -j runtimes | python3 -c 'import json,sys,re; rts=[r for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and r["platform"]=="iOS"]; rt=max(rts,key=lambda r:[int(x) for x in r["version"].split(".")]); ph=[d["name"] for d in rt["supportedDeviceTypes"] if d["productFamily"]=="iPhone"]; print(max(ph,key=lambda n:(int((re.findall(r"iPhone (\d+)",n) or [0])[0]),-len(n))))')
SIM_UDID=$(xcrun simctl create "fixture-store-180" "$DEVTYPE")

cleanup() {
  xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
  xcrun simctl delete "$SIM_UDID" >/dev/null 2>&1 || true
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_DIR" >/dev/null 2>&1 || true
}
trap cleanup EXIT

xcrun simctl boot "$SIM_UDID"
xcrun simctl bootstatus "$SIM_UDID" -b

echo "==> 1.8.0-Stand ($LEGACY_COMMIT) auschecken"
git -C "$REPO_ROOT" worktree add --detach "$WORKTREE_DIR" "$LEGACY_COMMIT"

echo "==> Bauen"
DERIVED="$WORKTREE_DIR/.build-fixture"
xcodebuild \
  -project "$WORKTREE_DIR/ShipTrip.xcodeproj" \
  -scheme ShipTrip \
  -configuration Debug \
  -destination "id=$SIM_UDID" \
  -derivedDataPath "$DERIVED" \
  build

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/ShipTrip.app"

echo "==> Installieren und mit Demo-Daten starten"
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" -uiTestingResetAndLoadDemoData
sleep 8

if [[ "$MANUAL_PAUSE" == "yes" ]]; then
  echo "==> Simulator ist offen: manuelle Reise mit Fotos anlegen."
  read -r -p "    Fertig? [Enter] " _
fi

echo "==> App beenden (WAL flushen)"
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" || true
sleep 2

echo "==> Store herauskopieren"
CONTAINER=$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)
STORE_DIR="$CONTAINER/Library/Application Support"

mkdir -p "$FIXTURE_DIR"
for suffix in "" "-wal" "-shm"; do
  SOURCE="$STORE_DIR/default.store$suffix"
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$FIXTURE_DIR/default.store$suffix"
    echo "    kopiert: default.store$suffix"
  fi
done

if [[ ! -f "$FIXTURE_DIR/default.store" ]]; then
  echo "FEHLER: default.store nicht gefunden unter $STORE_DIR" >&2
  exit 1
fi

echo "==> Fertig: $FIXTURE_DIR"
echo "    Jetzt committen und die Tests erneut fahren."
