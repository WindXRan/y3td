#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { TextDecoder } = require("util");

const TEXT_SUFFIXES = new Set([
  ".json",
  ".md",
  ".mdc",
  ".ps1",
  ".py",
  ".toml",
  ".txt",
  ".yaml",
  ".yml",
]);
const COPY_TREE_NAMES = ["knowledge", "memory", "rules"];
const CLAUDE_DIR_NAMES = ["knowledge", "memory", "rules", "skills", "migration"];
const DEFAULT_OPENSPEC_DIRS = ["openspec/docs", "openspec/reports"];
const EXTRA_CLAUDE_TEMP_DIRS = ["cmtmp"];
const SKILL_ITEM_EXCLUDES = {
  "y3-auto-test": new Set([".queue"]),
  "y3-obj-gen": new Set([".claude-plugin"]),
};
const FRONTMATTER_PATTERN = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/;
const ACTIVE_PATH_PATTERN = /`((?:\.claude|\.omc|\.mcp\.json|CLAUDE\.md|openspec|scripts)\/[^`\n]*|(?:\.claude|\.omc|openspec|scripts)\/[^`\n]+)`/g;
const MANIFEST_VERSION = 1;
const MANIFEST_RELATIVE_PATH = ".claude/migration/y3maker-manifest.json";
const MCP_SCOPES = new Set(["project", "user", "skip"]);

function normalizeSlashes(value) {
  return value.split(path.sep).join("/");
}

function isSameOrInsidePath(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function getUnsafeWorkspaceReason(workspace) {
  const resolved = path.resolve(workspace);
  const parsed = path.parse(resolved);
  if (resolved === parsed.root) {
    return `Workspace resolves to a filesystem root: ${resolved}`;
  }

  const home = path.resolve(os.homedir());
  if (resolved === home) {
    return `Workspace resolves to the user home directory: ${resolved}`;
  }

  const claudeHome = path.join(home, ".claude");
  if (isSameOrInsidePath(claudeHome, resolved)) {
    return `Workspace resolves inside the user-level Claude home: ${resolved}`;
  }

  return null;
}

function assertSafeWorkspace(workspace, options = {}) {
  if (options.allowUnsafeWorkspace) {
    return;
  }
  const reason = getUnsafeWorkspaceReason(workspace);
  if (!reason) {
    return;
  }
  throw new Error(
    `${reason}. Refusing migration guard check. Re-run with --allow-unsafe-workspace only if this target is intentional.`
  );
}

function sortedEntries(target) {
  if (!fs.existsSync(target) || !fs.statSync(target).isDirectory()) {
    return [];
  }
  return fs.readdirSync(target).sort();
}

function workspacePaths(workspace) {
  const root = path.resolve(workspace);
  return {
    workspace: root,
    legacy: path.join(root, ".y3maker"),
    claude: path.join(root, ".claude"),
    omc: path.join(root, ".omc"),
    claudeMd: path.join(root, "CLAUDE.md"),
    projectMcp: path.join(root, ".mcp.json"),
    manifest: path.join(root, MANIFEST_RELATIVE_PATH.replaceAll("/", path.sep)),
  };
}

function userClaudeConfigPath() {
  return path.join(os.homedir(), ".claude.json");
}

function readText(filePath) {
  const raw = fs.readFileSync(filePath);
  const decoders = [
    new TextDecoder("utf-8", { fatal: true }),
    new TextDecoder("gb18030", { fatal: true }),
  ];
  for (const decoder of decoders) {
    try {
      let text = decoder.decode(raw);
      if (text.charCodeAt(0) === 0xfeff) {
        text = text.slice(1);
      }
      return text;
    } catch (error) {
      continue;
    }
  }
  throw new Error(`Unable to decode ${filePath}`);
}

function writeText(filePath, content, dryRun) {
  if (dryRun) {
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const normalized = content.replace(/\r\n/g, "\n");
  fs.writeFileSync(filePath, Buffer.from(normalized, "utf8"));
}

function writeBuffer(filePath, content, dryRun) {
  if (dryRun) {
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function ensureDir(target, dryRun) {
  if (dryRun) {
    return;
  }
  fs.mkdirSync(target, { recursive: true });
}

function hashBuffer(content) {
  return crypto.createHash("sha256").update(content).digest("hex");
}

function hashExistingFile(filePath) {
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    return null;
  }
  if (TEXT_SUFFIXES.has(path.extname(filePath).toLowerCase())) {
    return hashBuffer(Buffer.from(readText(filePath).replace(/\r\n/g, "\n"), "utf8"));
  }
  return hashBuffer(fs.readFileSync(filePath));
}

function emptyManifest() {
  return {
    version: MANIFEST_VERSION,
    tool: "sync-y3maker-to-claude",
    updatedAt: null,
    files: {},
  };
}

function loadManifest(workspace) {
  const { manifest } = workspacePaths(workspace);
  if (!fs.existsSync(manifest)) {
    return emptyManifest();
  }
  const parsed = JSON.parse(readText(manifest));
  return {
    version: parsed.version || MANIFEST_VERSION,
    tool: parsed.tool || "sync-y3maker-to-claude",
    updatedAt: parsed.updatedAt || null,
    files: parsed.files && typeof parsed.files === "object" ? parsed.files : {},
    mcp: parsed.mcp && typeof parsed.mcp === "object" ? parsed.mcp : null,
  };
}

function writeManifest(workspace, manifest, dryRun) {
  const { manifest: manifestFile } = workspacePaths(workspace);
  const payload = {
    version: MANIFEST_VERSION,
    tool: "sync-y3maker-to-claude",
    updatedAt: new Date().toISOString(),
    files: manifest.files,
  };
  if (manifest.mcp) {
    payload.mcp = manifest.mcp;
  }
  writeText(manifestFile, `${JSON.stringify(payload, null, 2)}\n`, dryRun);
}

function inventoryWorkspace(workspace) {
  const paths = workspacePaths(workspace);
  const manifest = loadManifest(workspace);
  const manifestEntries = Object.values(manifest.files || {});
  const result = {
    workspace: paths.workspace,
    exists: {
      ".y3maker": fs.existsSync(paths.legacy),
      ".claude": fs.existsSync(paths.claude),
      ".omc": fs.existsSync(paths.omc),
      "CLAUDE.md": fs.existsSync(paths.claudeMd),
      ".mcp.json": fs.existsSync(paths.projectMcp),
    },
    manifest: {
      path: MANIFEST_RELATIVE_PATH,
      exists: fs.existsSync(paths.manifest),
      trackedFiles: manifestEntries.length,
      blockedFiles: manifestEntries.filter((entry) => entry.status === "blocked").length,
      orphanedTargets: manifestEntries.filter((entry) => entry.status === "orphaned").length,
    },
    legacy: {},
  };
  if (fs.existsSync(paths.legacy)) {
    result.legacy = {
      entries: sortedEntries(paths.legacy),
      skills: sortedEntries(path.join(paths.legacy, "skills")).filter((name) =>
        fs.statSync(path.join(paths.legacy, "skills", name)).isDirectory()
      ),
      rules: sortedEntries(path.join(paths.legacy, "rules")).filter((name) =>
        fs.statSync(path.join(paths.legacy, "rules", name)).isFile()
      ),
      knowledge: sortedEntries(path.join(paths.legacy, "knowledge")),
      memory: sortedEntries(path.join(paths.legacy, "memory")),
      hasMcpSettings: fs.existsSync(path.join(paths.legacy, "mcp_settings.json")),
    };
  }
  return result;
}

function normalizeApplyOptions(dryRunOrOptions) {
  if (typeof dryRunOrOptions === "boolean") {
    return { dryRun: dryRunOrOptions, mcpScope: null };
  }
  const options = dryRunOrOptions || {};
  return {
    dryRun: Boolean(options.dryRun),
    mcpScope: options.mcpScope || null,
  };
}

function normalizeMcpScope(mcpScope) {
  if (!mcpScope) {
    return null;
  }
  if (!MCP_SCOPES.has(mcpScope)) {
    throw new Error(`Invalid MCP scope: ${mcpScope}. Expected project, user, or skip.`);
  }
  return mcpScope;
}

function extractFrontmatter(text) {
  const match = text.match(FRONTMATTER_PATTERN);
  if (!match) {
    throw new Error("Missing or invalid frontmatter");
  }
  return { frontmatter: match[1], body: match[2] };
}

function extractFrontmatterField(frontmatter, fieldName) {
  const lines = frontmatter.split(/\r?\n/);
  const start = lines.findIndex((line) => line.startsWith(`${fieldName}:`));
  if (start < 0) {
    return null;
  }
  const fieldLines = [lines[start]];
  for (let index = start + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (line && !/^\s/.test(line)) {
      break;
    }
    fieldLines.push(line);
  }
  return fieldLines;
}

function loadFrontmatterKeys(frontmatter) {
  return frontmatter
    .split(/\r?\n/)
    .filter((line) => line && !/^\s/.test(line) && line.includes(":"))
    .map((line) => line.split(":", 1)[0].trim());
}

function extractCandidatePaths(text) {
  const results = [];
  for (const match of text.matchAll(ACTIVE_PATH_PATTERN)) {
    const candidate = match[1].trim();
    if (/[{}*<>]/.test(candidate) || candidate === ".mcp.json" || candidate === "CLAUDE.md") {
      continue;
    }
    results.push(candidate);
  }
  return results;
}

function collectFiles(root, options = {}) {
  const files = [];

  function walk(currentDir, relativeDir) {
    for (const name of sortedEntries(currentDir)) {
      const relativePath = relativeDir ? `${relativeDir}/${name}` : name;
      if (options.skipRelativePath && options.skipRelativePath(relativePath)) {
        continue;
      }
      const currentPath = path.join(currentDir, name);
      const stats = fs.statSync(currentPath);
      if (stats.isDirectory()) {
        walk(currentPath, relativePath);
      } else if (stats.isFile()) {
        files.push(relativePath);
      }
    }
  }

  if (fs.existsSync(root)) {
    walk(root, "");
  }
  return files;
}

function normalizeSkillFrontmatterText(skillName, original) {
  const { frontmatter, body } = extractFrontmatter(original);
  const descriptionLines = extractFrontmatterField(frontmatter, "description");
  if (!descriptionLines) {
    throw new Error("Missing description field");
  }
  const allowedToolsLines = extractFrontmatterField(frontmatter, "allowed-tools") || extractFrontmatterField(frontmatter, "tools");
  const normalized = [`---`, `name: ${skillName}`, ...descriptionLines];
  if (allowedToolsLines) {
    normalized.push(allowedToolsLines.join("\n").replace(/^tools:/, "allowed-tools:"));
  }
  normalized.push("---", "");
  return `${normalized.join("\n")}\n${body.replace(/^\r?\n+/, "").replace(/\s+$/, "")}\n`;
}

function normalizeClaudeMcpTransport(config) {
  if (config.type === "streamableHttp" || config.type === "http") {
    return "http";
  }
  if (config.type === "sse") {
    return "sse";
  }
  if (config.type === "stdio") {
    return "stdio";
  }
  return config.url ? "http" : "stdio";
}

function normalizeClaudeMcpServer(config) {
  const normalized = {};
  if (config.url) {
    normalized.type = normalizeClaudeMcpTransport(config);
    normalized.url = config.url;
  }
  if (config.command) {
    normalized.type = normalizeClaudeMcpTransport(config);
    normalized.command = config.command;
  }
  if (Array.isArray(config.args) && config.args.length > 0) {
    normalized.args = config.args;
  }
  if (config.env && Object.keys(config.env).length > 0) {
    normalized.env = config.env;
  }
  if (config.headers && Object.keys(config.headers).length > 0) {
    normalized.headers = config.headers;
  }
  return normalized;
}

function inspectLegacyMcp(legacyFile) {
  const payload = JSON.parse(readText(legacyFile));
  const servers = payload.mcpServers && typeof payload.mcpServers === "object" ? payload.mcpServers : {};
  const enabled = [];
  const disabled = [];
  for (const name of Object.keys(servers).sort()) {
    if (servers[name] && servers[name].disabled) {
      disabled.push(name);
    } else {
      enabled.push(name);
    }
  }
  return {
    empty: Object.keys(servers).length === 0,
    enabled,
    disabled,
  };
}

function buildClaudeMcpFromLegacy(legacyFile, existingFile = null) {
  const payload = JSON.parse(readText(legacyFile));
  const servers = payload.mcpServers || {};
  const existing = existingFile && fs.existsSync(existingFile) ? JSON.parse(readText(existingFile)) : {};
  const next = existing && typeof existing === "object" && !Array.isArray(existing) ? existing : {};
  const nextServers = next.mcpServers && typeof next.mcpServers === "object" ? { ...next.mcpServers } : {};
  const converted = [];
  const skipped = [];
  const empty = Object.keys(servers).length === 0;
  for (const name of Object.keys(servers).sort()) {
    const config = servers[name];
    if (config.disabled) {
      skipped.push(name);
      continue;
    }
    nextServers[name] = normalizeClaudeMcpServer(config);
    converted.push(name);
  }
  next.mcpServers = nextServers;
  return {
    content: `${JSON.stringify(next, null, 2)}\n`,
    servers: converted,
    skipped,
    empty,
    warnings: empty ? [".y3maker/mcp_settings.json has an empty mcpServers object"] : [],
  };
}

function buildMigrationPlan(workspace, options = {}) {
  const paths = workspacePaths(workspace);
  const filePlans = [];
  const copied = { knowledge: [], memory: [], rules: [], skills: [] };
  const mcpScope = normalizeMcpScope(options.mcpScope);

  for (const name of COPY_TREE_NAMES) {
    const sourceRoot = path.join(paths.legacy, name);
    const targetRoot = path.join(paths.claude, name);
    if (!fs.existsSync(sourceRoot)) {
      continue;
    }
    copied[name] = sortedEntries(sourceRoot);
    for (const relativeFile of collectFiles(sourceRoot)) {
      filePlans.push({
        kind: name,
        sourceFile: path.join(sourceRoot, relativeFile.replaceAll("/", path.sep)),
        sourceRelative: normalizeSlashes(path.relative(paths.workspace, path.join(sourceRoot, relativeFile.replaceAll("/", path.sep)))),
        targetFile: path.join(targetRoot, relativeFile.replaceAll("/", path.sep)),
        targetRelative: normalizeSlashes(path.relative(paths.workspace, path.join(targetRoot, relativeFile.replaceAll("/", path.sep)))),
      });
    }
  }

  const skillsRoot = path.join(paths.legacy, "skills");
  const targetSkillsRoot = path.join(paths.claude, "skills");
  if (fs.existsSync(skillsRoot)) {
    for (const skillName of sortedEntries(skillsRoot)) {
      const sourceSkillDir = path.join(skillsRoot, skillName);
      if (!fs.statSync(sourceSkillDir).isDirectory()) {
        continue;
      }
      copied.skills.push(skillName);
      const excluded = SKILL_ITEM_EXCLUDES[skillName] || new Set();
      for (const relativeFile of collectFiles(sourceSkillDir, {
        skipRelativePath(relativePath) {
          const topLevelName = relativePath.split("/", 1)[0];
          return excluded.has(topLevelName);
        },
      })) {
        const sourceFile = path.join(sourceSkillDir, relativeFile.replaceAll("/", path.sep));
        const targetFile = path.join(targetSkillsRoot, skillName, relativeFile.replaceAll("/", path.sep));
        filePlans.push({
          kind: "skill",
          skillName,
          sourceFile,
          sourceRelative: normalizeSlashes(path.relative(paths.workspace, sourceFile)),
          targetFile,
          targetRelative: normalizeSlashes(path.relative(paths.workspace, targetFile)),
        });
      }
    }
  }

  const legacyMcp = path.join(paths.legacy, "mcp_settings.json");
  const hasLegacyMcp = fs.existsSync(legacyMcp);
  const mcpSelection = {
    hasLegacyMcp,
    scope: mcpScope,
    targetRelative: null,
    targetFile: null,
    empty: false,
    servers: [],
    skipped: [],
  };
  if (fs.existsSync(legacyMcp)) {
    const legacyMcpInfo = inspectLegacyMcp(legacyMcp);
    mcpSelection.empty = legacyMcpInfo.empty;
    mcpSelection.servers = legacyMcpInfo.enabled;
    mcpSelection.skipped = legacyMcpInfo.disabled;
    if (!mcpScope) {
      throw new Error(
        "Legacy MCP settings exist; refusing to modify MCP config silently. Re-run with --mcp-scope project, --mcp-scope user, or --mcp-scope skip."
      );
    }
    if (mcpScope !== "skip") {
      const targetFile = mcpScope === "project" ? paths.projectMcp : userClaudeConfigPath();
      const targetRelative = mcpScope === "project" ? ".mcp.json" : "~/.claude.json";
      mcpSelection.targetFile = targetFile;
      mcpSelection.targetRelative = targetRelative;
      filePlans.push({
        kind: "mcp-config",
        sourceFile: legacyMcp,
        sourceRelative: normalizeSlashes(path.relative(paths.workspace, legacyMcp)),
        targetFile,
        targetRelative,
        targetScope: mcpScope,
      });
    }
  }

  return { paths, filePlans, copied, mcpSelection };
}

function materializeTextPlan(plan, workspace) {
  let content = readText(plan.sourceFile);
  const flags = {
    rewrittenLegacyPaths: false,
    normalizedSkillFrontmatter: false,
    appliedSpecialFixes: [],
  };

  const legacyRewritten = content
    .replace(/<agent>/g, ".claude")
    .replace(/<codemaker>/g, ".claude")
    .replace(/\.codemaker/g, ".claude")
    .replace(/\.codex/g, ".claude");
  if (legacyRewritten !== content) {
    content = legacyRewritten;
    flags.rewrittenLegacyPaths = true;
  }

  if (
    plan.targetFile.includes(`${path.sep}y3-auto-test${path.sep}`) &&
    (path.basename(plan.targetFile) === "admin_daemon.ps1" || path.basename(plan.targetFile) === "send_command.ps1")
  ) {
    const updated = content.replace(
      /\.\\\.claude\\skills\\desktop-automation/g,
      ".\\.claude\\skills\\y3-auto-test"
    );
    if (updated !== content) {
      content = updated;
      flags.appliedSpecialFixes.push("y3-auto-test-self-reference");
    }
  }

  if (plan.targetFile.includes(`${path.sep}y3-obj-gen${path.sep}`) && path.basename(plan.targetFile) === "SKILL.md") {
    const updated = content.replace(
      "MCP 返回的数据会保存到临时文件 `.claude/cmtmp/` 目录下。由于数据量很大（56000+），需要使用脚本搜索：",
      "MCP 返回的数据应保存到一次性临时文件中，不要在 `.claude/` 下保留临时目录。由于数据量很大（56000+），需要使用脚本搜索："
    );
    if (updated !== content) {
      content = updated;
      flags.appliedSpecialFixes.push("y3-obj-gen-cmtmp-note");
    }
  }

  const skillRoot = path.join(workspace, ".claude", "skills");
  const relativeToSkillRoot = path.relative(skillRoot, plan.targetFile);
  if (
    !relativeToSkillRoot.startsWith("..") &&
    !path.isAbsolute(relativeToSkillRoot) &&
    path.basename(plan.targetFile) === "SKILL.md"
  ) {
    const [skillName, fileName, ...rest] = normalizeSlashes(relativeToSkillRoot).split("/");
    if (skillName && fileName === "SKILL.md" && rest.length === 0) {
      const normalized = normalizeSkillFrontmatterText(skillName, content);
      if (normalized !== content) {
        content = normalized;
        flags.normalizedSkillFrontmatter = true;
      }
    }
  }

  return {
    buffer: Buffer.from(content.replace(/\r\n/g, "\n"), "utf8"),
    flags,
  };
}

function materializePlan(plan, workspace) {
  if (plan.kind === "mcp-config") {
    const rawBuffer = fs.readFileSync(plan.sourceFile);
    const claudeMcp = buildClaudeMcpFromLegacy(plan.sourceFile, plan.targetFile);
    return {
      sourceHash: hashBuffer(rawBuffer),
      renderedHash: hashBuffer(Buffer.from(claudeMcp.content, "utf8")),
      buffer: Buffer.from(claudeMcp.content, "utf8"),
      flags: {
        rewrittenLegacyPaths: false,
        normalizedSkillFrontmatter: false,
        appliedSpecialFixes: [],
      },
      metadata: {
        mcp: {
          converted: true,
          scope: plan.targetScope || "project",
          target: plan.targetRelative,
          servers: claudeMcp.servers,
          skipped: claudeMcp.skipped,
          empty: claudeMcp.empty,
          warnings: claudeMcp.warnings,
        },
      },
    };
  }

  const rawBuffer = fs.readFileSync(plan.sourceFile);
  const sourceHash = hashBuffer(rawBuffer);
  if (!TEXT_SUFFIXES.has(path.extname(plan.sourceFile).toLowerCase())) {
    return {
      sourceHash,
      renderedHash: sourceHash,
      buffer: rawBuffer,
      flags: {
        rewrittenLegacyPaths: false,
        normalizedSkillFrontmatter: false,
        appliedSpecialFixes: [],
      },
      metadata: {},
    };
  }

  const materialized = materializeTextPlan(plan, workspace);
  return {
    sourceHash,
    renderedHash: hashBuffer(materialized.buffer),
    buffer: materialized.buffer,
    flags: materialized.flags,
    metadata: {},
  };
}

function decidePlanAction(previous, renderedHash, currentTargetHash) {
  if (currentTargetHash === renderedHash) {
    if (!previous) {
      return { action: "adopt" };
    }
    if (previous.status === "blocked") {
      return { action: "resolved" };
    }
    if (previous.status === "managed" && previous.renderedHash === renderedHash) {
      return { action: "unchanged" };
    }
    return { action: "adopt" };
  }

  if (!previous) {
    if (currentTargetHash === null) {
      return { action: "create" };
    }
    return {
      action: "blocked",
      reason: "target already exists but no previous migration baseline was recorded",
    };
  }

  if (previous.status === "blocked") {
    return {
      action: "blocked",
      reason: previous.blockedReason || "previous merge conflict has not been resolved",
    };
  }

  const sourceChanged = previous.renderedHash !== renderedHash;
  const targetChanged = previous.targetHash !== currentTargetHash;

  if (sourceChanged && !targetChanged) {
    return { action: "update" };
  }
  if (!sourceChanged && targetChanged) {
    return {
      action: "blocked",
      reason: "target changed locally after the last migration",
    };
  }
  if (sourceChanged && targetChanged) {
    return {
      action: "blocked",
      reason: "source and target both changed since the last migration",
    };
  }
  return { action: "unchanged" };
}

function managedManifestRecord(plan, materialized, targetHash) {
  return {
    status: "managed",
    kind: plan.kind,
    source: plan.sourceRelative,
    target: plan.targetRelative,
    targetScope: plan.targetScope || "project",
    sourceHash: materialized.sourceHash,
    renderedHash: materialized.renderedHash,
    targetHash,
    updatedAt: new Date().toISOString(),
  };
}

function blockedManifestRecord(plan, materialized, targetHash, reason) {
  return {
    status: "blocked",
    kind: plan.kind,
    source: plan.sourceRelative,
    target: plan.targetRelative,
    targetScope: plan.targetScope || "project",
    sourceHash: materialized.sourceHash,
    renderedHash: materialized.renderedHash,
    targetHash,
    blockedReason: reason,
    updatedAt: new Date().toISOString(),
  };
}

function resolveManifestTargetFile(workspace, targetRelative, previous = {}) {
  const targetScope = previous.targetScope || (targetRelative.startsWith("~/") ? "user" : "project");
  if (targetScope === "user") {
    const withoutHomePrefix = targetRelative.replace(/^~[\\/]/, "");
    return path.join(os.homedir(), withoutHomePrefix.replaceAll("/", path.sep));
  }
  return path.join(workspace, targetRelative.replaceAll("/", path.sep));
}

function orphanedManifestRecord(previous, targetHash) {
  return {
    ...previous,
    status: "orphaned",
    targetHash,
    blockedReason: "source file was removed from .y3maker; target was left in place",
    updatedAt: new Date().toISOString(),
  };
}

function ensureProjectDefaults(workspace, dryRun) {
  const created = [];
  for (const relativeDir of DEFAULT_OPENSPEC_DIRS) {
    const target = path.join(workspace, relativeDir);
    if (!fs.existsSync(target)) {
      ensureDir(target, dryRun);
      created.push(normalizeSlashes(relativeDir));
    }
  }
  return created;
}

function removeExtraneousClaudeTempDirs(workspace, dryRun) {
  const removed = [];
  const claudeRoot = path.join(workspace, ".claude");
  for (const name of EXTRA_CLAUDE_TEMP_DIRS) {
    const target = path.join(claudeRoot, name);
    if (!fs.existsSync(target)) {
      continue;
    }
    removed.push(normalizeSlashes(path.relative(workspace, target)));
    if (!dryRun) {
      fs.rmSync(target, { recursive: true, force: true });
    }
  }
  return removed;
}

function applyMigration(workspace, dryRunOrOptions) {
  const options = normalizeApplyOptions(dryRunOrOptions);
  const { paths, filePlans, copied, mcpSelection } = buildMigrationPlan(workspace, options);
  const dryRun = options.dryRun;
  if (!fs.existsSync(paths.legacy)) {
    throw new Error(`Missing legacy source: ${paths.legacy}`);
  }

  const manifest = loadManifest(workspace);
  const previousFiles = manifest.files || {};
  const nextFiles = {};
  const seenTargets = new Set();

  const createdDirs = [];
  for (const name of CLAUDE_DIR_NAMES) {
    const target = path.join(paths.claude, name);
    if (!fs.existsSync(target)) {
      createdDirs.push(normalizeSlashes(path.relative(workspace, target)));
    }
    ensureDir(target, dryRun);
  }

  const sync = {
    created: [],
    updated: [],
    adopted: [],
    resolved: [],
    blocked: [],
    orphaned: [],
    unchangedCount: 0,
  };
  const rewrittenFiles = [];
  const normalizedSkills = [];
  let mcp = {
    converted: false,
    scope: mcpSelection.scope,
    target: mcpSelection.targetRelative,
    servers: mcpSelection.servers,
    skipped: mcpSelection.skipped,
    empty: mcpSelection.empty,
    warnings: mcpSelection.empty ? [".y3maker/mcp_settings.json has an empty mcpServers object"] : [],
  };
  if (mcpSelection.hasLegacyMcp && mcpSelection.scope === "skip") {
    mcp.skipped.push("mcp_settings.json");
  }
  if (mcpSelection.hasLegacyMcp && mcpSelection.scope !== "skip" && mcpSelection.empty) {
    mcp.skipped.push("mcp_settings.json: empty mcpServers");
  }

  for (const plan of filePlans) {
    seenTargets.add(plan.targetRelative);
    const materialized = materializePlan(plan, workspace);
    const currentTargetHash = hashExistingFile(plan.targetFile);
    const previous = previousFiles[plan.targetRelative] || null;
    const decision = decidePlanAction(previous, materialized.renderedHash, currentTargetHash);

    if (materialized.flags.rewrittenLegacyPaths || materialized.flags.appliedSpecialFixes.length > 0) {
      rewrittenFiles.push(plan.targetRelative);
    }
    if (materialized.flags.normalizedSkillFrontmatter) {
      normalizedSkills.push(plan.targetRelative);
    }
    if (materialized.metadata.mcp) {
      mcp = materialized.metadata.mcp;
    }

    if (decision.action === "create" || decision.action === "update") {
      writeBuffer(plan.targetFile, materialized.buffer, dryRun);
      nextFiles[plan.targetRelative] = managedManifestRecord(plan, materialized, materialized.renderedHash);
      if (decision.action === "create") {
        sync.created.push(plan.targetRelative);
      } else {
        sync.updated.push(plan.targetRelative);
      }
      continue;
    }

    if (decision.action === "adopt" || decision.action === "resolved") {
      nextFiles[plan.targetRelative] = managedManifestRecord(plan, materialized, materialized.renderedHash);
      if (decision.action === "adopt") {
        sync.adopted.push(plan.targetRelative);
      } else {
        sync.resolved.push(plan.targetRelative);
      }
      continue;
    }

    if (decision.action === "blocked") {
      nextFiles[plan.targetRelative] = blockedManifestRecord(plan, materialized, currentTargetHash, decision.reason);
      sync.blocked.push({ path: plan.targetRelative, reason: decision.reason });
      continue;
    }

    nextFiles[plan.targetRelative] = managedManifestRecord(plan, materialized, currentTargetHash);
    sync.unchangedCount += 1;
  }

  for (const [targetRelative, previous] of Object.entries(previousFiles)) {
    if (seenTargets.has(targetRelative)) {
      continue;
    }
    const targetFile = resolveManifestTargetFile(workspace, targetRelative, previous);
    const currentTargetHash = hashExistingFile(targetFile);
    if (currentTargetHash === null) {
      continue;
    }
    nextFiles[targetRelative] = orphanedManifestRecord(previous, currentTargetHash);
    sync.orphaned.push({
      path: targetRelative,
      reason: "source file was removed from .y3maker; target was left in place",
    });
  }

  const nextManifest = {
    version: MANIFEST_VERSION,
    tool: "sync-y3maker-to-claude",
    updatedAt: new Date().toISOString(),
    files: nextFiles,
    mcp,
  };
  writeManifest(workspace, nextManifest, dryRun);

  return {
    dryRun,
    workspace,
    createdDirs,
    copied,
    sync,
    rewrittenFiles: [...new Set(rewrittenFiles)].sort(),
    normalizedSkills: [...new Set(normalizedSkills)].sort(),
    mcp,
    manifest: {
      path: MANIFEST_RELATIVE_PATH,
      trackedFiles: Object.keys(nextFiles).length,
      blockedFiles: sync.blocked.length,
      orphanedTargets: sync.orphaned.length,
    },
    projectDefaults: ensureProjectDefaults(workspace, dryRun),
    removedTempDirs: removeExtraneousClaudeTempDirs(workspace, dryRun),
  };
}

module.exports = {
  COPY_TREE_NAMES,
  MANIFEST_RELATIVE_PATH,
  TEXT_SUFFIXES,
  applyMigration,
  assertSafeWorkspace,
  extractCandidatePaths,
  extractFrontmatter,
  getUnsafeWorkspaceReason,
  inventoryWorkspace,
  loadFrontmatterKeys,
  readText,
};
