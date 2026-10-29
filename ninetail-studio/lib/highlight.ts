// Small hand-written syntax highlighter for the three output languages.
//
// It returns plain { kind, text } tokens (never HTML), so callers render them as
// React text inside <span>s and nothing from the model is ever injected as markup.
// The lexers are forgiving: half-streamed code (an unterminated string or comment)
// simply runs to the end of the input.

import type { CodeLanguage } from "./types";

export type TokenKind =
  | "plain"
  | "text"
  | "comment"
  | "keyword"
  | "string"
  | "number"
  | "function"
  | "punct"
  | "tag"
  | "attr"
  | "type"
  | "preproc"
  | "imgui"
  | "builtin"
  | "decorator"
  | "self"
  | "entity"
  | "selector"
  | "property";

export interface Token {
  kind: TokenKind;
  text: string;
}

/** Colors for each token kind (dark theme). */
export const TOKEN_COLORS: Record<TokenKind, string> = {
  plain: "#d4d0ea",
  text: "#ebe8fa",
  comment: "#6b6889",
  keyword: "#c4b5fd",
  string: "#67e8f9",
  number: "#f0abfc",
  function: "#f6f4ff",
  punct: "#9a96b8",
  tag: "#a78bfa",
  attr: "#d9d4f5",
  type: "#e9d5ff",
  preproc: "#f0abfc",
  imgui: "#a78bfa",
  builtin: "#ddd6fe",
  decorator: "#f0abfc",
  self: "#f0abfc",
  entity: "#f0abfc",
  selector: "#a78bfa",
  property: "#d9d4f5",
};

/** Extra font styling per kind. */
export const TOKEN_STYLES: Partial<Record<TokenKind, { fontStyle?: "italic"; fontWeight?: number }>> = {
  comment: { fontStyle: "italic" },
  self: { fontStyle: "italic" },
  imgui: { fontWeight: 500 },
  function: { fontWeight: 500 },
};

// ---------------------------------------------------------------------------
// Token buffer
// ---------------------------------------------------------------------------

class Out {
  tokens: Token[] = [];
  push(kind: TokenKind, text: string) {
    if (!text) return;
    const last = this.tokens[this.tokens.length - 1];
    if (last && last.kind === kind) last.text += text;
    else this.tokens.push({ kind, text });
  }
  /** Last token that is not pure whitespace. */
  prev(): Token | undefined {
    for (let i = this.tokens.length - 1; i >= 0; i--) {
      if (this.tokens[i].text.trim()) return this.tokens[i];
    }
    return undefined;
  }
}

/** True when only spaces/tabs sit between the start of the line and `i`. */
function atLineStart(src: string, i: number): boolean {
  for (let j = i - 1; j >= 0; j--) {
    const c = src[j];
    if (c === "\n") return true;
    if (c !== " " && c !== "\t") return false;
  }
  return true;
}

/** Next non-space character at or after `i`. */
function peekNonSpace(src: string, i: number): string {
  while (i < src.length && (src[i] === " " || src[i] === "\t")) i++;
  return src[i] ?? "";
}

function stickyMatch(re: RegExp, src: string, i: number): string | null {
  re.lastIndex = i;
  const m = re.exec(src);
  return m && m[0].length ? m[0] : null;
}

const WS = /[ \t\r\n]+/y;
const IDENT = /[A-Za-z_$][\w$]*/y;
const PY_IDENT = /[A-Za-z_][\w]*/y;

// ---------------------------------------------------------------------------
// C++
// ---------------------------------------------------------------------------

const CPP_KEYWORDS = new Set(
  (
    "alignas alignof and asm break case catch class co_await co_return co_yield concept const consteval constexpr " +
    "constinit const_cast continue decltype default delete do dynamic_cast else enum explicit export extern false " +
    "for friend goto if inline mutable namespace new noexcept not nullptr operator or private protected public " +
    "register reinterpret_cast requires return sizeof static static_assert static_cast struct switch template this " +
    "thread_local throw true try typedef typeid typename union using virtual volatile while override final"
  ).split(" "),
);

const CPP_TYPES = new Set(
  (
    "void bool char wchar_t char8_t char16_t char32_t short int long float double signed unsigned auto size_t " +
    "ssize_t ptrdiff_t intptr_t uintptr_t int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t " +
    "std string string_view vector array map unordered_map optional function unique_ptr shared_ptr pair tuple"
  ).split(" "),
);

