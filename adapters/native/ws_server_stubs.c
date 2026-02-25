/**
 * WebSocket Server C Stubs for MoonBit FFI
 *
 * This provides a simple WebSocket server implementation using libwebsockets.
 * For production use, link against libwebsockets (-lwebsockets).
 *
 * This stub implementation provides mock functionality for testing.
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Mock WebSocket server context
typedef struct {
    int port;
    int is_running;
    int client_count;
    int next_client_id;
} WsServerContext;

// Mock WebSocket client
typedef struct {
    int id;
    int is_connected;
    char* pending_message;
} WsClientContext;

// Maximum clients
#define MAX_CLIENTS 1024
static WsClientContext* clients[MAX_CLIENTS] = {0};

/**
 * Create a new WebSocket server
 */
void* moonbit_ws_server_create(int port) {
    WsServerContext* ctx = (WsServerContext*)malloc(sizeof(WsServerContext));
    if (!ctx) return NULL;

    ctx->port = port;
    ctx->is_running = 0;
    ctx->client_count = 0;
    ctx->next_client_id = 1;

    return ctx;
}

/**
 * Start the WebSocket server
 */
int moonbit_ws_server_start(void* server) {
    if (!server) return -1;

    WsServerContext* ctx = (WsServerContext*)server;
    ctx->is_running = 1;

    // In a real implementation, this would start listening on the port
    // For now, we just mark it as running
    return 0;
}

/**
 * Stop the WebSocket server
 */
int moonbit_ws_server_stop(void* server) {
    if (!server) return -1;

    WsServerContext* ctx = (WsServerContext*)server;
    ctx->is_running = 0;

    return 0;
}

/**
 * Destroy the WebSocket server
 */
void moonbit_ws_server_destroy(void* server) {
    if (!server) return;

    WsServerContext* ctx = (WsServerContext*)server;

    // Clean up any remaining clients
    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i]) {
            if (clients[i]->pending_message) {
                free(clients[i]->pending_message);
            }
            free(clients[i]);
            clients[i] = NULL;
        }
    }

    free(ctx);
}

/**
 * Check if server is running
 */
int moonbit_ws_server_is_running(void* server) {
    if (!server) return 0;

    WsServerContext* ctx = (WsServerContext*)server;
    return ctx->is_running;
}

/**
 * Get server port
 */
int moonbit_ws_server_get_port(void* server) {
    if (!server) return 0;

    WsServerContext* ctx = (WsServerContext*)server;
    return ctx->port;
}

/**
 * Get client count
 */
int moonbit_ws_server_client_count(void* server) {
    if (!server) return 0;

    WsServerContext* ctx = (WsServerContext*)server;
    return ctx->client_count;
}

/**
 * Accept a new client connection (mock)
 * Returns client ID or -1 on error
 */
int moonbit_ws_server_accept_client(void* server) {
    if (!server) return -1;

    WsServerContext* ctx = (WsServerContext*)server;
    if (!ctx->is_running) return -1;

    // Find an empty slot
    int slot = -1;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (!clients[i]) {
            slot = i;
            break;
        }
    }

    if (slot < 0) return -1;

    // Create client
    WsClientContext* client = (WsClientContext*)malloc(sizeof(WsClientContext));
    if (!client) return -1;

    client->id = ctx->next_client_id++;
    client->is_connected = 1;
    client->pending_message = NULL;

    clients[slot] = client;
    ctx->client_count++;

    return client->id;
}

/**
 * Disconnect a client
 */
int moonbit_ws_server_disconnect_client(void* server, int client_id) {
    if (!server) return -1;

    WsServerContext* ctx = (WsServerContext*)server;

    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i] && clients[i]->id == client_id) {
            if (clients[i]->pending_message) {
                free(clients[i]->pending_message);
            }
            free(clients[i]);
            clients[i] = NULL;
            ctx->client_count--;
            return 0;
        }
    }

    return -1;
}

/**
 * Send message to a client
 */
int moonbit_ws_server_send(void* server, int client_id, const char* message) {
    if (!server || !message) return -1;

    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i] && clients[i]->id == client_id && clients[i]->is_connected) {
            // In a real implementation, this would send the message over WebSocket
            // For mock, we just return success
            return 0;
        }
    }

    return -1;
}

/**
 * Broadcast message to all clients
 */
int moonbit_ws_server_broadcast(void* server, const char* message) {
    if (!server || !message) return -1;

    WsServerContext* ctx = (WsServerContext*)server;
    if (!ctx->is_running) return -1;

    int sent = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i] && clients[i]->is_connected) {
            // In a real implementation, this would send to each client
            sent++;
        }
    }

    return sent;
}

/**
 * Poll for incoming messages (mock)
 * Returns client ID that has a message, or -1 if none
 */
int moonbit_ws_server_poll(void* server) {
    if (!server) return -1;

    WsServerContext* ctx = (WsServerContext*)server;
    if (!ctx->is_running) return -1;

    // In a real implementation, this would check for incoming messages
    // For mock, we always return -1 (no messages)
    return -1;
}

/**
 * Get pending message from a client
 * Caller must free the returned string
 */
char* moonbit_ws_server_get_message(void* server, int client_id) {
    if (!server) return NULL;

    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i] && clients[i]->id == client_id) {
            char* msg = clients[i]->pending_message;
            clients[i]->pending_message = NULL;
            return msg;
        }
    }

    return NULL;
}

/**
 * Set a pending message for a client (for testing)
 */
int moonbit_ws_server_set_pending_message(void* server, int client_id, const char* message) {
    if (!server || !message) return -1;

    for (int i = 0; i < MAX_CLIENTS; i++) {
        if (clients[i] && clients[i]->id == client_id) {
            if (clients[i]->pending_message) {
                free(clients[i]->pending_message);
            }
            clients[i]->pending_message = strdup(message);
            return 0;
        }
    }

    return -1;
}
