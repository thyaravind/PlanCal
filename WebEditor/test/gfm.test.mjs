import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { GFM, parser } from "@lezer/markdown";

const gfmParser = parser.configure([GFM]);

test("recognizes the GFM structures Plancal exposes", () => {
  const markdown = [
    "### Heading",
    "",
    "> Quote",
    "",
    "- [ ] Task",
    "",
    "~~done~~ and **important**",
    "",
    "```swift",
    "let value = 1",
    "```"
  ].join("\n");

  const tree = gfmParser.parse(markdown).toString();
  assert.match(tree, /ATXHeading3\(HeaderMark\)/);
  assert.match(tree, /Blockquote\(QuoteMark/);
  assert.match(tree, /Task\(TaskMarker\)/);
  assert.match(tree, /Strikethrough\(StrikethroughMark/);
  assert.match(tree, /StrongEmphasis\(EmphasisMark/);
  assert.match(tree, /FencedCode\(CodeMark,CodeInfo,CodeText,CodeMark\)/);
});

test("ships a self-contained editor resource", async () => {
  const resourceURL = new URL("../../Plancal/Resources/MarkdownEditor.html", import.meta.url);
  const html = await readFile(resourceURL, "utf8");

  assert.match(html, /plancalEditor/);
  assert.match(html, /markdownChanged/);
  assert.doesNotMatch(html, /<script[^>]+src=["']https?:\/\//i);
});
