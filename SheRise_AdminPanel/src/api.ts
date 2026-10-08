export type Admin = { id: string; email: string; role: string; permissions?: string[] }
const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://127.0.0.1:10201'
let accessToken = sessionStorage.getItem('sherise_admin_access')
export const getAdminToken = () => accessToken
export const setAdminToken = (token: string | null) => { accessToken = token; token ? sessionStorage.setItem('sherise_admin_access', token) : sessionStorage.removeItem('sherise_admin_access') }

async function request(path: string, init: RequestInit = {}, retry = true): Promise<any> {
  const headers = new Headers(init.headers)
  headers.set('Content-Type', 'application/json')
  if (accessToken) headers.set('Authorization', `Bearer ${accessToken}`)
  const response = await fetch(`${API_BASE}${path}`, { ...init, headers, credentials: 'include' })
  if (response.status === 401 && retry && path !== '/api/admin/login' && path !== '/api/admin/refresh') {
    const refreshed = await request('/api/admin/refresh', { method: 'POST' }, false).catch(() => null)
    if (refreshed?.data?.accessToken) { setAdminToken(refreshed.data.accessToken); return request(path, init, false) }
  }
  const body = await response.json().catch(() => ({}))
  if (!response.ok) {
    if (response.status === 429) throw new Error('Too many reset requests. Please wait before requesting another OTP.')
    if (response.status === 503 && path === '/api/admin/forgot-password') throw new Error('Password reset email is not configured on the backend. Configure SMTP_EMAIL and SMTP_PASSWORD first.')
    throw new Error(body.message || `Request failed (${response.status})`)
  }
  return body
}
export const api = {
  login: async (email: string, password: string) => { const result = await request('/api/admin/login', { method: 'POST', body: JSON.stringify({ email, password }) }); setAdminToken(result.data.accessToken); return result.data.admin as Admin },
  me: async () => (await request('/api/admin/me')).data as Admin,
  logout: async () => { await request('/api/admin/logout', { method: 'POST' }); setAdminToken(null) },
  get: (path: string) => request(path),
  patch: (path: string, body: unknown) => request(path, { method: 'PATCH', body: JSON.stringify(body) }),
  post: (path: string, body: unknown) => request(path, { method: 'POST', body: JSON.stringify(body) }),
  delete: (path: string, body?: unknown) => request(path, { method: 'DELETE', body: body ? JSON.stringify(body) : undefined }),
  forgotPassword: (email: string) => request('/api/admin/forgot-password', { method: 'POST', body: JSON.stringify({ email }) }),
  resetPassword: (email: string, otp: string, password: string) => request('/api/admin/reset-password', { method: 'POST', body: JSON.stringify({ email, otp, password }) }),
}
