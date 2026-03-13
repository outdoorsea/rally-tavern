# Install: react-css-showcase

## What This Artifact Provides

A living CSS design system browser component (`<ShowcasePage />`) that reads CSS
custom properties from `:root` and renders them as visual swatches, scales, and
token cards. Drop it into any React app with CSS custom properties to get an
instant design system reference page.

## Installation Steps

1. **Copy the component files** into your project:
   ```
   templates/ShowcasePage.tsx  → src/components/ShowcasePage.tsx
   templates/ShowcasePage.css  → src/components/ShowcasePage.css
   templates/index.ts          → src/components/showcase/index.ts
   ```

2. **Add a route** in your router (React Router example):
   ```tsx
   import { ShowcasePage } from "./components/showcase";

   // In your router config:
   <Route path="/showcase" element={<ShowcasePage />} />
   // or
   <Route path="/_style" element={<ShowcasePage title="Style Guide" />} />
   ```

3. **Ensure your CSS custom properties are on `:root`** — the component reads
   them automatically. Common prefixes it looks for:
   - `--color-*` (brand, semantic, gray scale)
   - `--font-size-*`, `--font-weight-*`, `--font-family-*`
   - `--space-*`, `--spacing-*`
   - `--shadow-*`
   - `--radius-*`, `--border-radius-*`
   - `--z-index-*`, `--z-*`
   - `--transition-*`, `--duration-*`, `--ease-*`

## Customization

Pass custom `tokenGroups` to extend or override the default token detection:

```tsx
<ShowcasePage
  title="Acme Design Tokens"
  tokenGroups={[
    { label: "Primary Colors", prefix: "--acme-primary", render: "color" },
    { label: "Spacing", prefix: "--acme-gap", render: "size" },
    // ...
  ]}
/>
```

## Requirements

- React 17+ (uses hooks)
- TypeScript optional (JS-compatible via compiled output)
- No external dependencies
