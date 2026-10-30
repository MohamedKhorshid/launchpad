---
name: design-to-code
description: Implement a UI design (Claude Design export, Figma link, screenshot, or HTML mockup) in the web and mobile apps with shared design tokens. Use when the user shares a design, mockup, screenshot, or asks to "build this screen" / "match this design".
---

# Design -> code

## Inputs you may get

- **Claude Design / HTML mockup**: read the HTML/CSS; it is the most precise source.
- **Figma link**: use the Figma MCP server if connected; otherwise ask for an export.
- **Screenshots**: infer layout, spacing and colors; state assumptions you made.

## Steps

1. **Extract tokens** (colors incl. dark mode, font sizes, radius, spacing) and
   update `docs/design/tokens.json`. Then mirror them in:
   - `web/src/styles.css` (`:root` CSS variables)
   - `mobile/src/theme.ts`
   Token names must match across the three files.
2. **Inventory components** in the design (buttons, inputs, cards, lists, nav).
   Build each once per platform: `web/src/components/`, `mobile/src/components/`.
   Use tokens only; no hard-coded colors or sizes in components.
3. **Build screens** listed in `docs/product/spec.md`. Web and mobile should
   share names, structure and behavior, adapted to platform conventions
   (mobile: safe areas, touch targets >= 44pt, native navigation via Expo Router
   once there are multiple screens).
4. **Wire data** only through `src/api.ts` in each app. If an endpoint is
   missing, add it to the backend first (see `add-backend-module`).
5. **States**: every screen handles loading, empty, error, and success.
6. **Verify**: `cd web && npm run build`, `cd mobile && npm run typecheck`.
   Run `make dev` and describe what to check in the browser. If a browser tool is
   available, screenshot the web app and compare against the design.

If the `frontend-design` plugin is enabled, use it for aesthetic decisions the
design leaves open.
