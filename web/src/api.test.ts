import { afterEach, describe, expect, it, vi } from "vitest";
import { api } from "./api";

afterEach(() => vi.restoreAllMocks());

describe("api client", () => {
  it("unwraps the notes list", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ items: [{ id: "1", title: "a", body: "", createdAt: "" }] }), { status: 200 }),
    ));
    await expect(api.listNotes()).resolves.toHaveLength(1);
  });

  it("surfaces backend error messages", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: "title is required" }), { status: 422 }),
    ));
    await expect(api.createNote("")).rejects.toThrow("title is required");
  });
});