const CPP_COMMENT_LINE = /\/\/[^\n]*/y;
const CPP_COMMENT_BLOCK = /\/\*[\s\S]*?(?:\*\/|$)/y;
const CPP_PREPROC = /#[ \t]*[A-Za-z_]+/y;
const CPP_INCLUDE_PATH = /<[\w./+-]+>/y;
const CPP_RAW_STRING = /R"([^(\s"\\]{0,16})\([\s\S]*?(?:\)\1"|$)/y;
const CPP_STRING = /(?:u8|u|U|L)?"(?:\\[\s\S]|[^"\\\n])*"?/y;
const CPP_CHAR = /'(?:\\.|[^'\\\n]){1,8}'/y;
const CPP_NUMBER = /(?:0[xX][\da-fA-F']+|0[bB][01']+|(?:\d[\d']*\.?[\d']*|\.\d[\d']*)(?:[eE][+-]?\d+)?)[uUlLfF]*/y;
const CPP_PUNCT = /->|::|[{}()[\];,.<>+\-*/%=&|!?:^~]/y;

function classifyCppIdent(word: string, src: string, start: number, end: number, out: Out): TokenKind {
  if (word === "ImGui" && src.startsWith("::", end)) return "imgui";
  if (start >= 7 && src.slice(start - 7, start) === "ImGui::") return "imgui";
  if (/^IM_[A-Z0-9_]+$/.test(word)) return "imgui";
  if (CPP_KEYWORDS.has(word)) return "keyword";
  if (CPP_TYPES.has(word)) return "type";
  if (/^Im[A-Z]\w*$/.test(word)) return "type";
  const prev = out.prev();
  const call = peekNonSpace(src, end) === "(";
  if (call && prev && (prev.text.endsWith("->") || prev.text.endsWith(".")) && /^(Add|Path|Prim|PushClipRect|PopClipRect|Channels)/.test(word)) {
    return "imgui";
  }
  if (call) return "function";
  if (/^[A-Z][A-Z0-9_]{2,}$/.test(word)) return "preproc";
  return "plain";
}

function tokenizeCpp(src: string): Token[] {
  const out = new Out();
  let i = 0;
  const n = src.length;
  let lastWasInclude = false;
  while (i < n) {
    let m: string | null;
    if ((m = stickyMatch(WS, src, i))) {
      out.push("plain", m);
      if (m.includes("\n")) lastWasInclude = false;
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(CPP_COMMENT_LINE, src, i)) || (m = stickyMatch(CPP_COMMENT_BLOCK, src, i))) {
      out.push("comment", m);
      i += m.length;
      continue;
    }
    if (src[i] === "#" && atLineStart(src, i) && (m = stickyMatch(CPP_PREPROC, src, i))) {
      out.push("preproc", m);
      lastWasInclude = /include|import/.test(m);
      i += m.length;
      continue;
    }
    if (lastWasInclude && src[i] === "<" && (m = stickyMatch(CPP_INCLUDE_PATH, src, i))) {
      out.push("string", m);
      i += m.length;
      lastWasInclude = false;
      continue;
    }
    if (src[i] === "R" && src[i + 1] === '"' && (m = stickyMatch(CPP_RAW_STRING, src, i))) {
      out.push("string", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(CPP_STRING, src, i)) || (src[i] === "'" && (m = stickyMatch(CPP_CHAR, src, i)))) {
      out.push("string", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(IDENT, src, i))) {
      out.push(classifyCppIdent(m, src, i, i + m.length, out), m);
      i += m.length;
      continue;
    }
    if (/[\d.]/.test(src[i]) && (m = stickyMatch(CPP_NUMBER, src, i)) && m !== ".") {
      out.push("number", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(CPP_PUNCT, src, i))) {
      out.push("punct", m);
      i += m.length;
      continue;
    }
    out.push("plain", src[i]);
    i++;
  }
  return out.tokens;
}

// ---------------------------------------------------------------------------
// Python
// ---------------------------------------------------------------------------

const PY_KEYWORDS = new Set(
  (
    "False None True and as assert async await break class continue def del elif else except finally for from " +
    "global if import in is lambda nonlocal not or pass raise return try while with yield match case"
  ).split(" "),
);

const PY_BUILTINS = new Set(
  (
    "print len range str int float list dict set tuple bool bytes super isinstance issubclass enumerate zip open " +
    "min max sum abs round sorted reversed map filter any all type getattr setattr hasattr object property " +
    "staticmethod classmethod iter next format repr hash id input divmod pow chr ord hex bin oct callable vars " +
    "Exception ValueError TypeError KeyError IndexError RuntimeError OSError"
  ).split(" "),
);

const PY_COMMENT = /#[^\n]*/y;
const PY_TRIPLE = /(?:[rRbBuUfF]{1,2})?("""|''')[\s\S]*?(?:\1|$)/y;
const PY_STRING = /(?:[rRbBuUfF]{1,2})?(?:"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?)/y;
const PY_DECORATOR = /@[A-Za-z_][\w.]*/y;
const PY_NUMBER = /(?:0[xXoObB][\da-fA-F_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?[jJ]?)/y;
const PY_PUNCT = /->|\*\*|\/\/|[{}()[\];,.<>+\-*/%=&|!:^~@]/y;

/** Splits an f-string into string parts and `{expression}` parts. */
function pushFString(out: Out, lit: string) {
  const re = /\{\{|\}\}|\{[^{}\n]*\}?/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(lit))) {
    if (m[0] === "{{" || m[0] === "}}") continue;
    out.push("string", lit.slice(last, m.index));
    const body = m[0];
    const closed = body.endsWith("}");
    out.push("punct", "{");
    const inner = body.slice(1, closed ? -1 : undefined);
    const fmt = inner.indexOf(":");
    if (fmt > 0) {
      out.push("plain", inner.slice(0, fmt));
      out.push("number", inner.slice(fmt));
    } else {
      out.push("plain", inner);
    }
    if (closed) out.push("punct", "}");
    last = m.index + body.length;
  }
  out.push("string", lit.slice(last));
}

function tokenizePython(src: string): Token[] {
  const out = new Out();
  let i = 0;
  const n = src.length;
  while (i < n) {
    let m: string | null;
    if ((m = stickyMatch(WS, src, i))) {
      out.push("plain", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(PY_COMMENT, src, i))) {
      out.push("comment", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(PY_TRIPLE, src, i)) || (m = stickyMatch(PY_STRING, src, i))) {
      const prefix = /^[rRbBuUfF]{0,2}/.exec(m)?.[0] ?? "";
      if (/f/i.test(prefix)) pushFString(out, m);
      else out.push("string", m);
      i += m.length;
      continue;
    }
    if (src[i] === "@" && atLineStart(src, i) && (m = stickyMatch(PY_DECORATOR, src, i))) {
      out.push("decorator", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(PY_IDENT, src, i))) {
      const end = i + m.length;
      let kind: TokenKind = "plain";
      const prev = out.prev();
      if (PY_KEYWORDS.has(m)) kind = "keyword";
      else if (m === "self" || m === "cls") kind = "self";
      else if (prev && prev.kind === "keyword" && /(?:^|\s)(def|class)$/.test(prev.text)) kind = "function";
      else if (/^CTk[A-Z]?\w*$/.test(m)) kind = "type";
      else if (PY_BUILTINS.has(m) && !(prev && prev.text.endsWith("."))) kind = "builtin";
      else if (peekNonSpace(src, end) === "(") kind = "function";
      else if (/^[A-Z][A-Z0-9_]{2,}$/.test(m)) kind = "number";
      out.push(kind, m);
      i = end;
      continue;
    }
    if (/[\d.]/.test(src[i]) && (m = stickyMatch(PY_NUMBER, src, i)) && m !== ".") {
      out.push("number", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(PY_PUNCT, src, i))) {
      out.push("punct", m);
      i += m.length;
      continue;
    }
    out.push("plain", src[i]);
    i++;
  }
  return out.tokens;
}

// ---------------------------------------------------------------------------
// JavaScript (inside <script>)
// ---------------------------------------------------------------------------

const JS_KEYWORDS = new Set(
  (
    "async await break case catch class const continue debugger default delete do else export extends false finally " +
    "for from function if import in instanceof let new null of return static super switch this throw true try typeof " +
    "undefined var void while with yield"
  ).split(" "),
);
const JS_GLOBALS = new Set("document window console Math JSON Date Array Object Number String Promise localStorage setTimeout setInterval clearInterval requestAnimationFrame tailwind".split(" "));
const JS_COMMENT_LINE = /\/\/[^\n]*/y;
const JS_COMMENT_BLOCK = /\/\*[\s\S]*?(?:\*\/|$)/y;
const JS_STRING = /`(?:\\[\s\S]|[^`\\])*`?|"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?/y;
const JS_NUMBER = /(?:0[xX][\da-fA-F_]+|(?:\d[\d_]*\.?[\d_]*|\.\d[\d_]*)(?:[eE][+-]?\d+)?n?)/y;
const JS_PUNCT = /=>|[{}()[\];,.<>+\-*/%=&|!?:^~]/y;

function tokenizeJs(src: string, out: Out) {
  let i = 0;
  const n = src.length;
  while (i < n) {
    let m: string | null;
    if ((m = stickyMatch(WS, src, i))) {
      out.push("plain", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(JS_COMMENT_LINE, src, i)) || (m = stickyMatch(JS_COMMENT_BLOCK, src, i))) {
      out.push("comment", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(JS_STRING, src, i))) {
      out.push("string", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(IDENT, src, i))) {
      const end = i + m.length;
      let kind: TokenKind = "plain";
      if (JS_KEYWORDS.has(m)) kind = "keyword";
      else if (JS_GLOBALS.has(m)) kind = "builtin";
      else if (peekNonSpace(src, end) === "(") kind = "function";
      out.push(kind, m);
      i = end;
      continue;
    }
    if (/[\d.]/.test(src[i]) && (m = stickyMatch(JS_NUMBER, src, i)) && m !== ".") {
      out.push("number", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(JS_PUNCT, src, i))) {
      out.push("punct", m);
      i += m.length;
      continue;
    }
    out.push("plain", src[i]);
    i++;
  }
}

// ---------------------------------------------------------------------------
// CSS (inside <style>)
// ---------------------------------------------------------------------------

const CSS_COMMENT = /\/\*[\s\S]*?(?:\*\/|$)/y;
const CSS_STRING = /"(?:\\.|[^"\\\n])*"?|'(?:\\.|[^'\\\n])*'?/y;
const CSS_AT = /@[\w-]+/y;
const CSS_WORD = /[\w#.%-]+|[*>+~[\]=()]/y;

function tokenizeCss(src: string, out: Out) {
  let i = 0;
  const n = src.length;
  let depth = 0;
  let inValue = false;
  while (i < n) {
    let m: string | null;
    const c = src[i];
    if ((m = stickyMatch(WS, src, i))) {
      out.push("plain", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(CSS_COMMENT, src, i))) {
      out.push("comment", m);
      i += m.length;
      continue;
    }
    if ((m = stickyMatch(CSS_STRING, src, i))) {
      out.push("string", m);
      i += m.length;
      continue;
    }
    if (c === "@" && (m = stickyMatch(CSS_AT, src, i))) {
      out.push("keyword", m);
      i += m.length;
      continue;
    }
    if (c === "{") {
      depth++;
      inValue = false;
      out.push("punct", c);
      i++;
      continue;
    }
    if (c === "}") {
      depth = Math.max(0, depth - 1);
      inValue = false;
      out.push("punct", c);
      i++;
      continue;
    }
    if (c === ";") {
      inValue = false;
      out.push("punct", c);
      i++;
      continue;
    }
    if (c === ":" && depth > 0 && !inValue) {
      inValue = true;
      out.push("punct", c);
      i++;
      continue;
    }
    if ((m = stickyMatch(CSS_WORD, src, i))) {
      let kind: TokenKind;
      if (inValue) kind = /^(#[\da-f]{3,8}|-?[\d.]+[a-z%]*)$/i.test(m) ? "number" : "plain";
      else if (depth > 0 && peekNonSpace(src, i + m.length) === ":" && /^[\w-]+$/.test(m)) kind = "property";
      else kind = "selector";
      out.push(kind, m);
      i += m.length;
      continue;
    }
    out.push("punct", c);
    i++;
  }
}

// ---------------------------------------------------------------------------
// HTML
// ---------------------------------------------------------------------------

const HTML_TAG_NAME = /[A-Za-z][\w:-]*/y;
const HTML_ATTR_NAME = /[^\s=>"'/]+/y;
const HTML_ENTITY = /&(?:#\d{1,7}|#x[\da-fA-F]{1,6}|[A-Za-z][\w]{1,31});/y;

function tokenizeHtml(src: string): Token[] {
  const out = new Out();
  const lower = src.toLowerCase();
  let i = 0;
  const n = src.length;
  while (i < n) {
    const c = src[i];
    if (c === "<") {
      if (src.startsWith("<!--", i)) {
        const end = src.indexOf("-->", i + 4);
        const j = end === -1 ? n : end + 3;
        out.push("comment", src.slice(i, j));
        i = j;
        continue;
      }
      if (src[i + 1] === "!" || src[i + 1] === "?") {
        const end = src.indexOf(">", i);
        const j = end === -1 ? n : end + 1;
        out.push("tag", src.slice(i, j));
        i = j;
        continue;
      }
      let j = i + 1;
      const closing = src[j] === "/";
      if (closing) j++;
      const name = stickyMatch(HTML_TAG_NAME, src, j);
      if (!name) {
        out.push("text", "<");
        i++;
        continue;
      }
      out.push("punct", src.slice(i, j));
      out.push("tag", name);
      j += name.length;
      let expectValue = false;
      while (j < n && src[j] !== ">") {
        const d = src[j];
        let m: string | null;
        if ((m = stickyMatch(WS, src, j))) {
          out.push("plain", m);
          j += m.length;
          continue;
        }
        if (d === "/") {
          out.push("punct", d);
          j++;
          continue;
        }
        if (d === "=") {
          out.push("punct", d);
          expectValue = true;
          j++;
          continue;
        }
        if (d === '"' || d === "'") {
          const end = src.indexOf(d, j + 1);
          const k = end === -1 ? n : end + 1;
          out.push("string", src.slice(j, k));
          expectValue = false;
          j = k;
          continue;
        }
        m = stickyMatch(HTML_ATTR_NAME, src, j) ?? d;
        out.push(expectValue ? "string" : "attr", m);
        expectValue = false;
        j += m.length;
      }
      if (j < n) {
        out.push("punct", ">");
        j++;
      }
      i = j;
      const tag = name.toLowerCase();
      if (!closing && (tag === "script" || tag === "style") && src[j - 2] !== "/") {
        const close = lower.indexOf(`</${tag}`, i);
        const end = close === -1 ? n : close;
        const inner = src.slice(i, end);
        if (tag === "script") tokenizeJs(inner, out);
        else tokenizeCss(inner, out);
        i = end;
      }
      continue;
    }
    if (c === "&") {
      const m = stickyMatch(HTML_ENTITY, src, i);
      if (m) {
        out.push("entity", m);
        i += m.length;
        continue;
      }
    }
    let k = i + 1;
    while (k < n && src[k] !== "<" && src[k] !== "&") k++;
    out.push("text", src.slice(i, k));
    i = k;
  }
  return out.tokens;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/** Tokenizes a whole source file. Tokens may contain newlines. */
export function tokenize(code: string, language: CodeLanguage): Token[] {
  if (!code) return [];
  try {
    if (language === "cpp") return tokenizeCpp(code);
    if (language === "python") return tokenizePython(code);
    return tokenizeHtml(code);
  } catch {
    return [{ kind: "plain", text: code }];
  }
}

/** Tokenizes and splits into lines (one token array per source line). */
export function tokenizeLines(code: string, language: CodeLanguage): Token[][] {
  const lines: Token[][] = [[]];
  for (const tok of tokenize(code.replace(/\r\n?/g, "\n"), language)) {
    const parts = tok.text.split("\n");
    for (let p = 0; p < parts.length; p++) {
      if (p > 0) lines.push([]);
      if (parts[p]) lines[lines.length - 1].push({ kind: tok.kind, text: parts[p] });
    }
  }
  return lines;
}

/** Plain lines without highlighting, for very large files. */
export function plainLines(code: string): Token[][] {
  return code
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((text) => (text ? [{ kind: "plain" as const, text }] : []));
}

/** Two token lines render identically. Used to memoize line rendering. */
export function sameTokens(a: Token[], b: Token[]): boolean {
  if (a === b) return true;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i].kind !== b[i].kind || a[i].text !== b[i].text) return false;
  }
  return true;
}

export const LANGUAGE_LABEL: Record<CodeLanguage, string> = { html: "HTML", cpp: "C++", python: "Python" };

/** Dot color for the filename tab. */
export const LANGUAGE_DOT: Record<CodeLanguage, string> = { html: "#f0abfc", cpp: "#a78bfa", python: "#67e8f9" };
