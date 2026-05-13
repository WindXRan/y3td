#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");

const {
  COPY_TREE_NAMES,
  MANIFEST_RELATIVE_PATH,
  TEXT_SUFFIXES,
  assertSafeWorkspace,
  extractCandidatePaths,
  extractFrontmatter,
  loadFrontmatterKeys,
  readText,
} = require("./migration-lib");

function normalizeSlashes(value) {
  return value.split(path.sep).join("/");
}

function userClaudeConfigPath() {
  return path.join(os.homedir(), ".claude.json");
}

function resolveManifestTargetFile(workspace, target, entry) {
  const targetScope = entry.targetScope || (target.startsWith("~/") ? "user" : "project");
  if (targetScope === "user") {
    return path.join(os.homedir(), target.replace(/^~[\\/]/, "").replaceAll("/", path.sep));
  }
  return path.join(workspace, target.replaceAll("/", path.sep));
}

function findMcpManifestEntry(manifest) {
  const files = manifest.files && typeof manifest.files === "object" ? manifest.files : {};
  return Object.entries(files).find(([, entry]) => entry.kind === "mcp-config") || null;
}

function verifyWorkspace(workspace, options = {}) {
  const issues = [];
  const claude = path.join(workspace, ".claude");
  const manifestFile = path.join(workspace, MANIFEST_RELATIVE_PATH.replaceAll("/", path.sep));
  const extraneousClaudeTempDirs = ["cmtmp"];
  let manifest = { files: {} };
  if (!fs.existsSync(claude)) {
    return {
      ok: false,
      issues: [{ type: "missing-path", path: ".claude", detail: "Missing .claude directory" }],
    };
  }

  for (const name of [...COPY_TREE_NAMES, "skills"]) {
    const target = path.join(claude, name);
    if (!fs.existsSync(target)) {
      issues.push({
        type: "missing-path",
        path: normalizeSlashes(path.relative(workspace, target)),
        detail: "Required migration output is missing",
      });
    }
  }

  if (fs.existsSync(manifestFile)) {
    manifest = JSON.parse(readText(manifestFile));
    const files = manifest.files && typeof manifest.files === "object" ? manifest.files : {};
    for (const [target, entry] of Object.entries(files)) {
      if (entry.status === "blocked") {
        issues.push({
          type: "merge-blocked",
          path: target,
          detail: entry.blockedReason || "Migration sync is blocked pending manual merge",
        });
      }
      if (entry.status === "orphaned") {
        issues.push({
          type: "orphaned-target",
          path: target,
          detail: entry.blockedReason || "Source file was removed from .y3maker but target is still retained",
        });
      }
    }
  }

  for (const name of extraneousClaudeTempDirs) {
    const target = path.join(claude, name);
    if (fs.existsSync(target)) {
      issues.push({
        type: "extra-temp-dir",
        path: normalizeSlashes(path.relative(workspace, target)),
        detail: "Temporary migration artifact should not be retained under .claude",
      });
    }
  }

  const skillRoot = path.join(claude, "skills");
  if (fs.existsSync(skillRoot)) {
    for (const skillName of fs.readdirSync(skillRoot).sort()) {
      const skillDir = path.join(skillRoot, skillName);
      if (!fs.statSync(skillDir).isDirectory()) {
        continue;
      }
      const skillFile = path.join(skillDir, "SKILL.md");
      const relSkill = normalizeSlashes(path.relative(workspace, skillFile));
      if (!fs.existsSync(skillFile)) {
        issues.push({ type: "missing-skill", path: relSkill, detail: "Missing SKILL.md" });
        continue;
      }
      const raw = fs.readFileSync(skillFile);
      if (raw[0] === 0xef && raw[1] === 0xbb && raw[2] === 0xbf) {
        issues.push({ type: "bom", path: relSkill, detail: "SKILL.md still has a UTF-8 BOM" });
      }
      let frontmatter;
      try {
        ({ frontmatter } = extractFrontmatter(readText(skillFile)));
      } catch (error) {
        issues.push({ type: "frontmatter", path: relSkill, detail: error.message });
        continue;
      }
      const extraKeys = loadFrontmatterKeys(frontmatter).filter(
        (key) => !["name", "description", "allowed-tools"].includes(key)
      );
      if (extraKeys.length > 0) {
        issues.push({
          type: "frontmatter",
          path: relSkill,
          detail: `Unexpected frontmatter keys: ${extraKeys.join(", ")}`,
        });
      }
      if (!frontmatter.includes(`name: ${skillName}`)) {
        issues.push({
          type: "frontmatter",
          path: relSkill,
          detail: "Frontmatter name does not match the directory name",
        });
      }
    }
  }

  const activeSurfaces = [path.join(claude, "knowledge"), path.join(claude, "rules"), path.join(claude, "skills")];
  const migrationSkill = path.join(claude, "skills", "sync-y3maker-to-claude");
  for (const root of activeSurfaces) {
    if (!fs.existsSync(root)) {
      continue;
    }
    walk(root, (filePath) => {
      if (filePath.startsWith(`${migrationSkill}${path.sep}`)) {
        return;
      }
      if (!TEXT_SUFFIXES.has(path.extname(filePath).toLowerCase())) {
        return;
      }
      const relPath = normalizeSlashes(path.relative(workspace, filePath));
      const text = readText(filePath);
      if (text.includes(".codemaker")) {
        issues.push({ type: "stale-path", path: relPath, detail: "Contains legacy .codemaker path" });
      }
      if (text.includes(".codex")) {
        issues.push({ type: "stale-path", path: relPath, detail: "Contains Codex .codex path" });
      }
      if (text.includes(".y3maker/") || text.includes(".y3maker\\")) {
        issues.push({ type: "stale-path", path: relPath, detail: "Contains legacy .y3maker path" });
      }
      for (const candidate of extractCandidatePaths(text)) {
        if (shouldSkipReference(candidate)) {
          continue;
        }
        const target = resolveReferenceTarget(workspace, filePath, candidate);
        if (!fs.existsSync(target)) {
          issues.push({
            type: "missing-reference",
            path: relPath,
            detail: `Referenced path does not exist: ${candidate}`,
          });
        }
      }
    });
  }

  if (fs.existsSync(path.join(workspace, ".y3maker", "mcp_settings.json"))) {
    const requestedScope = options.mcpScope || null;
    const recordedMcp = manifest.mcp || {};
    const recordedScope = recordedMcp.scope || null;
    const manifestEntry = findMcpManifestEntry(manifest);
    const effectiveScope = requestedScope || recordedScope || (manifestEntry ? manifestEntry[1].targetScope : null);

    if (effectiveScope === "skip") {
      return { ok: issues.length === 0, issues };
    }

    if (effectiveScope === "project") {
      if (!fs.existsSync(path.join(workspace, ".mcp.json"))) {
        issues.push({
          type: "missing-path",
          path: ".mcp.json",
          detail: "Legacy MCP settings exist and project-level MCP migration was selected, but the converted Claude MCP config is missing",
        });
      }
    } else if (effectiveScope === "user") {
      if (!fs.existsSync(userClaudeConfigPath())) {
        issues.push({
          type: "missing-path",
          path: "~/.claude.json",
          detail: "Legacy MCP settings exist and user-level MCP migration was selected, but the converted Claude MCP config is missing",
        });
      }
    } else if (manifestEntry) {
      const [target, entry] = manifestEntry;
      if (!fs.existsSync(resolveManifestTargetFile(workspace, target, entry))) {
        issues.push({
          type: "missing-path",
          path: target,
          detail: "Legacy MCP settings exist but the recorded MCP migration target is missing",
        });
      }
    } else if (!fs.existsSync(path.join(workspace, ".mcp.json"))) {
      issues.push({
        type: "mcp-target-unselected",
        path: ".y3maker/mcp_settings.json",
        detail: "Legacy MCP settings exist but no explicit MCP migration target was recorded; rerun apply with --mcp-scope project, user, or skip",
      });
    }
  }

  return { ok: issues.length === 0, issues };
}

