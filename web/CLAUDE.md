# Web (React + Vite + TypeScript)

- Entry: `src/main.tsx` -> `src/App.tsx`. Placeholder UI; replace freely.
- All backend calls go through `src/api.ts` (typed). Never `fetch` directly in components.
- `VITE_API_URL` is set at build time by `devops/scripts/deploy-web.sh`; locally
  the Vite dev server proxies `/api` to `localhost:8080`.
- Styling: CSS variables in `src/styles.css` mirror `docs/design/tokens.json`.
  Add a router (react-router) or data library (TanStack Query) when the app
  needs more than one screen; don't add them preemptively.
- Done means: `npm test` and `npm run build` pass.
