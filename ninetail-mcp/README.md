# ninetail-mcp

The 9 Tails of the Kitsune social suite, as a local [MCP](https://modelcontextprotocol.io) server. It runs over stdio, so any MCP client (Claude Code, Claude Desktop, Cursor and others) can publish to YouTube, TikTok, Instagram and X, pin first comments and pull analytics.

> **Simulation mode.** Every tool currently returns mock data. Nothing is posted, and no platform APIs are called.

## Install and build

```bash
npm install
npm run build        # tsc, then chmod +x dist/index.js
```

Run from source without building:

```bash
npm start            # tsx src/index.ts
```

## Connect it to a client

Claude Code:

```bash
claude mcp add ninetail -- node /absolute/path/to/ninetail-mcp/dist/index.js
```

Claude Desktop (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "ninetail": {
      "command": "node",
      "args": ["/absolute/path/to/ninetail-mcp/dist/index.js"]
    }
  }
}
```

Once the package is published to npm, `npx -y ninetail-mcp` replaces `node …/dist/index.js`.

## Tools

| Tool | Parameters | Uses a trial run |
| --- | --- | --- |
| `ninetail_publish` | `title`, `caption`, `mediaPath`, `platforms` (`youtube`, `tiktok`, `instagram`, `x`), `tags?` | Yes |
| `ninetail_pin_comment` | `videoId`, `commentText` | Yes |
| `ninetail_get_analytics` | `days` (default 7, 1 to 365) | Yes |
| `ninetail_status` | none | No |
| `ninetail_activate` | `licenseKey` | No |

## Trial and license

State lives in `~/.ninetail/config.json`:

```json
{ "licenseKey": null, "runsUsed": 0 }
```

- The first 10 metered tool calls are free. After that, metered tools return the trial-expired message until a license is activated.
- `ninetail_activate` accepts any key that starts with `NT-` or is at least 8 characters long. This is a placeholder: keys are not yet checked against Gumroad.
- Calls rejected for invalid input never use a run.

## Logging

stdout carries JSON-RPC only. All logs go to stderr.
