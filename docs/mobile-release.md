# Mobile release checklist

Builds happen in Expo's cloud (EAS); no Xcode or Android Studio required.

## One-time

- [ ] Create accounts: [Expo](https://expo.dev/signup), [Apple Developer](https://developer.apple.com/programs/) ($99/yr), [Google Play Console](https://play.google.com/console) ($25)
- [ ] Confirm `name`, `ios.bundleIdentifier`, `android.package` in `mobile/app.json`
- [ ] `cd mobile && npx eas-cli@latest login && npx eas-cli@latest init`, then commit `app.json`
- [ ] `npx eas-cli@latest credentials` for iOS (EAS creates certificates and profiles via your Apple login)
- [ ] `npx eas-cli@latest credentials` for Android (EAS generates the upload keystore)
- [ ] App Store Connect: create the app with the same bundle id
- [ ] Play Console: create the app; set up a service account with release permissions and add its JSON key via `eas credentials` (Android > Google Service Account)
- [ ] First Android release: build once (`profile=production`), download the `.aab` from expo.dev and upload it manually to the internal testing track (Google requires this once)
- [ ] Expo access token (expo.dev > Account settings > Access tokens), then `gh secret set EXPO_TOKEN`

## Every release

```bash
# internal test build against dev (installable via link/QR)
gh workflow run mobile-release.yml -f profile=preview -f env=dev

# store build against prod, auto-submitted to TestFlight + Play internal track
gh workflow run mobile-release.yml -f profile=production -f env=prod -f submit=true
```

Then promote in App Store Connect / Play Console after testing. Store review
needs a privacy policy URL, screenshots, and app description; Claude can draft these.

JS-only changes: `npx eas-cli@latest update --channel production` ships over the air.
