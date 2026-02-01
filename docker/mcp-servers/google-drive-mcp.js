#!/usr/bin/env node
/**
 * ╔═══════════════════════════════════════════════════════════╗
 * ║         Google Drive MCP Server for ClaudePantheon       ║
 * ╚═══════════════════════════════════════════════════════════╝
 *
 * Provides rich Google Drive API integration via Model Context Protocol
 *
 * Features:
 * - File search with advanced queries
 * - Shared drives support
 * - Permissions management
 * - Metadata operations
 * - File operations (create, update, delete)
 *
 * Setup:
 * 1. Create Google Cloud project
 * 2. Enable Google Drive API
 * 3. Create OAuth 2.0 credentials or service account
 * 4. Set GOOGLE_DRIVE_CREDENTIALS_PATH or GOOGLE_DRIVE_TOKEN
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { google } from 'googleapis';
import fs from 'fs/promises';
import path from 'path';

// Configuration
const CREDENTIALS_PATH = process.env.GOOGLE_DRIVE_CREDENTIALS_PATH || '/app/data/mcp/google-drive-credentials.json';
const TOKEN_PATH = process.env.GOOGLE_DRIVE_TOKEN_PATH || '/app/data/mcp/google-drive-token.json';

class GoogleDriveMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'google-drive-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.drive = null;
    this.setupToolHandlers();

    // Error handlers
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  async initialize() {
    try {
      // Try to load service account credentials first
      try {
        const credentials = JSON.parse(await fs.readFile(CREDENTIALS_PATH, 'utf8'));
        const auth = new google.auth.GoogleAuth({
          credentials,
          scopes: ['https://www.googleapis.com/auth/drive'],
        });
        this.drive = google.drive({ version: 'v3', auth });
        console.error('[Google Drive MCP] Initialized with service account');
        return;
      } catch (err) {
        // Service account not available, try OAuth token
      }

      // Try OAuth token
      try {
        const token = JSON.parse(await fs.readFile(TOKEN_PATH, 'utf8'));
        const oauth2Client = new google.auth.OAuth2();
        oauth2Client.setCredentials(token);
        this.drive = google.drive({ version: 'v3', auth: oauth2Client });
        console.error('[Google Drive MCP] Initialized with OAuth token');
        return;
      } catch (err) {
        // No auth available
      }

      throw new Error('No Google Drive credentials found. Set GOOGLE_DRIVE_CREDENTIALS_PATH or GOOGLE_DRIVE_TOKEN_PATH');
    } catch (error) {
      console.error('[Google Drive MCP] Initialization failed:', error.message);
      throw error;
    }
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'search_files',
          description: 'Search for files in Google Drive using advanced queries',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Search query (e.g., "name contains \'report\' and mimeType = \'application/pdf\'")',
              },
              max_results: {
                type: 'number',
                description: 'Maximum number of results (default: 10)',
                default: 10,
              },
              include_shared_drives: {
                type: 'boolean',
                description: 'Include shared drive files',
                default: false,
              },
            },
            required: ['query'],
          },
        },
        {
          name: 'get_file_metadata',
          description: 'Get detailed metadata for a file',
          inputSchema: {
            type: 'object',
            properties: {
              file_id: {
                type: 'string',
                description: 'Google Drive file ID',
              },
            },
            required: ['file_id'],
          },
        },
        {
          name: 'list_shared_drives',
          description: 'List all shared drives (team drives) accessible to the user',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'get_file_permissions',
          description: 'Get sharing permissions for a file',
          inputSchema: {
            type: 'object',
            properties: {
              file_id: {
                type: 'string',
                description: 'Google Drive file ID',
              },
            },
            required: ['file_id'],
          },
        },
        {
          name: 'create_file',
          description: 'Create a new file in Google Drive',
          inputSchema: {
            type: 'object',
            properties: {
              name: {
                type: 'string',
                description: 'File name',
              },
              content: {
                type: 'string',
                description: 'File content (for text files)',
              },
              mime_type: {
                type: 'string',
                description: 'MIME type (default: text/plain)',
                default: 'text/plain',
              },
              parent_id: {
                type: 'string',
                description: 'Parent folder ID (optional)',
              },
            },
            required: ['name', 'content'],
          },
        },
        {
          name: 'update_file_content',
          description: 'Update the content of an existing file',
          inputSchema: {
            type: 'object',
            properties: {
              file_id: {
                type: 'string',
                description: 'File ID to update',
              },
              content: {
                type: 'string',
                description: 'New file content',
              },
            },
            required: ['file_id', 'content'],
          },
        },
        {
          name: 'delete_file',
          description: 'Delete a file (moves to trash)',
          inputSchema: {
            type: 'object',
            properties: {
              file_id: {
                type: 'string',
                description: 'File ID to delete',
              },
            },
            required: ['file_id'],
          },
        },
      ],
    }));

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        const { name, arguments: args } = request.params;

        switch (name) {
          case 'search_files':
            return await this.searchFiles(args);
          case 'get_file_metadata':
            return await this.getFileMetadata(args);
          case 'list_shared_drives':
            return await this.listSharedDrives();
          case 'get_file_permissions':
            return await this.getFilePermissions(args);
          case 'create_file':
            return await this.createFile(args);
          case 'update_file_content':
            return await this.updateFileContent(args);
          case 'delete_file':
            return await this.deleteFile(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async searchFiles(args) {
    const { query, max_results = 10, include_shared_drives = false } = args;

    const response = await this.drive.files.list({
      q: query,
      pageSize: max_results,
      fields: 'files(id, name, mimeType, size, createdTime, modifiedTime, webViewLink, owners, shared)',
      supportsAllDrives: include_shared_drives,
      includeItemsFromAllDrives: include_shared_drives,
    });

    const files = response.data.files || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            found: files.length,
            files: files.map(f => ({
              id: f.id,
              name: f.name,
              mimeType: f.mimeType,
              size: f.size,
              created: f.createdTime,
              modified: f.modifiedTime,
              link: f.webViewLink,
              owners: f.owners?.map(o => o.emailAddress),
              shared: f.shared,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async getFileMetadata(args) {
    const { file_id } = args;

    const response = await this.drive.files.get({
      fileId: file_id,
      fields: '*',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(response.data, null, 2),
        },
      ],
    };
  }

  async listSharedDrives() {
    const response = await this.drive.drives.list({
      pageSize: 100,
    });

    const drives = response.data.drives || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            found: drives.length,
            drives: drives.map(d => ({
              id: d.id,
              name: d.name,
              createdTime: d.createdTime,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async getFilePermissions(args) {
    const { file_id } = args;

    const response = await this.drive.permissions.list({
      fileId: file_id,
      fields: 'permissions(id, type, role, emailAddress, displayName)',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            file_id,
            permissions: response.data.permissions || [],
          }, null, 2),
        },
      ],
    };
  }

  async createFile(args) {
    const { name, content, mime_type = 'text/plain', parent_id } = args;

    const fileMetadata = {
      name,
      mimeType: mime_type,
    };

    if (parent_id) {
      fileMetadata.parents = [parent_id];
    }

    const media = {
      mimeType: mime_type,
      body: content,
    };

    const response = await this.drive.files.create({
      resource: fileMetadata,
      media,
      fields: 'id, name, webViewLink',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            created: true,
            file: response.data,
          }, null, 2),
        },
      ],
    };
  }

  async updateFileContent(args) {
    const { file_id, content } = args;

    const media = {
      body: content,
    };

    const response = await this.drive.files.update({
      fileId: file_id,
      media,
      fields: 'id, name, modifiedTime',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            updated: true,
            file: response.data,
          }, null, 2),
        },
      ],
    };
  }

  async deleteFile(args) {
    const { file_id } = args;

    await this.drive.files.delete({
      fileId: file_id,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            deleted: true,
            file_id,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    await this.initialize();
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Google Drive MCP] Server running on stdio');
  }
}

// Start server
const server = new GoogleDriveMCPServer();
server.run().catch(console.error);