function shouldSkipReference(candidate) {
  return (
    candidate.includes("{") ||
    candidate.includes("}") ||
    candidate.includes("...") ||
    candidate.includes("xxx") ||
    candidate.endsWith("AutoTestPlan.md") ||
    candidate.endsWith("env_setup_done")
  );
}

function resolveReferenceTarget(workspace, filePath, candidate) {
  if (candidate.startsWith("scripts/")) {
    return path.join(path.dirname(filePath), candidate.replaceAll("/", path.sep));
  }
  return path.join(workspace, candidate.replaceAll("/", path.sep));
}

function walk(target, onFile) {
  for (const name of fs.readdirSync(target).sort()) {
    const current = path.join(target, name);
    const stats = fs.statSync(current);
    if (stats.isDirectory()) {
      walk(current, onFile);
    } else {
      onFile(current);
    }
  }
}

function parseArgs(argv) {
  const options = { workspace: ".", pretty: false, allowUnsafeWorkspace: false, mcpScope: null };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token === "--workspace") {
      index += 1;
      options.workspace = argv[index];
    } else if (token === "--pretty") {
      options.pretty = true;
    } else if (token === "--allow-unsafe-workspace") {
      options.allowUnsafeWorkspace = true;
    } else if (token === "--mcp-scope") {
      index += 1;
      options.mcpScope = argv[index];
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }
  if (options.mcpScope && !["project", "user", "skip"].includes(options.mcpScope)) {
    throw new Error(`Invalid --mcp-scope: ${options.mcpScope}. Expected project, user, or skip.`);
  }
  return options;
}

function main() {
  try {
    const options = parseArgs(process.argv.slice(2));
    const workspace = path.resolve(options.workspace);
    assertSafeWorkspace(workspace, options);
    const payload = verifyWorkspace(workspace, options);
    process.stdout.write(`${JSON.stringify(payload, null, options.pretty ? 2 : 0)}\n`);
    process.exitCode = payload.ok ? 0 : 1;
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exitCode = 1;
  }
}

main();
