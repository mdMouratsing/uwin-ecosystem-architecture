// ============================================================================
// API Client — typed request/response helpers with standard error handling
// ============================================================================

import type {
  ApiResponse,
  ApiListResponse,
  ApiError,
  PaginatedQuery,
} from '../shared-types';
import { DEFAULT_PAGE_SIZE } from '../config';

export class ApiClientError extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
    this.name = 'ApiClientError';
  }
}

function buildQueryString(params: PaginatedQuery & Record<string, unknown>): string {
  const searchParams = new URLSearchParams();
  if (params.page) searchParams.set('page', String(params.page));
  if (params.pageSize) searchParams.set('page_size', String(params.pageSize));
  if (params.search) searchParams.set('search', params.search);
  if (params.sortBy) searchParams.set('sort_by', params.sortBy);
  if (params.sortOrder) searchParams.set('sort_order', params.sortOrder);
  if (params.cursor) searchParams.set('cursor', params.cursor);

  for (const [key, value] of Object.entries(params)) {
    if (!['page', 'pageSize', 'search', 'sortBy', 'sortOrder', 'cursor'].includes(key) && value != null) {
      searchParams.set(key, String(value));
    }
  }

  const qs = searchParams.toString();
  return qs ? `?${qs}` : '';
}

export async function apiGet<T>(
  endpoint: string,
  params?: PaginatedQuery & Record<string, unknown>,
): Promise<ApiResponse<T>> {
  const url = `${endpoint}${params ? buildQueryString(params) : ''}`;
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json' },
  });
  return handleResponse<T>(response);
}

export async function apiGetList<T>(
  endpoint: string,
  params?: PaginatedQuery & Record<string, unknown>,
): Promise<ApiListResponse<T>> {
  const url = `${endpoint}${params ? buildQueryString({ ...params, pageSize: params.pageSize ?? DEFAULT_PAGE_SIZE }) : `?page_size=${DEFAULT_PAGE_SIZE}`}`;
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json' },
  });
  return handleResponseList<T>(response);
}

export async function apiPost<T>(
  endpoint: string,
  body: Record<string, unknown>,
): Promise<ApiResponse<T>> {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return handleResponse<T>(response);
}

export async function apiPut<T>(
  endpoint: string,
  body: Record<string, unknown>,
): Promise<ApiResponse<T>> {
  const response = await fetch(endpoint, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return handleResponse<T>(response);
}

export async function apiDelete<T>(endpoint: string): Promise<ApiResponse<T>> {
  const response = await fetch(endpoint, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
  });
  return handleResponse<T>(response);
}

async function handleResponse<T>(response: Response): Promise<ApiResponse<T>> {
  if (!response.ok) {
    const errorBody = (await safeParseJson(response)) as ApiError | null;
    const code = errorBody?.error?.code ?? 'UNKNOWN_ERROR';
    const message = errorBody?.error?.message ?? 'Request failed';
    throw new ApiClientError(code, message, response.status);
  }
  const data = (await response.json()) as ApiResponse<T>;
  return data;
}

async function handleResponseList<T>(response: Response): Promise<ApiListResponse<T>> {
  if (!response.ok) {
    const errorBody = (await safeParseJson(response)) as ApiError | null;
    const code = errorBody?.error?.code ?? 'UNKNOWN_ERROR';
    const message = errorBody?.error?.message ?? 'Request failed';
    throw new ApiClientError(code, message, response.status);
  }
  const data = (await response.json()) as ApiListResponse<T>;
  return data;
}

async function safeParseJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export function getUserFacingMessage(error: unknown): string {
  if (error instanceof ApiClientError) {
    switch (error.code) {
      case 'RESOURCE_NOT_FOUND':
        return 'The requested item could not be found.';
      case 'UNAUTHORIZED':
        return 'You need to sign in to access this.';
      case 'FORBIDDEN':
        return 'You do not have permission to do this.';
      case 'VALIDATION_ERROR':
        return 'Please check the provided information and try again.';
      default:
        return 'Could not complete the request. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
