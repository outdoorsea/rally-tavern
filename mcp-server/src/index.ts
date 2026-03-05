#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);

// Resolve rally_tavern root relative to this file
const __dirname = dirname(fileURLToPath(import.meta.url));
const TAVERN_ROOT = process.env.RALLY_TAVERN_ROOT ?? resolve(__dirname, "../..");
const SCRIPTS_DIR = resolve(TAVERN_ROOT, "scripts");

// --- Helpers ---

async function runScript(
  script: string,
  args: string[],
  options?: { cwd?: string }
): Promise<{ stdout: string; stderr: string }> {
  const scriptPath = resolve(SCRIPTS_DIR, script);
  return execFileAsync("bash", [scriptPath, ...args], {
    cwd: options?.cwd ?? TAVERN_ROOT,
    env: { ...process.env, ARTIFACT_DIR_OVERRIDE: process.env.ARTIFACT_DIR_OVERRIDE },
    timeout: 30_000,
  });
}

function parseJsonSafe(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

// --- Server Setup ---

const server = new McpServer({
  name: "rally-tavern-mcp",
  version: "0.1.0",
});

// --- Discovery Tools ---

server.tool(
  "tavern.searchArtifacts",
  "Search the Rally Tavern artifact registry with optional filters",
  {
    tags: z.string().optional().describe("Comma-separated tags to filter by"),
    type: z
      .enum(["starter-template", "module", "skill", "mcp-server", "playbook"])
      .optional()
      .describe("Artifact type filter"),
    trustMin: z
      .enum(["experimental", "community", "verified"])
      .optional()
      .describe("Minimum trust level"),
    limit: z.number().int().positive().optional().describe("Max results to return"),
    sort: z
      .enum(["name", "trust", "tokenSavings"])
      .optional()
      .describe("Sort field"),
  },
  async ({ tags, type, trustMin, limit, sort }) => {
    const args: string[] = [];
    if (tags) args.push("--tags", tags);
    if (type) args.push("--type", type);
    if (trustMin) args.push("--trust", trustMin);

    const { stdout } = await runScript("artifacts-json.sh", args);
    const parsed = parseJsonSafe(stdout) as {
      artifacts?: Array<Record<string, unknown>>;
      count?: number;
      timestamp?: string;
    } | null;

    if (!parsed || !parsed.artifacts) {
      return { content: [{ type: "text" as const, text: stdout }] };
    }

    let artifacts = parsed.artifacts;

    // Sort
    if (sort === "trust") {
      const trustOrder: Record<string, number> = { experimental: 0, community: 1, verified: 2 };
      artifacts.sort(
        (a, b) =>
          (trustOrder[a.trust as string] ?? 0) - (trustOrder[b.trust as string] ?? 0)
      );
    } else if (sort === "tokenSavings") {
      artifacts.sort(
        (a, b) =>
          ((b.tokenSavingsEstimate as number) ?? 0) -
          ((a.tokenSavingsEstimate as number) ?? 0)
      );
    } else if (sort === "name") {
      artifacts.sort((a, b) =>
        String(a.name ?? "").localeCompare(String(b.name ?? ""))
      );
    }

    // Limit
    if (limit && limit > 0) {
      artifacts = artifacts.slice(0, limit);
    }

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { artifacts, count: artifacts.length, timestamp: parsed.timestamp },
            null,
            2
          ),
        },
      ],
    };
  }
);

server.tool(
  "tavern.getArtifact",
  "Get detailed information about a specific artifact",
  {
    artifactId: z
      .string()
      .describe("Artifact ID (namespace/name, e.g. io.github.rally-tavern/my-artifact)"),
    version: z.string().optional().describe("Specific version (currently unused, returns latest)"),
  },
  async ({ artifactId }) => {
    const { stdout } = await runScript("artifact.sh", ["show", artifactId]);
    return { content: [{ type: "text" as const, text: stdout }] };
  }
);

server.tool(
  "tavern.instantiateArtifact",
  "Copy an artifact's templates into a target directory with optional variable substitution",
  {
    artifactId: z
      .string()
      .describe("Artifact ID (namespace/name)"),
    version: z.string().optional().describe("Version (currently uses latest)"),
    targetDir: z.string().describe("Target directory to copy templates into"),
    answers: z
      .record(z.string(), z.string())
      .optional()
      .describe("Key-value pairs for template variable substitution (replaces {{key}} patterns)"),
  },
  async ({ artifactId, targetDir, answers }) => {
    const args = ["instantiate", artifactId, "--into", targetDir];
    if (answers) {
      for (const [key, value] of Object.entries(answers)) {
        args.push("--set", `${key}=${value}`);
      }
    }

    const { stdout } = await runScript("artifact.sh", args);
    return { content: [{ type: "text" as const, text: stdout }] };
  }
);

// --- Bounty Tools ---

