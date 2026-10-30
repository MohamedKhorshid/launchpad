---
name: release-mobile
description: Build and ship the Expo app to TestFlight / App Store and Google Play using EAS. Use when the user wants a mobile build, an internal test build, or to publish to the app stores.
---

# Release the mobile app

Full human checklist: `docs/mobile-release.md`. Your job is to drive it.

## First release (one-time)

Check each; stop and tell the user exactly what to do for anything missing:

1. **Accounts**: Expo (free), Apple Developer Program ($99/yr), Google Play Console ($25 once).
2. **Identity**: `mobile/app.json` has the real `name`, `ios.bundleIdentifier`,
   `android.package` (set by bootstrap; changing later means a new store listing).
3. **Link EAS**: user runs `cd mobile && npx eas-cli@latest login && npx eas-cli@latest init`
   (writes `extra.eas.projectId` into app.json; commit it).
4. **Credentials**: user runs `npx eas-cli@latest credentials` once per platform,
   letting EAS manage signing. For Android submissions, a Google Play service
   account JSON key is uploaded through `eas credentials` (never committed).
5. **Store listings**: create the app in App Store Connect and Play Console.
   Google requires the first upload to be done manually; download the first
   production `.aab` from EAS and upload it in Play Console.
6. **CI token**: create an Expo access token and add it as the `EXPO_TOKEN`
   repo secret: `gh secret set EXPO_TOKEN`.

## Each release

- Internal test build (no stores): `gh workflow run mobile-release.yml -f profile=preview -f env=dev`
- Store release: `gh workflow run mobile-release.yml -f profile=production -f env=prod -f submit=true`
  (iOS lands in TestFlight; Android in the internal testing track. Promote in the consoles.)
- JS-only fixes can ship over the air: `npx eas-cli@latest update --channel production`
  (only when no native dependency changed).

Before any release: `npm run typecheck`, `npx expo install --check`, and confirm
the target backend env is deployed (`tf.sh <env> output -raw api_url`).
