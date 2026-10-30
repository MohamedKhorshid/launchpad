// Typed client for the Go backend. Keep in sync with backend/internal/modules/*.
// VITE_API_URL is injected at build time by devops/scripts/deploy-web.sh;
// locally it falls back to the Vite proxy at /api.
const BASE = (import.meta.env.VITE_API_URL as string | undefined) ?? "/api";

export type Note = { id: string; title: string; body: string; createdAt: string };

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error ?? `Request failed: ${res.status}`);
  }
  return res.status === 204 ? (undefined as T) : res.json();
}

export const api = {
  health: () => request<{ status: string; version: string }>("/health"),
  listNotes: () => request<{ items: Note[] }>("/v1/notes").then((r) => r.items),
  createNote: (title: string, body = "") =>
    request<Note>("/v1/notes", { method: "POST", body: JSON.stringify({ title, body }) }),
  deleteNote: (id: string) => request<void>(`/v1/notes/${id}`, { method: "DELETE" }),
};
