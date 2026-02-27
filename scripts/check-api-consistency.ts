#!/usr/bin/env bun
/**
 * API Consistency Checker
 *
 * Verifies that all frontend API client methods have corresponding backend routes.
 * Run with: bun scripts/check-api-consistency.ts
 */

import { readFileSync, readdirSync } from 'fs';
import { join } from 'path';

// Define expected API endpoints based on frontend client
interface EndpointDef {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  path: string;
  clientMethod: string;
}

// All endpoints defined in the frontend client
const CLIENT_ENDPOINTS: Record<string, EndpointDef[]> = {
  settings: [
    { method: 'GET', path: '/settings', clientMethod: 'getAll' },
    { method: 'PUT', path: '/settings', clientMethod: 'updateAll' },
    { method: 'GET', path: '/settings/retry', clientMethod: 'getRetry' },
    { method: 'PUT', path: '/settings/retry', clientMethod: 'updateRetry' },
    { method: 'GET', path: '/settings/agent', clientMethod: 'getAgent' },
    { method: 'PUT', path: '/settings/agent', clientMethod: 'updateAgent' },
    { method: 'GET', path: '/settings/model', clientMethod: 'getModel' },
    { method: 'PUT', path: '/settings/model', clientMethod: 'updateModel' },
    { method: 'GET', path: '/settings/thinking', clientMethod: 'getThinking' },
    { method: 'PUT', path: '/settings/thinking', clientMethod: 'updateThinking' },
    { method: 'GET', path: '/settings/providers', clientMethod: 'listProviders' },
    { method: 'PUT', path: '/settings/providers/{name}', clientMethod: 'updateProvider' },
  ],
  plugins: [
    { method: 'GET', path: '/plugins', clientMethod: 'list' },
    { method: 'POST', path: '/plugins', clientMethod: 'add' },
    { method: 'GET', path: '/plugins/{id}', clientMethod: 'get' },
    { method: 'DELETE', path: '/plugins/{id}', clientMethod: 'remove' },
    { method: 'PUT', path: '/plugins/{id}/enable', clientMethod: 'enable' },
    { method: 'PUT', path: '/plugins/{id}/disable', clientMethod: 'disable' },
    { method: 'POST', path: '/plugins/{id}/reload', clientMethod: 'reload' },
    { method: 'POST', path: '/plugins/upload', clientMethod: 'upload' },
    { method: 'GET', path: '/plugins/{id}/settings', clientMethod: 'getSettings' },
    { method: 'PUT', path: '/plugins/{id}/settings', clientMethod: 'updateSettings' },
  ],
  prompts: [
    { method: 'GET', path: '/prompts/system', clientMethod: 'getSystem' },
    { method: 'PUT', path: '/prompts/system', clientMethod: 'updateSystem' },
    { method: 'GET', path: '/prompts/bootstrap', clientMethod: 'getBootstrap' },
    { method: 'PUT', path: '/prompts/bootstrap', clientMethod: 'updateBootstrap' },
    { method: 'POST', path: '/prompts/bootstrap/append', clientMethod: 'appendBootstrap' },
    { method: 'GET', path: '/prompts/channels/{name}', clientMethod: 'getChannel' },
    { method: 'PUT', path: '/prompts/channels/{name}', clientMethod: 'updateChannel' },
    { method: 'POST', path: '/prompts/channels', clientMethod: 'createChannel' },
    { method: 'DELETE', path: '/prompts/channels/{name}', clientMethod: 'deleteChannel' },
  ],
  providers: [
    { method: 'GET', path: '/providers', clientMethod: 'list' },
    { method: 'POST', path: '/providers', clientMethod: 'add' },
    { method: 'GET', path: '/providers/{id}', clientMethod: 'get' },
    { method: 'PUT', path: '/providers/{id}', clientMethod: 'update' },
    { method: 'DELETE', path: '/providers/{id}', clientMethod: 'remove' },
    { method: 'PUT', path: '/providers/{id}/enable', clientMethod: 'enable' },
    { method: 'PUT', path: '/providers/{id}/disable', clientMethod: 'disable' },
    { method: 'POST', path: '/providers/{id}/connect', clientMethod: 'connect' },
    { method: 'POST', path: '/providers/{id}/disconnect', clientMethod: 'disconnect' },
    { method: 'POST', path: '/providers/{id}/test', clientMethod: 'test' },
    { method: 'GET', path: '/providers/types', clientMethod: 'getTypes' },
    { method: 'GET', path: '/providers/schema/{type}', clientMethod: 'getSchema' },
  ],
};

