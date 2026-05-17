/**
 * MCP SSE ↔ StreamableHTTP Bridge
 *
 * Claude Code only supports SSE and stdio MCP transports.
 * Y3 MCP servers (y3editor, y3-helper, y3runtime) use streamableHttp.
 * This bridge translates between the two protocols.
 *
 * Usage: node scripts/mcp-bridge-server.js
 *
 * Creates bridge servers:
 *   y3editor   :8765 → localhost:18765/sse
 *   y3-helper  :8766 → localhost:18766/sse
 *   y3runtime  :8767 → localhost:18767/sse
 */

const http = require('http');

const BRIDGES = [
  { name: 'y3editor',  backendPort: 8765, bridgePort: 18765 },
  { name: 'y3-helper', backendPort: 8766, bridgePort: 18766 },
  { name: 'y3runtime', backendPort: 8767, bridgePort: 18767 },
];

const BACKEND_HOST = '127.0.0.1';

// ── Session Management ──────────────────────────────────────────

const sessions = new Map();
let sessionCounter = 0;

// ── Bridge Server Factory ────────────────────────────────────────

function createBridge({ name, backendPort, bridgePort }) {
  // Override session backendPort on creation via closure
  const server = http.createServer((req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, MCP-*');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url, `http://${req.headers.host}`);

    if (url.pathname === '/sse') {
      handleSSE(req, res, name, backendPort);
    } else if (req.method === 'POST' && url.pathname === '/message') {
      handleMessage(req, res);
    } else {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found. Use /sse or POST /message?session=<id>');
    }
  });

  server.listen(bridgePort, () => {
    const status = 'listening';
    console.log(`[${name}] :${bridgePort}/sse → :${backendPort}/mcp [${status}]`);
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.error(`[${name}] Port ${bridgePort} already in use. Skip.`);
    } else {
      console.error(`[${name}] ${err.message}`);
    }
  });
}

// ── SSE Handler ──────────────────────────────────────────────────

function handleSSE(req, res, bridgeName, backendPort) {
  const sessionId = `${bridgeName}-${++sessionCounter}`;
  const session = { id: sessionId, res, backendPort, backendSessionId: null, closed: false };
  sessions.set(sessionId, session);

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
  });
  res.flushHeaders();

  // Tell Claude Code where to POST JSON-RPC messages
  res.write(`event: endpoint\ndata: /message?session=${sessionId}\n\n`);

  // Heartbeat to keep connection alive (some proxies drop idle connections)
  const heartbeat = setInterval(() => {
    if (!session.closed) {
      try { res.write(': hb\n\n'); } catch { clearInterval(heartbeat); }
    } else {
      clearInterval(heartbeat);
    }
  }, 15000);

  req.on('close', () => {
    session.closed = true;
    clearInterval(heartbeat);
    sessions.delete(sessionId);
  });
}

// ── Message Handler ──────────────────────────────────────────────

function handleMessage(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const sessionId = url.searchParams.get('session');
  const session = sessions.get(sessionId);

  if (!session) {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Session not found or expired. Reconnect to /sse first.' }));
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    forwardToBackend(body, session)
      .then(responseBody => {
        // streamableHttp may return multiple JSON objects separated by newlines
        const lines = responseBody.trim().split('\n');
        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed) {
            try {
              JSON.parse(trimmed); // validate
              session.res.write(`event: message\ndata: ${trimmed}\n\n`);
            } catch {
              // skip non-JSON lines
            }
          }
        }
        res.writeHead(202, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true }));
      })
      .catch(err => {
        const errResp = JSON.stringify({
          jsonrpc: '2.0', id: null,
          error: { code: -32000, message: `Bridge: ${err.message}` },
        });
        if (!session.closed) {
          session.res.write(`event: message\ndata: ${errResp}\n\n`);
        }
        res.writeHead(502, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      });
  });
}

// ── Backend Proxy (StreamableHTTP) ───────────────────────────────

function forwardToBackend(body, session) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: BACKEND_HOST,
      port: session.backendPort,
      path: '/mcp',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    if (session.backendSessionId) {
      options.headers['Mcp-Session-Id'] = session.backendSessionId;
    }

    const req = http.request(options, (res) => {
      const mcpSessionId = res.headers['mcp-session-id'];
      if (mcpSessionId) {
        session.backendSessionId = Array.isArray(mcpSessionId) ? mcpSessionId[0] : mcpSessionId;
      }

      let data = '';
      res.on('data', chunk => data += chunk.toString());
      res.on('end', () => resolve(data));
    });

    req.on('error', (err) => {
      if (err.code === 'ECONNREFUSED') {
        reject(new Error(`Backend :${session.backendPort} not available`));
      } else {
        reject(err);
      }
    });

    req.write(body);
    req.end();
  });
}

// ── Startup ──────────────────────────────────────────────────────

console.log('MCP SSE ↔ StreamableHTTP Bridge');
console.log('────────────────────────────────────────');

let started = false;
for (const config of BRIDGES) {
  createBridge(config);
}

process.on('uncaughtException', (err) => {
  if (err.code !== 'EADDRINUSE' && err.code !== 'ECONNREFUSED') {
    console.error('Uncaught:', err);
  }
});

console.log('────────────────────────────────────────');
console.log('.mcp.json should point to bridge ports 18765-18767 with type: "sse".');
