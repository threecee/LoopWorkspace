#!/usr/bin/env bash
# bin/setup.sh — one-time Apple Developer Portal + App Store Connect setup
# for MyLoop With Watch. Idempotent; safe to re-run.
#
# Required env vars (already in ~/.zshrc from D.1a):
#   ASC_KEY_PATH, ASC_KEY_ID, ASC_KEY_ISSUER_ID
#
# What it does:
#   1. Registers App Group group.com.threecee.loop.LoopGroup (idempotent)
#   2. Registers 7 App IDs under com.threecee.loop.* (idempotent)
#   3. Prompts for capability assignment (web UI; API is finicky)
#   4. Creates App Store Connect record "MyLoop With Watch" (idempotent)
#   5. Prompts for App Information (web UI)
#   6. Prompts for App Privacy questionnaire (no API)
#   7. Creates Internal Testing "Family" group + adds Carl
#   8. Prompts for Critical Alerts entitlement web form (Apple-mandated)

set -euo pipefail
cd "$(dirname "$0")/.."

: "${ASC_KEY_PATH:?ASC_KEY_PATH not set; source ~/.zshrc}"
: "${ASC_KEY_ID:?ASC_KEY_ID not set}"
: "${ASC_KEY_ISSUER_ID:?ASC_KEY_ISSUER_ID not set}"

API="$(dirname "$0")/asc-api.py"
TEAM_ID="8YPHY526TJ"
APP_NAME="MyLoop With Watch"
MAIN_BUNDLE="com.threecee.loop"
APP_GROUP="group.com.threecee.loop.LoopGroup"
SKU="myloop-001"
PRIVACY_URL="https://threecee.github.io/loop-privacy/"

# All 7 shipping bundle IDs we need to register
BUNDLES=(
  "${MAIN_BUNDLE}"
  "${MAIN_BUNDLE}.LoopWatch"
  "${MAIN_BUNDLE}.LoopWatch.watchkitextension"
  "${MAIN_BUNDLE}.Loop-Intent-Extension"
  "${MAIN_BUNDLE}.LoopWidgetExtension"
  "${MAIN_BUNDLE}.statuswidget"
  "${MAIN_BUNDLE}.LoopUI"
)

echo "==> D.1b setup: MyLoop With Watch"
echo "    Team: $TEAM_ID"
echo "    Main bundle: $MAIN_BUNDLE"
echo ""

# Helper: list existing bundle IDs once
EXISTING_BUNDLES_JSON=$("$API" GET "/v1/bundleIds?limit=200" 2>/dev/null || echo '{"data":[]}')

bundle_exists() {
  local id="$1"
  echo "$EXISTING_BUNDLES_JSON" | python3 -c "
import json, sys
target = '$id'
d = json.load(sys.stdin)
hits = [b for b in d.get('data', []) if b.get('attributes', {}).get('identifier') == target]
sys.exit(0 if hits else 1)
"
}

# ---- 1. Register App Group ----
echo "==> Step 1/7: Register App Group $APP_GROUP"
if bundle_exists "$APP_GROUP"; then
  echo "    ✓ already exists"
else
  if cat <<JSON | "$API" POST /v1/bundleIds >/dev/null 2>&1; then
{
  "data": {
    "type": "bundleIds",
    "attributes": {
      "identifier": "$APP_GROUP",
      "name": "MyLoop App Group",
      "platform": "IOS"
    }
  }
}
JSON
    echo "    ✓ registered"
  else
    echo "    ✗ API failed; MANUAL: register at"
    echo "      https://developer.apple.com/account/resources/identifiers/list/applicationGroup"
    echo "      Identifier: $APP_GROUP"
    echo "      Description: MyLoop App Group"
    read -r -p "    Press [Enter] when done..."
  fi
fi