server.tool(
  "tavern.listBounties",
  "List bounties from the Rally Tavern bounty board",
  {
    state: z
      .enum(["open", "claimed", "done"])
      .optional()
      .default("open")
      .describe("Bounty state to list"),
    type: z
      .enum(["looking-for", "build", "explain", "fix", "collab"])
      .optional()
      .describe("Filter by bounty type"),
    tags: z.string().optional().describe("Comma-separated tags to filter by"),
  },
  async ({ state, type, tags }) => {
    // bounties-json.sh only lists open bounties; for claimed/done we read directly
    if (state === "open") {
      const { stdout } = await runScript("bounties-json.sh", []);
      const parsed = parseJsonSafe(stdout) as Array<Record<string, unknown>> | null;

      if (!parsed) {
        return { content: [{ type: "text" as const, text: stdout }] };
      }

      let bounties = parsed;

      if (type) {
        bounties = bounties.filter((b) => b.type === type);
      }
      if (tags) {
        const tagList = tags.split(",").map((t) => t.trim().toLowerCase());
        bounties = bounties.filter((b) => {
          const bTags = Array.isArray(b.tags) ? b.tags.map(String) : [];
          return tagList.some((t) => bTags.some((bt) => bt.toLowerCase().includes(t)));
        });
      }

      return {
        content: [{ type: "text" as const, text: JSON.stringify(bounties, null, 2) }],
      };
    }

    // For claimed/done, list yaml files in that directory
    const { stdout } = await execFileAsync("bash", [
      "-c",
      'for f in "$1"/bounties/"$2"/*.yaml; do [ -f "$f" ] || continue; echo "--- $(basename "$f" .yaml)"; cat "$f"; echo; done',
      "--",
      TAVERN_ROOT,
      state,
    ], { cwd: TAVERN_ROOT, timeout: 15_000 });

    return { content: [{ type: "text" as const, text: stdout || `No ${state} bounties found.` }] };
  }
);

server.tool(
  "tavern.claimBounty",
  "Claim an open bounty for work",
  {
    bountyId: z.string().describe("Bounty ID to claim"),
    actor: z.string().describe("Name of the claimant"),
  },
  async ({ bountyId, actor }) => {
    const { stdout } = await runScript("claim.sh", [bountyId, "--name", actor]);
    return { content: [{ type: "text" as const, text: stdout }] };
  }
);

server.tool(
  "tavern.completeBounty",
  "Mark a claimed bounty as complete",
  {
    bountyId: z.string().describe("Bounty ID to complete"),
    artifactId: z
      .string()
      .optional()
      .describe("Artifact ID that resolved the bounty (format: namespace/name@version)"),
    summary: z.string().optional().describe("Summary of what was done"),
    tokenSavingsActual: z
      .number()
      .int()
      .optional()
      .describe("Actual token savings achieved"),
  },
  async ({ bountyId, artifactId, summary, tokenSavingsActual }) => {
    const args = [bountyId];
    if (summary) args.push("--summary", summary);
    if (artifactId) args.push("--artifact", artifactId);
    if (tokenSavingsActual !== undefined)
      args.push("--token-savings", String(tokenSavingsActual));

    const { stdout } = await runScript("complete.sh", args);
    return { content: [{ type: "text" as const, text: stdout }] };
  }
);

// --- Trust Tools ---

server.tool(
  "tavern.submitReview",
  "Submit a review verdict for an artifact (approve or flag)",
  {
    artifactId: z
      .string()
      .describe("Artifact ID (namespace/name)"),
    version: z.string().optional().describe("Version reviewed (informational)"),
    verdict: z
      .enum(["approve", "flag"])
      .describe("Review verdict: approve promotes trust, flag demotes"),
    notes: z
      .string()
      .optional()
      .describe("Review notes or reason for flagging"),
  },
  async ({ artifactId, verdict, notes }) => {
    if (verdict === "approve") {
      const { stdout } = await runScript("sheriff.sh", [
        "approve-artifact",
        artifactId,
      ]);
      return { content: [{ type: "text" as const, text: stdout }] };
    }

    // Flag
    const args = ["flag-artifact", artifactId];
    if (notes) args.push("--reason", notes);
    else args.push("--reason", "Flagged via MCP review");

    const { stdout } = await runScript("sheriff.sh", args);
    return { content: [{ type: "text" as const, text: stdout }] };
  }
);

server.tool(
  "tavern.getTrustReport",
  "Get trust and security report for an artifact",
  {
    artifactId: z
      .string()
      .describe("Artifact ID (namespace/name)"),
    version: z.string().optional().describe("Version (currently returns latest)"),
  },
  async ({ artifactId }) => {
    // Read artifact.yaml trust section + run security scan info
    const { stdout: showOutput } = await runScript("artifact.sh", ["show", artifactId]);

    // Try to read the trust section from artifact.yaml via yq
    let trustInfo = "";
    try {
      const { stdout: yqOutput } = await execFileAsync("yq", [
        "-o", "json",
        ".trust_tier, .trust, .fingerprints, .scoring",
        resolve(TAVERN_ROOT, "artifacts", artifactId, "artifact.yaml"),
      ], { timeout: 10_000 });
      trustInfo = yqOutput;
    } catch {
      // yq not available or file not found — fall back to show output
    }

    // Check for existing security reports
    let securityReports = "";
    try {
      // Pass artifactId as a positional arg to avoid shell injection
      const { stdout: reportOutput } = await execFileAsync("bash", [
        "-c",
        'for f in "$1"/security/reports/*.json; do [ -f "$f" ] || continue; content=$(cat "$f"); artifact=$(echo "$content" | jq -r \'.artifact // ""\' 2>/dev/null); [ "$artifact" = "$2" ] && echo "$content"; done',
        "--",
        TAVERN_ROOT,
        artifactId,
      ], { cwd: TAVERN_ROOT, timeout: 10_000 });
      if (reportOutput.trim()) {
        securityReports = "\n\nSecurity Reports:\n" + reportOutput;
      }
    } catch {
      // No reports or jq not available
    }

    const report = `Trust Report: ${artifactId}\n\n${showOutput}${trustInfo ? "\n\nTrust Details (JSON):\n" + trustInfo : ""}${securityReports}`;

    return { content: [{ type: "text" as const, text: report }] };
  }
);

// --- Start Server ---

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
