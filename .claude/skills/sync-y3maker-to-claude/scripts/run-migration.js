#!/usr/bin/env node

const fs = require("fs");
const os = require("os");
const path = require("path");
const readline = require("readline");

const { applyMigration, assertSafeWorkspace, inventoryWorkspace } = require("./migration-lib");

function emitJson(payload, pretty) {
  const text = JSON.stringify(payload, null, pretty ? 2 : 0);
  process.stdout.write(`${text}\n`);
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const options = {
    workspace: ".",
    dryRun: false,
    pretty: false,
    allowUnsafeWorkspace: false,
    mcpScope: null,
  };
  for (let index = 0; index < rest.length; index += 1) {
    const token = rest[index];
    if (token === "--workspace") {
      index += 1;
      options.workspace = rest[index];
    } else if (token === "--dry-run") {
      options.dryRun = true;
    } else if (token === "--pretty") {
      options.pretty = true;
    } else if (token === "--allow-unsafe-workspace") {
      options.allowUnsafeWorkspace = true;
    } else if (token === "--mcp-scope") {
      index += 1;
      options.mcpScope = rest[index];
    } else {
      throw new Error(`Unknown argument: ${token}`);
    }
  }
  if (options.mcpScope && !["project", "user", "skip"].includes(options.mcpScope)) {
    throw new Error(`Invalid --mcp-scope: ${options.mcpScope}. Expected project, user, or skip.`);
  }
  if (!command || !["inventory", "apply"].includes(command)) {
    throw new Error(
      "Usage: node run-migration.js <inventory|apply> [--workspace .] [--dry-run] [--pretty] [--allow-unsafe-workspace] [--mcp-scope project|user|skip]"
    );
  }
  return { command, options };
}

function question(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stderr,
  });
  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function resolveMcpScope(workspace, options) {
  if (options.mcpScope || !fs.existsSync(path.join(workspace, ".y3maker", "mcp_settings.json"))) {
    return options.mcpScope;
  }

  if (!process.stdin.isTTY) {
    throw new Error(
      "Legacy MCP settings exist; refusing to modify MCP config silently. Re-run with --mcp-scope project, --mcp-scope user, or --mcp-scope skip."
    );
  }

  process.stderr.write(
    [
      "Detected .y3maker/mcp_settings.json. Choose where to migrate MCP config:",
      `  1) project - ${path.join(workspace, ".mcp.json")} (recommended for shared Claude Code project MCP)` ,
      `  2) user    - ${path.join(os.homedir(), ".claude.json")} (private user-level Claude Code MCP)`,
      "  3) skip    - do not migrate MCP config in this run",
      "",
    ].join("\n")
  );

  const answer = (await question("MCP target [project/user/skip or 1/2/3]: ")).toLowerCase();
  const aliases = {
    "1": "project",
    p: "project",
    project: "project",
    "2": "user",
    u: "user",
    user: "user",
    "3": "skip",
    s: "skip",
    skip: "skip",
  };
  if (!aliases[answer]) {
    throw new Error("MCP migration target was not selected. Expected project, user, or skip.");
  }
  return aliases[answer];
}

async function main() {
  try {
    const { command, options } = parseArgs(process.argv.slice(2));
    const workspace = path.resolve(options.workspace);
    if (command === "apply") {
      assertSafeWorkspace(workspace, options);
      options.mcpScope = await resolveMcpScope(workspace, options);
    }
    const payload =
      command === "inventory"
        ? inventoryWorkspace(workspace)
        : applyMigration(workspace, { dryRun: options.dryRun, mcpScope: options.mcpScope });
    emitJson(payload, options.pretty);
  } catch (error) {
    process.stderr.write(`ERROR: ${error.message}\n`);
    process.exitCode = 1;
  }
}

main();