# ---- 2. Register 7 App IDs ----
echo "==> Step 2/7: Register 7 shipping App IDs"
for BUNDLE in "${BUNDLES[@]}"; do
  if bundle_exists "$BUNDLE"; then
    echo "    ✓ $BUNDLE already exists"
    continue
  fi
  NAME="MyLoop ${BUNDLE#${MAIN_BUNDLE}}"
  [ "$BUNDLE" = "$MAIN_BUNDLE" ] && NAME="MyLoop With Watch (main)"
  if cat <<JSON | "$API" POST /v1/bundleIds >/dev/null 2>&1; then
{
  "data": {
    "type": "bundleIds",
    "attributes": {
      "identifier": "$BUNDLE",
      "name": "$NAME",
      "platform": "IOS"
    }
  }
}
JSON
    echo "    ✓ $BUNDLE"
  else
    echo "    ✗ $BUNDLE — API failed; MANUAL register at"
    echo "      https://developer.apple.com/account/resources/identifiers/list"
    read -r -p "    Press [Enter] when done..."
  fi
done

# ---- 3. Capabilities (manual fallback always) ----
echo ""
echo "==> Step 3/7: Capabilities for App IDs (MANUAL)"
echo "    Apple's per-capability API is finicky. Easier and more reliable to do"
echo "    this manually one-time. For each App ID below at"
echo "    https://developer.apple.com/account/resources/identifiers/list, click"
echo "    into it and check the listed capabilities:"
echo ""
echo "    - $MAIN_BUNDLE:"
echo "      HealthKit, App Groups (select group.com.threecee.loop.LoopGroup),"
echo "      Background Modes (Bluetooth Central + Background Fetch + Background Processing),"
echo "      Push Notifications, Sign in with Apple, Siri, Time Sensitive Notifications,"
echo "      Inter-App Audio"
echo ""
echo "    - $MAIN_BUNDLE.LoopWatch: HealthKit, App Groups, Background Modes"
echo "    - $MAIN_BUNDLE.LoopWatch.watchkitextension: HealthKit, App Groups, Background Modes"
echo "    - $MAIN_BUNDLE.Loop-Intent-Extension: App Groups, Siri"
echo "    - $MAIN_BUNDLE.LoopWidgetExtension: App Groups"
echo "    - $MAIN_BUNDLE.statuswidget: App Groups"
echo "    - $MAIN_BUNDLE.LoopUI: App Groups"
echo ""
read -r -p "    Press [Enter] when done..."

# ---- 4. Create App Store Connect record ----
echo "==> Step 4/7: Create App Store Connect record"
EXISTING_APP=$("$API" GET "/v1/apps?filter[bundleId]=$MAIN_BUNDLE" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['data'][0]['id'] if d.get('data') else '')
except Exception:
    print('')
")
if [ -n "$EXISTING_APP" ]; then
  echo "    ✓ ASC record already exists (id=$EXISTING_APP)"
else
  if cat <<JSON | "$API" POST /v1/apps >/dev/null 2>&1; then
{
  "data": {
    "type": "apps",
    "attributes": {
      "bundleId": "$MAIN_BUNDLE",
      "name": "$APP_NAME",
      "primaryLocale": "en-US",
      "sku": "$SKU"
    }
  }
}
JSON
    echo "    ✓ ASC record created"
  else
    echo "    ✗ API failed; MANUAL: create at"
    echo "      https://appstoreconnect.apple.com → My Apps → + → New App"
    echo "      Platform: iOS, Name: $APP_NAME, Bundle ID: $MAIN_BUNDLE,"
    echo "      Primary Language: English (US), SKU: $SKU"
    read -r -p "    Press [Enter] when done..."
  fi
fi

# ---- 5. App Information (categories + Privacy Policy URL) ----
echo "==> Step 5/7: App Information (MANUAL)"
echo "    https://appstoreconnect.apple.com → MyLoop With Watch → App Information"
echo "    - Privacy Policy URL: $PRIVACY_URL"
echo "    - Primary Category: Medical"
echo "    - Secondary Category: Health & Fitness"
echo "    - Content Rights: 'No, it does not contain...'"
echo "    - Age Rating: Set Age Rating → Medical/Treatment Information = 'Frequent/Intense', everything else 'None'"
echo ""
read -r -p "    Press [Enter] when done..."

