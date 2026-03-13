import React, { useEffect, useState } from "react";
import "./ShowcasePage.css";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface TokenGroup {
  label: string;
  prefix: string;
  render: "color" | "size" | "shadow" | "radius" | "timing" | "zindex" | "raw";
}

interface ResolvedToken {
  name: string;
  value: string;
}

// ---------------------------------------------------------------------------
// Configuration — extend these arrays to cover your project's token prefixes
// ---------------------------------------------------------------------------

const DEFAULT_TOKEN_GROUPS: TokenGroup[] = [
  // Colors
  { label: "Brand Colors", prefix: "--color-brand", render: "color" },
  { label: "Semantic Colors", prefix: "--color-semantic", render: "color" },
  { label: "Gray Scale", prefix: "--color-gray", render: "color" },
  { label: "Colors", prefix: "--color", render: "color" },

  // Typography
  { label: "Font Sizes", prefix: "--font-size", render: "size" },
  { label: "Font Weights", prefix: "--font-weight", render: "raw" },
  { label: "Line Heights", prefix: "--line-height", render: "raw" },
  { label: "Font Families", prefix: "--font-family", render: "raw" },

  // Spacing
  { label: "Spacing Scale", prefix: "--space", render: "size" },
  { label: "Spacing", prefix: "--spacing", render: "size" },

  // Shadows
  { label: "Shadows", prefix: "--shadow", render: "shadow" },

  // Borders & Radii
  { label: "Border Radii", prefix: "--radius", render: "radius" },
  { label: "Border Radii", prefix: "--border-radius", render: "radius" },

  // Z-Index
  { label: "Z-Index Layers", prefix: "--z-index", render: "zindex" },
  { label: "Z-Index", prefix: "--z-", render: "zindex" },

  // Transitions
  { label: "Transition Timings", prefix: "--transition", render: "timing" },
  { label: "Duration", prefix: "--duration", render: "timing" },
  { label: "Easing", prefix: "--ease", render: "raw" },
];

// ---------------------------------------------------------------------------
// Utility: read CSS custom properties from the document
// ---------------------------------------------------------------------------

function getCustomProperties(): Map<string, string> {
  const props = new Map<string, string>();
  const root = document.documentElement;
  const computed = getComputedStyle(root);

  for (const sheet of Array.from(document.styleSheets)) {
    try {
      for (const rule of Array.from(sheet.cssRules)) {
        if (
          rule instanceof CSSStyleRule &&
          rule.selectorText &&
          (rule.selectorText === ":root" ||
            rule.selectorText.includes("html") ||
            rule.selectorText === "*")
        ) {
          for (let i = 0; i < rule.style.length; i++) {
            const name = rule.style[i];
            if (name.startsWith("--")) {
              const value = computed.getPropertyValue(name).trim();
              if (value) props.set(name, value);
            }
          }
        }
      }
    } catch {
      // Cross-origin stylesheet — skip
    }
  }

  // Also pick up inline styles on :root
  for (let i = 0; i < root.style.length; i++) {
    const name = root.style[i];
    if (name.startsWith("--")) {
      const value = computed.getPropertyValue(name).trim();
      if (value) props.set(name, value);
    }
  }

  return props;
}

function resolveTokens(
  allProps: Map<string, string>,
  prefix: string
): ResolvedToken[] {
  const tokens: ResolvedToken[] = [];
  for (const [name, value] of allProps) {
    if (name.startsWith(prefix)) {
      tokens.push({ name, value });
    }
  }
  return tokens.sort((a, b) => a.name.localeCompare(b.name));
}

// ---------------------------------------------------------------------------
// Sub-components for each render type
// ---------------------------------------------------------------------------

