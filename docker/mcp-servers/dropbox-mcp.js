#!/usr/bin/env node
/**
 * ╔═══════════════════════════════════════════════════════════╗
 * ║           Dropbox MCP Server for ClaudePantheon          ║
 * ╚═══════════════════════════════════════════════════════════╝
 *
 * Provides Dropbox API integration via Model Context Protocol
 *
 * Features:
 * - File search
 * - File operations (upload, download, delete)
 * - Sharing and permissions
 * - Folder operations
 * - Metadata access
 *
 * Setup:
 * 1. Create Dropbox app at https://www.dropbox.com/developers/apps
 * 2. Generate access token
 * 3. Set DROPBOX_ACCESS_TOKEN environment variable
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { Dropbox } from 'dropbox';

// Configuration
const ACCESS_TOKEN = process.env.DROPBOX_ACCESS_TOKEN;

class DropboxMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'dropbox-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.dbx = null;
    this.setupToolHandlers();

    // Error handlers
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  async initialize() {
    if (!ACCESS_TOKEN) {
      throw new Error('DROPBOX_ACCESS_TOKEN environment variable is required');
    }

    this.dbx = new Dropbox({ accessToken: ACCESS_TOKEN });
    console.error('[Dropbox MCP] Initialized with access token');

    // Test connection
    try {
      await this.dbx.usersGetCurrentAccount();
      console.error('[Dropbox MCP] Connected successfully');
    } catch (error) {
      console.error('[Dropbox MCP] Connection test failed:', error.message);
      throw error;
    }
  }

  setupToolHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'search_files',
          description: 'Search for files in Dropbox',
          inputSchema: {
            type: 'object',
            properties: {
              query: {
                type: 'string',
                description: 'Search query',
              },
              max_results: {
                type: 'number',
                description: 'Maximum number of results (default: 20)',
                default: 20,
              },
              path: {
                type: 'string',
                description: 'Limit search to specific folder path',
              },
            },
            required: ['query'],
          },
        },
        {
          name: 'list_folder',
          description: 'List contents of a folder',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'Folder path (empty string for root)',
                default: '',
              },
              recursive: {
                type: 'boolean',
                description: 'List recursively',
                default: false,
              },
            },
          },
        },
        {
          name: 'get_metadata',
          description: 'Get metadata for a file or folder',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'File or folder path',
              },
            },
            required: ['path'],
          },
        },
        {
          name: 'upload_file',
          description: 'Upload a file to Dropbox',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'Destination path in Dropbox',
              },
              content: {
                type: 'string',
                description: 'File content (text)',
              },
              mode: {
                type: 'string',
                description: 'Upload mode: add, overwrite, or update',
                default: 'add',
                enum: ['add', 'overwrite', 'update'],
              },
            },
            required: ['path', 'content'],
          },
        },
        {
          name: 'download_file',
          description: 'Download file content from Dropbox',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'File path in Dropbox',
              },
            },
            required: ['path'],
          },
        },
        {
          name: 'delete',
          description: 'Delete a file or folder',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'Path to delete',
              },
            },
            required: ['path'],
          },
        },
        {
          name: 'create_folder',
          description: 'Create a new folder',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'Folder path to create',
              },
            },
            required: ['path'],
          },
        },
        {
          name: 'get_shared_link',
          description: 'Get or create a shared link for a file',
          inputSchema: {
            type: 'object',
            properties: {
              path: {
                type: 'string',
                description: 'File or folder path',
              },
            },
            required: ['path'],
          },
        },
        {
          name: 'move_file',
          description: 'Move or rename a file',
          inputSchema: {
            type: 'object',
            properties: {
              from_path: {
                type: 'string',
                description: 'Source path',
              },
              to_path: {
                type: 'string',
                description: 'Destination path',
              },
            },
            required: ['from_path', 'to_path'],
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
          case 'list_folder':
            return await this.listFolder(args);
          case 'get_metadata':
            return await this.getMetadata(args);
          case 'upload_file':
            return await this.uploadFile(args);
          case 'download_file':
            return await this.downloadFile(args);
          case 'delete':
            return await this.delete(args);
          case 'create_folder':
            return await this.createFolder(args);
          case 'get_shared_link':
            return await this.getSharedLink(args);
          case 'move_file':
            return await this.moveFile(args);
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
    const { query, max_results = 20, path } = args;

    const options = {
      query,
      max_results,
    };

    if (path) {
      options.options = {
        path,
        max_results,
      };
    }

    const response = await this.dbx.filesSearchV2(options);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            found: response.result.matches.length,
            has_more: response.result.has_more,
            matches: response.result.matches.map(m => ({
              path: m.metadata.metadata.path_display,
              name: m.metadata.metadata.name,
              type: m.metadata.metadata['.tag'],
              size: m.metadata.metadata.size,
              modified: m.metadata.metadata.server_modified,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async listFolder(args) {
    const { path = '', recursive = false } = args;

    const response = await this.dbx.filesListFolder({
      path,
      recursive,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            path: path || '/',
            entries: response.result.entries.map(e => ({
              path: e.path_display,
              name: e.name,
              type: e['.tag'],
              size: e.size,
              modified: e.server_modified,
            })),
            has_more: response.result.has_more,
          }, null, 2),
        },
      ],
    };
  }

  async getMetadata(args) {
    const { path } = args;

    const response = await this.dbx.filesGetMetadata({ path });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(response.result, null, 2),
        },
      ],
    };
  }

  async uploadFile(args) {
    const { path, content, mode = 'add' } = args;

    const response = await this.dbx.filesUpload({
      path,
      contents: content,
      mode: { '.tag': mode },
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            uploaded: true,
            path: response.result.path_display,
            size: response.result.size,
            id: response.result.id,
          }, null, 2),
        },
      ],
    };
  }

  async downloadFile(args) {
    const { path } = args;

    const response = await this.dbx.filesDownload({ path });
    const content = response.result.fileBinary.toString('utf8');

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            path: response.result.path_display,
            size: response.result.size,
            content,
          }, null, 2),
        },
      ],
    };
  }

  async delete(args) {
    const { path } = args;

    const response = await this.dbx.filesDeleteV2({ path });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            deleted: true,
            metadata: response.result.metadata,
          }, null, 2),
        },
      ],
    };
  }

  async createFolder(args) {
    const { path } = args;

    const response = await this.dbx.filesCreateFolderV2({ path });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            created: true,
            path: response.result.metadata.path_display,
          }, null, 2),
        },
      ],
    };
  }

  async getSharedLink(args) {
    const { path } = args;

    try {
      // Try to get existing links first
      const links = await this.dbx.sharingListSharedLinks({ path });
      if (links.result.links.length > 0) {
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify({
                url: links.result.links[0].url,
                existing: true,
              }, null, 2),
            },
          ],
        };
      }
    } catch (err) {
      // No existing links, create new one
    }

    const response = await this.dbx.sharingCreateSharedLinkWithSettings({
      path,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            url: response.result.url,
            existing: false,
          }, null, 2),
        },
      ],
    };
  }

  async moveFile(args) {
    const { from_path, to_path } = args;

    const response = await this.dbx.filesMoveV2({
      from_path,
      to_path,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            moved: true,
            from: from_path,
            to: response.result.metadata.path_display,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    await this.initialize();
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Dropbox MCP] Server running on stdio');
  }
}

// Start server
const server = new DropboxMCPServer();
server.run().catch(console.error);
