/**
 * Mukuro API Client Errors
 */

import type { ApiError } from './types.js';

export class MukuroApiError extends Error {
  public readonly status: number;
  public readonly code: string;
  public readonly details?: Record<string, unknown>;

  constructor(status: number, error: ApiError) {
    super(error.message);
    this.name = 'MukuroApiError';
    this.status = status;
    this.code = error.error;
    this.details = error.details;
  }

  static fromResponse(status: number, body: unknown): MukuroApiError {
    if (typeof body === 'object' && body !== null) {
      const obj = body as Record<string, unknown>;
      return new MukuroApiError(status, {
        error: String(obj.error ?? 'unknown_error'),
        message: String(obj.message ?? 'Unknown error'),
        details: obj.details as Record<string, unknown> | undefined,
      });
    }
    return new MukuroApiError(status, {
      error: 'unknown_error',
      message: String(body),
    });
  }

  isNotFound(): boolean {
    return this.status === 404;
  }

  isUnauthorized(): boolean {
    return this.status === 401;
  }

  isForbidden(): boolean {
    return this.status === 403;
  }

  isValidationError(): boolean {
    return this.status === 400 || this.status === 422;
  }

  isServerError(): boolean {
    return this.status >= 500;
  }
}

export class MukuroNetworkError extends Error {
  public readonly cause?: Error;

  constructor(message: string, cause?: Error) {
    super(message);
    this.name = 'MukuroNetworkError';
    this.cause = cause;
  }
}

export class MukuroTimeoutError extends Error {
  public readonly timeoutMs: number;

  constructor(timeoutMs: number) {
    super(`Request timed out after ${timeoutMs}ms`);
    this.name = 'MukuroTimeoutError';
    this.timeoutMs = timeoutMs;
  }
}
