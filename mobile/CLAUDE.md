# Mobile (Expo / React Native)

@AGENTS.md

Project specifics:

- Backend calls go through `src/api.ts` (mirror of `web/src/api.ts`; keep in sync).
- `EXPO_PUBLIC_API_URL` is injected by CI from the Terraform `api_url` output.
  Locally `make mobile` points it at `http://localhost:8080` (use your LAN IP
  instead of localhost when testing on a physical phone).
- Theme tokens: `src/theme.ts` mirrors `docs/design/tokens.json`.
- Install native packages with `npx expo install <pkg>`, never plain `npm install`.
- Releases: see the `release-mobile` skill and `docs/mobile-release.md`.
- Done means: `npm run typecheck` and `npx expo install --check` pass.
