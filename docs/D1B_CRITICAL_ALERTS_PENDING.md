# Critical Alerts entitlement — pending Apple approval

Filed via https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement
on 2026-05-01 as part of D.1b setup (MyLoop With Watch initial TestFlight).

**Status at time of D.1b shipping v1:** Loop's upstream `Loop.entitlements`
does NOT declare `com.apple.developer.usernotifications.critical-alerts`.
We ship v1 without it; alerts fire as regular notifications (silenceable
by Focus modes — document the limitation in user docs E.1).

When Apple approves (typically 1-3 business days):

1. Add the entitlement to `Loop/Loop/Loop.entitlements`. Insert this
   key+value into the `<dict>` block (alphabetical-ish insertion point
   for readability — between `time-sensitive` and the closing
   `application-groups`):

   ```xml
   <key>com.apple.developer.usernotifications.critical-alerts</key>
   <true/>
   ```

2. Verify the App ID `com.threecee.loop` has the matching capability
   enabled at https://developer.apple.com/account/resources/identifiers/list

3. Commit + ship a new build:

   ```bash
   cd ~/dev/LoopWorkspace/Loop
   git add Loop/Loop.entitlements
   git commit -m "feat: add Critical Alerts entitlement (Apple approved)

   threecee-claude"
   cd ~/dev/LoopWorkspace
   git add Loop
   git commit -m "submodule: advance Loop for Critical Alerts entitlement

   threecee-claude"
   bin/release.sh
   ```

4. Delete this file:

   ```bash
   git rm docs/D1B_CRITICAL_ALERTS_PENDING.md
   git commit -m "chore: remove D1B_CRITICAL_ALERTS_PENDING tracker"
   ```

If Apple denies the request: leave the entitlement absent. Loop's
alerts will fire as regular notifications — they can be silenced by Focus
modes, so document the limitation in the user docs (E.1).
