# ClaudePantheon MCP Servers for Cloud Storage

This directory contains Model Context Protocol (MCP) servers that provide rich API integration for cloud storage services.

## Available MCP Servers

### 1. Google Drive MCP Server

**Features:**
- File search with advanced queries
- Shared drives (Team Drives) support
- Permissions management
- File operations (create, read, update, delete)
- Metadata operations

**Setup:**

Option A: Service Account (Recommended for servers)

```bash
# 1. Create Google Cloud project at https://console.cloud.google.com
# 2. Enable Google Drive API
# 3. Create service account and download JSON key
# 4. Save credentials
cp service-account-key.json /app/data/mcp/google-drive-credentials.json
chmod 600 /app/data/mcp/google-drive-credentials.json

# 5. Add to mcp.json
```

Option B: OAuth Token

```bash
# 1. On a machine with browser, install rclone
curl https://rclone.org/install.sh | sudo bash

# 2. Authorize
rclone authorize "drive"

# 3. Save token
echo '{...token json...}' > /app/data/mcp/google-drive-token.json
chmod 600 /app/data/mcp/google-drive-token.json
```

**mcp.json configuration:**

```json
{
  "mcpServers": {
    "google-drive": {
      "command": "node",
      "args": ["/app/data/mcp-servers/google-drive-mcp.js"],
      "env": {
        "GOOGLE_DRIVE_CREDENTIALS_PATH": "/app/data/mcp/google-drive-credentials.json"
      }
    }
  }
}
```

**Usage Examples:**

```javascript
// Search for PDFs
search_files({ query: "mimeType = 'application/pdf'" })

// Get file metadata
get_file_metadata({ file_id: "1a2b3c4d5e6f" })

// List shared drives
list_shared_drives()

// Create a file
create_file({
  name: "notes.txt",
  content: "My notes",
  mime_type: "text/plain"
})
```

---

### 2. Dropbox MCP Server

**Features:**
- File search
- File operations (upload, download, delete, move)
- Sharing and link generation
- Folder operations
- Metadata access

**Setup:**

```bash
# 1. Create Dropbox app at https://www.dropbox.com/developers/apps
# 2. Choose "Scoped access"
# 3. Select "Full Dropbox" or "App folder"
# 4. Generate access token
# 5. Save token to environment or secrets
```

**mcp.json configuration:**

```json
{
  "mcpServers": {
    "dropbox": {
      "command": "node",
      "args": ["/app/data/mcp-servers/dropbox-mcp.js"],
      "env": {
        "DROPBOX_ACCESS_TOKEN": "your_dropbox_access_token"
      }
    }
  }
}
```

Or use Docker secrets (recommended):

```json
{
  "mcpServers": {
    "dropbox": {
      "command": "sh",
      "args": [
        "-c",
        "DROPBOX_ACCESS_TOKEN=$(cat /run/secrets/dropbox_token) node /app/data/mcp-servers/dropbox-mcp.js"
      ]
    }
  }
}
```

**Usage Examples:**

```javascript
// Search files
search_files({ query: "vacation photos" })

// List folder
list_folder({ path: "/Photos", recursive: false })

// Upload file
upload_file({
  path: "/notes.txt",
  content: "My notes",
  mode: "overwrite"
})

// Get shared link
get_shared_link({ path: "/report.pdf" })

// Move file
move_file({
  from_path: "/old/file.txt",
  to_path: "/new/file.txt"
})
```

---

## Installation

### Step 1: Install Dependencies

```bash
cd /app/data/mcp-servers
npm install
```

### Step 2: Configure Credentials

**For Google Drive:**

Place credentials at one of:
- `/app/data/mcp/google-drive-credentials.json` (service account)
- `/app/data/mcp/google-drive-token.json` (OAuth token)

**For Dropbox:**

Set environment variable or Docker secret:
- `DROPBOX_ACCESS_TOKEN` environment variable
- `/run/secrets/dropbox_token` Docker secret

### Step 3: Update mcp.json

Add servers to `/app/data/mcp/mcp.json`:

```json
{
  "mcpServers": {
    "google-drive": {
      "command": "node",
      "args": ["/app/data/mcp-servers/google-drive-mcp.js"],
      "env": {
        "GOOGLE_DRIVE_CREDENTIALS_PATH": "/app/data/mcp/google-drive-credentials.json"
      }
    },
    "dropbox": {
      "command": "node",
      "args": ["/app/data/mcp-servers/dropbox-mcp.js"],
      "env": {
        "DROPBOX_ACCESS_TOKEN": "your_token_here"
      }
    }
  }
}
```

### Step 4: Test

```bash
# Test Google Drive
node google-drive-mcp.js

# Test Dropbox
DROPBOX_ACCESS_TOKEN="your_token" node dropbox-mcp.js
```