function ColorSwatch({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-color">
      <div
        className="showcase-color__swatch"
        style={{ backgroundColor: `var(${token.name})` }}
      />
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function SizeToken({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-size">
      <div className="showcase-size__bar-container">
        <div
          className="showcase-size__bar"
          style={{ width: `var(${token.name})` }}
        />
      </div>
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function ShadowToken({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-shadow">
      <div
        className="showcase-shadow__box"
        style={{ boxShadow: `var(${token.name})` }}
      />
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function RadiusToken({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-radius">
      <div
        className="showcase-radius__box"
        style={{ borderRadius: `var(${token.name})` }}
      />
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function TimingToken({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-timing">
      <div className="showcase-timing__demo">
        <div
          className="showcase-timing__circle"
          style={{ transitionDuration: `var(${token.name})` }}
        />
      </div>
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function ZIndexToken({ token }: { token: ResolvedToken }) {
  return (
    <div className="showcase-token showcase-zindex">
      <div className="showcase-zindex__layer">
        <span className="showcase-zindex__number">{token.value}</span>
      </div>
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

function RawToken({ token }: { token: ResolvedToken }) {
  const isFontSize = token.name.includes("font-size");
  return (
    <div className="showcase-token showcase-raw">
      {isFontSize ? (
        <span
          className="showcase-raw__sample"
          style={{ fontSize: `var(${token.name})` }}
        >
          Aa
        </span>
      ) : null}
      <div className="showcase-token__info">
        <code className="showcase-token__name">{token.name}</code>
        <span className="showcase-token__value">{token.value}</span>
      </div>
    </div>
  );
}

const RENDERERS: Record<
  TokenGroup["render"],
  React.FC<{ token: ResolvedToken }>
> = {
  color: ColorSwatch,
  size: SizeToken,
  shadow: ShadowToken,
  radius: RadiusToken,
  timing: TimingToken,
  zindex: ZIndexToken,
  raw: RawToken,
};

// ---------------------------------------------------------------------------
// Section component
// ---------------------------------------------------------------------------

function TokenSection({
  group,
  tokens,
}: {
  group: TokenGroup;
  tokens: ResolvedToken[];
}) {
  const Renderer = RENDERERS[group.render];
  return (
    <section className="showcase-section">
      <h2 className="showcase-section__title">{group.label}</h2>
      <p className="showcase-section__subtitle">
        {tokens.length} token{tokens.length !== 1 ? "s" : ""} matching{" "}
        <code>{group.prefix}*</code>
      </p>
      <div className="showcase-section__grid">
        {tokens.map((t) => (
          <Renderer key={t.name} token={t} />
        ))}
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export interface ShowcasePageProps {
  /** Override or extend the default token groups */
  tokenGroups?: TokenGroup[];
  /** Page title */
  title?: string;
}

export default function ShowcasePage({
  tokenGroups,
  title = "Design System Tokens",
}: ShowcasePageProps) {
  const [allProps, setAllProps] = useState<Map<string, string>>(new Map());

  useEffect(() => {
    // Small delay to ensure stylesheets are loaded
    const timer = setTimeout(() => {
      setAllProps(getCustomProperties());
    }, 100);
    return () => clearTimeout(timer);
  }, []);

  const groups = tokenGroups ?? DEFAULT_TOKEN_GROUPS;

  // Only show groups that have matching tokens, deduplicate tokens across
  // more-specific prefixes (e.g. --color-brand before --color)
  const seen = new Set<string>();
  const visibleSections: { group: TokenGroup; tokens: ResolvedToken[] }[] = [];

  for (const group of groups) {
    const tokens = resolveTokens(allProps, group.prefix).filter(
      (t) => !seen.has(t.name)
    );
    if (tokens.length > 0) {
      tokens.forEach((t) => seen.add(t.name));
      visibleSections.push({ group, tokens });
    }
  }

  const totalTokens = visibleSections.reduce(
    (sum, s) => sum + s.tokens.length,
    0
  );

  return (
    <div className="showcase-page">
      <header className="showcase-header">
        <h1 className="showcase-header__title">{title}</h1>
        <p className="showcase-header__meta">
          {totalTokens} CSS custom properties across {visibleSections.length}{" "}
          categories
        </p>
      </header>

      {visibleSections.length === 0 && (
        <div className="showcase-empty">
          <p>No CSS custom properties found.</p>
          <p>
            Define tokens as <code>--color-*</code>, <code>--font-size-*</code>,{" "}
            <code>--space-*</code>, etc. on <code>:root</code> to see them here.
          </p>
        </div>
      )}

      <nav className="showcase-nav">
        {visibleSections.map(({ group }) => (
          <a
            key={group.prefix}
            className="showcase-nav__link"
            href={`#section-${group.prefix}`}
          >
            {group.label}
          </a>
        ))}
      </nav>

      <main className="showcase-main">
        {visibleSections.map(({ group, tokens }) => (
          <div key={group.prefix} id={`section-${group.prefix}`}>
            <TokenSection group={group} tokens={tokens} />
          </div>
        ))}
      </main>
    </div>
  );
}

export type { TokenGroup, ResolvedToken };
