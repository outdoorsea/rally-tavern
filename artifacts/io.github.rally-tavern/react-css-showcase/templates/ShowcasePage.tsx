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

interface HardcodedMatch {
  /** The hardcoded value found in a stylesheet rule */
  value: string;
  /** The CSS selector where it was found */
  selector: string;
  /** The CSS property (e.g. "color", "background-color") */
  property: string;
  /** The token name that defines this same value */
  tokenName: string;
}

interface AdoptionReport {
  /** Hardcoded values in stylesheets that match a defined token */
  hardcodedMatches: HardcodedMatch[];
  /** Number of elements with inline styles in the DOM */
  inlineStyleCount: number;
  /** Total CSS custom property references found across all rules */
  tokenRefCount: number;
  /** Total hardcoded color/size values across all rules */
  hardcodedCount: number;
  /** Adoption percentage: tokenRefs / (tokenRefs + hardcoded) * 100 */
  adoptionPct: number;
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
// Adoption analysis: detect hardcoded values that should use tokens
// ---------------------------------------------------------------------------

/** Normalize a CSS color value to 6-digit lowercase hex for comparison. */
function normalizeColor(raw: string): string | null {
  const s = raw.trim().toLowerCase();

  // Already 6-digit hex
  if (/^#[0-9a-f]{6}$/.test(s)) return s;

  // 3-digit hex → expand
  const short = s.match(/^#([0-9a-f])([0-9a-f])([0-9a-f])$/);
  if (short) return `#${short[1]}${short[1]}${short[2]}${short[2]}${short[3]}${short[3]}`;

  // rgb(r, g, b)
  const rgb = s.match(/^rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)$/);
  if (rgb) {
    const hex = (n: string) => parseInt(n, 10).toString(16).padStart(2, "0");
    return `#${hex(rgb[1])}${hex(rgb[2])}${hex(rgb[3])}`;
  }

  return null;
}

/** Color-related CSS properties worth scanning. */
const COLOR_PROPS = new Set([
  "color",
  "background-color",
  "border-color",
  "border-top-color",
  "border-right-color",
  "border-bottom-color",
  "border-left-color",
  "outline-color",
  "fill",
  "stroke",
]);

const VAR_RE = /var\(--/;

function analyzeAdoption(tokenMap: Map<string, string>): AdoptionReport {
  // Build a reverse lookup: normalized hex → token name
  const hexToToken = new Map<string, string>();
  for (const [name, value] of tokenMap) {
    const hex = normalizeColor(value);
    if (hex) hexToToken.set(hex, name);
  }

  const hardcodedMatches: HardcodedMatch[] = [];
  let tokenRefCount = 0;
  let hardcodedCount = 0;

  for (const sheet of Array.from(document.styleSheets)) {
    try {
      for (const rule of Array.from(sheet.cssRules)) {
        if (!(rule instanceof CSSStyleRule)) continue;
        // Skip the showcase's own styles
        if (rule.selectorText.startsWith(".showcase-")) continue;

        for (let i = 0; i < rule.style.length; i++) {
          const prop = rule.style[i];
          const val = rule.style.getPropertyValue(prop).trim();

          // Count var(--*) references as token usage
          if (VAR_RE.test(val)) {
            tokenRefCount++;
            continue;
          }

          // Check color properties for hardcoded hex/rgb values
          if (COLOR_PROPS.has(prop)) {
            const hex = normalizeColor(val);
            if (hex) {
              hardcodedCount++;
              const match = hexToToken.get(hex);
              if (match) {
                hardcodedMatches.push({
                  value: val,
                  selector: rule.selectorText,
                  property: prop,
                  tokenName: match,
                });
              }
            }
          }
        }
      }
    } catch {
      // Cross-origin stylesheet — skip
    }
  }

  // Count elements with inline styles
  const allElements = document.querySelectorAll("[style]");
  const inlineStyleCount = allElements.length;

  const total = tokenRefCount + hardcodedCount;
  const adoptionPct = total > 0 ? Math.round((tokenRefCount / total) * 100) : 100;

  return {
    hardcodedMatches,
    inlineStyleCount,
    tokenRefCount,
    hardcodedCount,
    adoptionPct,
  };
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
// Adoption analysis section
// ---------------------------------------------------------------------------

function AdoptionGauge({ pct }: { pct: number }) {
  const color = pct >= 80 ? "#22c55e" : pct >= 50 ? "#f59e0b" : "#ef4444";
  return (
    <div className="showcase-adoption__gauge">
      <svg viewBox="0 0 120 120" width="120" height="120">
        <circle
          cx="60"
          cy="60"
          r="50"
          fill="none"
          stroke="#e5e7eb"
          strokeWidth="10"
        />
        <circle
          cx="60"
          cy="60"
          r="50"
          fill="none"
          stroke={color}
          strokeWidth="10"
          strokeDasharray={`${(pct / 100) * 314} 314`}
          strokeLinecap="round"
          transform="rotate(-90 60 60)"
        />
        <text
          x="60"
          y="60"
          textAnchor="middle"
          dominantBaseline="central"
          fontSize="24"
          fontWeight="700"
          fill={color}
        >
          {pct}%
        </text>
      </svg>
    </div>
  );
}

function AdoptionSection({ report }: { report: AdoptionReport }) {
  return (
    <section className="showcase-section showcase-adoption">
      <h2 className="showcase-section__title">Token Adoption</h2>
      <p className="showcase-section__subtitle">
        Migration scorecard — hardcoded values that could use design tokens
      </p>

      <div className="showcase-adoption__summary">
        <AdoptionGauge pct={report.adoptionPct} />
        <div className="showcase-adoption__stats">
          <div className="showcase-adoption__stat">
            <span className="showcase-adoption__stat-value">
              {report.tokenRefCount}
            </span>
            <span className="showcase-adoption__stat-label">
              Token references
            </span>
          </div>
          <div className="showcase-adoption__stat">
            <span className="showcase-adoption__stat-value">
              {report.hardcodedCount}
            </span>
            <span className="showcase-adoption__stat-label">
              Hardcoded values
            </span>
          </div>
          <div className="showcase-adoption__stat">
            <span className="showcase-adoption__stat-value">
              {report.inlineStyleCount}
            </span>
            <span className="showcase-adoption__stat-label">
              Inline styles
            </span>
          </div>
        </div>
      </div>

      {report.hardcodedMatches.length > 0 && (
        <div className="showcase-adoption__matches">
          <h3 className="showcase-adoption__matches-title">
            Replaceable Hardcoded Values ({report.hardcodedMatches.length})
          </h3>
          <table className="showcase-adoption__table">
            <thead>
              <tr>
                <th>Selector</th>
                <th>Property</th>
                <th>Hardcoded</th>
                <th>Use Instead</th>
              </tr>
            </thead>
            <tbody>
              {report.hardcodedMatches.map((m, i) => (
                <tr key={i}>
                  <td>
                    <code>{m.selector}</code>
                  </td>
                  <td>
                    <code>{m.property}</code>
                  </td>
                  <td>
                    <span className="showcase-adoption__hardcoded">
                      <span
                        className="showcase-adoption__color-dot"
                        style={{ backgroundColor: m.value }}
                      />
                      {m.value}
                    </span>
                  </td>
                  <td>
                    <code className="showcase-adoption__suggestion">
                      var({m.tokenName})
                    </code>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {report.hardcodedMatches.length === 0 && report.hardcodedCount === 0 && (
        <p className="showcase-adoption__clean">
          No hardcoded color values found — great token adoption!
        </p>
      )}
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
  /** Show the Token Adoption analysis section (default: true) */
  showAdoption?: boolean;
}

export default function ShowcasePage({
  tokenGroups,
  title = "Design System Tokens",
  showAdoption = true,
}: ShowcasePageProps) {
  const [allProps, setAllProps] = useState<Map<string, string>>(new Map());
  const [adoption, setAdoption] = useState<AdoptionReport | null>(null);

  useEffect(() => {
    // Small delay to ensure stylesheets are loaded
    const timer = setTimeout(() => {
      const props = getCustomProperties();
      setAllProps(props);
      if (showAdoption) {
        setAdoption(analyzeAdoption(props));
      }
    }, 100);
    return () => clearTimeout(timer);
  }, [showAdoption]);

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
        {adoption && (
          <a className="showcase-nav__link" href="#section-adoption">
            Token Adoption
          </a>
        )}
      </nav>

      <main className="showcase-main">
        {visibleSections.map(({ group, tokens }) => (
          <div key={group.prefix} id={`section-${group.prefix}`}>
            <TokenSection group={group} tokens={tokens} />
          </div>
        ))}
      </main>

      {adoption && (
        <div id="section-adoption">
          <AdoptionSection report={adoption} />
        </div>
      )}
    </div>
  );
}

export type { TokenGroup, ResolvedToken, AdoptionReport, HardcodedMatch };