### Step 5: Restart Claude Code

```bash
# In container
exit
cc-new
```

---

## Security Best Practices

1. **Use Docker Secrets for Production**

```bash
# Create secrets
mkdir -p /app/data/secrets
echo "your_dropbox_token" > /app/data/secrets/dropbox_token
chmod 600 /app/data/secrets/dropbox_token

# Reference in mcp.json
{
  "mcpServers": {
    "dropbox": {
      "command": "sh",
      "args": [
        "-c",
        "DROPBOX_ACCESS_TOKEN=$(cat /run/secrets/dropbox_token) node /app/data/mcp-servers/dropbox-mcp.js"
      ]
    }
  }
}
```

2. **Restrict Service Account Permissions**

For Google Drive service accounts:
- Grant minimum required permissions
- Use domain-wide delegation carefully
- Regularly audit access logs

3. **Rotate Tokens Regularly**

- Dropbox tokens don't expire but should be rotated quarterly
- Google OAuth tokens expire and auto-refresh
- Service account keys should be rotated annually

4. **Monitor Usage**

```bash
# Check MCP server logs
claude mcp

# View Claude logs
tail -f /app/data/logs/claudepantheon.log
```

---

## Troubleshooting

### Google Drive MCP

**Error: "No credentials found"**

```bash
# Check file exists and is readable
ls -la /app/data/mcp/google-drive-*.json

# Verify JSON is valid
jq . /app/data/mcp/google-drive-credentials.json
```

**Error: "Permission denied"**

- Service account needs access to files/folders
- Share files with service account email
- Or use OAuth token instead

**Error: "API not enabled"**

1. Go to Google Cloud Console
2. Enable Google Drive API
3. Wait 5 minutes for propagation

### Dropbox MCP

**Error: "Invalid access token"**

```bash
# Test token manually
curl -X POST https://api.dropboxapi.com/2/users/get_current_account \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Error: "Path not found"**

- Dropbox paths are case-sensitive
- Use `/folder/file.txt` not `folder/file.txt`
- Check path exists: `list_folder({ path: "/" })`

### General MCP Issues

**MCP server not appearing in Claude Code:**

```bash
# Restart Claude Code
exit
cc-new

# Check MCP status
claude mcp

# Verify mcp.json syntax
jq . /app/data/mcp/mcp.json
```

**"Command not found" error:**

```bash
# Ensure Node.js is available
node --version

# Install if missing (add to custom-packages.txt)
apk add nodejs npm
```

---

## Examples

### Sync Local File to Google Drive

```javascript
// Read local file
const content = await readFile('/app/data/workspace/report.md', 'utf8');

// Upload to Google Drive
await create_file({
  name: 'report.md',
  content,
  mime_type: 'text/markdown'
});
```

### Batch Download from Dropbox

```javascript
// List all PDFs in folder
const results = await search_files({
  query: "*.pdf",
  path: "/Documents"
});

// Download each
for (const file of results.matches) {
  const content = await download_file({ path: file.path });
  await writeFile(`/app/data/workspace/${file.name}`, content);
}
```

### Cross-Platform Sync

```javascript
// Download from Dropbox
const dropboxFile = await dropbox_download({ path: "/notes.txt" });

// Upload to Google Drive
await googledrive_create({
  name: "notes.txt",
  content: dropboxFile.content
});
```

---

## Performance Considerations

**Google Drive:**
- Rate limit: 1,000 requests per 100 seconds per user
- Quota: 1 billion queries per day
- Use batch operations where possible

**Dropbox:**
- Rate limit: 200 requests per 15 minutes per app
- Large file downloads may be slow
- Use `recursive: false` for faster folder listings

**Best Practices:**
- Cache metadata locally
- Use webhooks for real-time sync (requires separate setup)
- Batch operations when possible
- Handle rate limits with exponential backoff

---

## Advanced Configuration

### Custom Scopes (Google Drive)

Edit service account or OAuth scopes:

```javascript
// In google-drive-mcp.js
scopes: [
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/drive.metadata.readonly'
]
```

### Dropbox App Folder Mode

```json
{
  "mcpServers": {
    "dropbox-app": {
      "command": "node",
      "args": ["/app/data/mcp-servers/dropbox-mcp.js"],
      "env": {
        "DROPBOX_ACCESS_TOKEN": "app_folder_token"
      }
    }
  }
}
```

Files will be in `/Apps/[YourAppName]/` only.

---

## Contributing

To add new cloud storage MCP servers:

1. Create `<service>-mcp.js` file
2. Implement MCP Server interface
3. Add to `package.json` dependencies
4. Update this README
5. Add tests

---

**Last Updated:** 2026-01-31
**Version:** 1.0.0
