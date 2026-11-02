/**
 * Reads a request body as UTF-8 text, or returns null as soon as it passes
 * `limit` bytes. Counting bytes as they arrive also covers chunked uploads,
 * which have no Content-Length.
 */
export async function readBody(req: Request, limit: number): Promise<string | null> {
  if (!req.body) return "";
  const reader = req.body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  let text = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      reader.cancel().catch(() => {});
      return null;
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}