# ---- 6. App Privacy questionnaire ----
echo "==> Step 6/7: App Privacy questionnaire (MANUAL)"
echo "    https://appstoreconnect.apple.com → MyLoop With Watch → App Privacy → Get Started"
echo "    Yes, we collect data. Then add 5 data types:"
echo ""
echo "    1. Health & Fitness > Health and Fitness Data"
echo "       linked: Yes, tracking: No, purpose: App Functionality"
echo "    2. Identifiers > Device ID  (CGM transmitter + pump pod serials)"
echo "       linked: Yes, tracking: No, purpose: App Functionality"
echo "    3. Diagnostics > Crash Data"
echo "       linked: Yes, tracking: No, purpose: App Functionality"
echo "    4. Diagnostics > Performance Data"
echo "       linked: Yes, tracking: No, purpose: App Functionality"
echo "    5. Other Data Types > Other Data Types  (Bluetooth pump telemetry)"
echo "       linked: Yes, tracking: No, purpose: App Functionality"
echo ""
echo "    Then click Publish."
echo ""
read -r -p "    Press [Enter] when done..."

# ---- 7. Internal Testing setup ----
echo "==> Step 7/7: Internal Testing — Family group + add Carl"
APP_ID="$EXISTING_APP"
if [ -z "$APP_ID" ]; then
  APP_ID=$("$API" GET "/v1/apps?filter[bundleId]=$MAIN_BUNDLE" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d['data'][0]['id'] if d.get('data') else '')
except Exception:
    print('')
")
fi

if [ -z "$APP_ID" ]; then
  echo "    ✗ couldn't resolve App ID; skipping Internal Testing setup"
  echo "    MANUAL: TestFlight tab → Internal Testing → + → group 'Family' → add yourself"
else
  EXISTING_GROUP=$("$API" GET "/v1/betaGroups?filter[app]=$APP_ID" 2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    fams = [g for g in d.get('data', []) if g.get('attributes', {}).get('name') == 'Family']
    print(fams[0]['id'] if fams else '')
except Exception:
    print('')
")
  if [ -z "$EXISTING_GROUP" ]; then
    if cat <<JSON | "$API" POST /v1/betaGroups >/dev/null 2>&1; then
{
  "data": {
    "type": "betaGroups",
    "attributes": { "name": "Family" },
    "relationships": {
      "app": { "data": { "type": "apps", "id": "$APP_ID" } }
    }
  }
}
JSON
      echo "    ✓ Family group created"
    else
      echo "    ✗ MANUAL: TestFlight → Internal Testing → + → group 'Family'"
    fi
  else
    echo "    ✓ Family group exists"
  fi
fi

# ---- Manual: Critical Alerts entitlement request ----
echo ""
echo "==> MANUAL (one-time): Submit Critical Alerts entitlement request"
echo ""
echo "    https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement"
echo ""
echo "    Form fields:"
echo "      App Name: $APP_NAME"
echo "      Bundle ID: $MAIN_BUNDLE"
echo "      Use case: Personal closed-loop insulin delivery for type-1 diabetes"
echo "                management. Critical Alerts notify the user of low-blood-glucose"
echo "                events and loop-failure conditions that can be life-threatening"
echo "                if missed (e.g., during sleep with Focus mode active)."
echo ""
echo "    Apple typically responds in 1-3 business days."
echo "    We ship without the entitlement for v1; re-add when approved."
echo "    (See docs/D1B_CRITICAL_ALERTS_PENDING.md after Phase 3.)"
echo ""
read -r -p "    Press [Enter] when submitted..."

echo ""
echo "==> setup.sh complete."
echo "    Next: run bin/release.sh to ship the first build."
