/** Error carrying an HTTP status and a stable machine-readable code. */
export class AppError extends Error {
  constructor(
    readonly statusCode: number,
    readonly code: string,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const badRequest = (code: string, message: string, details?: unknown) =>
  new AppError(400, code, message, details);

export const notFound = (code: string, message: string) => new AppError(404, code, message);

export const unprocessable = (code: string, message: string, details?: unknown) =>
  new AppError(422, code, message, details);

/** A capability the server was not configured for (missing API key, etc.). */
export const unavailable = (code: string, message: string) => new AppError(503, code, message);

/** An upstream provider failed. Keeps the provider name for logging/telemetry. */
export class UpstreamError extends AppError {
  constructor(
    readonly provider: string,
    message: string,
    readonly upstreamStatus?: number,
    details?: unknown,
  ) {
    super(502, 'upstream_error', message, details);
    this.name = 'UpstreamError';
  }
}