// Parse router.mbt to extract defined routes
function parseRouterFile(content: string): Map<string, Set<string>> {
  const routes = new Map<string, Set<string>>();

  // Match patterns like: ("GET", "retry") => return (handlers.get_retry.0)(ctx)
  // and: "GET" => return (handlers.list.0)(ctx)
  const routePatterns = [
    // Match tuple patterns: ("METHOD", "path")
    /\("(GET|POST|PUT|DELETE)",\s*"([^"]+)"\)\s*=>/g,
    // Match simple method patterns in if statements
    /if\s+meth\s*==\s*"(GET|POST|PUT|DELETE)"/g,
    // Match: match meth { "GET" => ...
    /meth\s*\{\s*"(GET|POST|PUT|DELETE)"\s*=>/g,
  ];

  // Extract route segments from comments like: // /settings/retry
  const commentPatterns = /\/\/\s*\/([\w\/\{\}]+)/g;

  let match;

  // Find route function blocks and their methods
  const functionBlocks = content.split(/fn\s+route_\w+_endpoint/);

  for (const block of functionBlocks) {
    // Determine which resource this block handles
    let resource = '';
    if (block.includes('PluginApiHandlers')) resource = 'plugins';
    else if (block.includes('PromptApiHandlers')) resource = 'prompts';
    else if (block.includes('SettingsApiHandlers')) resource = 'settings';
    else if (block.includes('ProviderApiHandlers')) resource = 'providers';
    else if (block.includes('ConfigApiHandlers')) resource = 'config';

    if (!resource) continue;

    if (!routes.has(resource)) {
      routes.set(resource, new Set());
    }

    // Find all method-path combinations
    const lines = block.split('\n');
    let currentPath = '';

    for (const line of lines) {
      // Check for path comments
      const pathMatch = line.match(/\/\/\s*\/(\w+(?:\/[\w\{\}]+)*)/);
      if (pathMatch) {
        currentPath = '/' + pathMatch[1];
      }

      // Check for method matches
      const methodMatch = line.match(/\("(GET|POST|PUT|DELETE)",\s*"([^"]+)"\)/);
      if (methodMatch) {
        routes.get(resource)!.add(`${methodMatch[1]} /${resource}/${methodMatch[2]}`);
      }

      // Check for simple method in current path context
      const simpleMatch = line.match(/meth\s*==\s*"(GET|POST|PUT|DELETE)"/);
      if (simpleMatch && currentPath) {
        routes.get(resource)!.add(`${simpleMatch[1]} ${currentPath}`);
      }
    }
  }

  return routes;
}

// Parse handler struct to find defined handlers
function parseHandlerStruct(content: string, structName: string): Set<string> {
  const handlers = new Set<string>();

  // Find the struct block - handle multiline with comments
  const structRegex = new RegExp(
    `pub\\(all\\)\\s+struct\\s+${structName}\\s*\\{([\\s\\S]*?)^\\}`,
    'm'
  );
  const structMatch = content.match(structRegex);

  if (structMatch) {
    // Extract field names that have RouteHandler type
    const fields = structMatch[1].matchAll(/^\s*(?:\/\/\/[^\n]*\n\s*)*(\w+)\s*:\s*RouteHandler/gm);
    for (const field of fields) {
      handlers.add(field[1]);
    }
  }

  return handlers;
}

// Map client method names to handler names
function clientMethodToHandler(method: string, resource: string): string {
  // Special cases for naming mismatches
  if (resource === 'providers' && method === 'test') {
    return 'test_connection';
  }
  // Convert camelCase to snake_case
  return method.replace(/([A-Z])/g, '_$1').toLowerCase();
}

// Check API consistency
async function checkConsistency() {
  const projectRoot = join(import.meta.dir, '..');
  const routerPath = join(projectRoot, 'api/v1/router.mbt');

  console.log('🔍 API Consistency Check\n');
  console.log('='.repeat(60));

  let hasErrors = false;
  const results: { resource: string; missing: string[]; extra: string[] }[] = [];

  // Read router file
  const routerContent = readFileSync(routerPath, 'utf-8');

  // Map resource names to struct names (handle plural -> singular)
  const resourceToStruct: Record<string, string> = {
    settings: 'SettingsApiHandlers',
    plugins: 'PluginApiHandlers',    // singular
    prompts: 'PromptApiHandlers',    // singular
    providers: 'ProviderApiHandlers', // singular
  };

  // Check each resource
  for (const [resource, endpoints] of Object.entries(CLIENT_ENDPOINTS)) {
    const structName = resourceToStruct[resource] || resource.charAt(0).toUpperCase() + resource.slice(1) + 'ApiHandlers';

    const handlers = parseHandlerStruct(routerContent, structName);
    const missing: string[] = [];
    const extra: string[] = [];

    // Check each endpoint
    for (const ep of endpoints) {
      const handlerName = clientMethodToHandler(ep.clientMethod, resource);

      // Check if handler exists in struct
      if (!handlers.has(handlerName)) {
        missing.push(`${ep.method} ${ep.path} (handler: ${handlerName})`);
        hasErrors = true;
      }
    }

    // Check for extra handlers not in client
    const expectedHandlers = new Set(endpoints.map(ep => clientMethodToHandler(ep.clientMethod, resource)));
    for (const handler of handlers) {
      if (!expectedHandlers.has(handler)) {
        extra.push(handler);
      }
    }

    results.push({ resource, missing, extra });
  }

  // Print results
  for (const { resource, missing, extra } of results) {
    console.log(`\n📦 ${resource.toUpperCase()}`);
    console.log('-'.repeat(40));

    if (missing.length === 0 && extra.length === 0) {
      console.log('  ✅ All endpoints consistent');
    } else {
      if (missing.length > 0) {
        console.log('  ❌ Missing in backend:');
        for (const m of missing) {
          console.log(`     - ${m}`);
        }
      }
      if (extra.length > 0) {
        console.log('  ⚠️  Extra handlers (not in client):');
        for (const e of extra) {
          console.log(`     - ${e}`);
        }
      }
    }
  }

  console.log('\n' + '='.repeat(60));

  if (hasErrors) {
    console.log('❌ API consistency check FAILED');
    console.log('\nTo fix:');
    console.log('1. Add missing handlers to the backend SettingsApiHandlers struct');
    console.log('2. Add routes in route_*_endpoint functions');
    console.log('3. Implement handler functions');
    process.exit(1);
  } else {
    console.log('✅ API consistency check PASSED');
  }
}

checkConsistency();
