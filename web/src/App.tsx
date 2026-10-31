import { useEffect, useState, type FormEvent } from "react";
import { api, type Note } from "./api";

// Placeholder screen proving web -> CloudFront -> Kong -> Go works end to end.
// Replace it with your real app (see .claude/skills/design-to-code).
export function App() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [title, setTitle] = useState("");
  const [version, setVersion] = useState("…");
  const [error, setError] = useState<string | null>(null);

  const refresh = () => api.listNotes().then(setNotes).catch((e: Error) => setError(e.message));

  useEffect(() => {
    api.health().then((h) => setVersion(h.version)).catch(() => setVersion("offline"));
    refresh();
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    try {
      await api.createNote(title.trim());
      setTitle("");
      setError(null);
      refresh();
    } catch (err) {
      setError((err as Error).message);
    }
  }

  return (
    <main className="container">
      <header>
        <h1>Launchpad</h1>
        <span className="badge">API {version}</span>
      </header>
      <form onSubmit={onSubmit}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Write a note" aria-label="Note title" />
        <button type="submit">Add</button>
      </form>
      {error && <p className="error">{error}</p>}
      <ul>
        {notes.map((n) => (
          <li key={n.id}>
            <span>{n.title}</span>
            <button className="link" onClick={() => api.deleteNote(n.id).then(refresh)} aria-label={`Delete ${n.title}`}>
              Delete
            </button>
          </li>
        ))}
      </ul>
      {notes.length === 0 && <p className="muted">No notes yet.</p>}
    </main>
  );
}
