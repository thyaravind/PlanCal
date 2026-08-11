import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
import { chromium } from "playwright-core";

const chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const editorURL = pathToFileURL(
  new URL("../../Plancal/Resources/MarkdownEditor.html", import.meta.url).pathname
).href;

const browser = await chromium.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--allow-file-access-from-files"]
});

try {
  const page = await browser.newPage({ viewport: { width: 900, height: 620 } });
  page.on("pageerror", (error) => {
    console.error(`Editor page error: ${error.message}`);
  });
  await page.goto(editorURL);
  await page.waitForFunction(() => Boolean(window.plancalEditor));
  await page.evaluate(() => window.plancalEditor.setTheme("dark"));
  assert.equal(
    await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue("--editor-accent").trim()
    ),
    "rgb(105, 190, 255)"
  );

  const source = [
    "### Focus",
    "",
    "> Keep the important work visible.",
    "",
    "- [ ] Finish the weekly review",
    "- [x] Plan tomorrow",
    "",
    "Use **bold**, _italic_, ~~strike~~, `code`, and [links](https://example.com)."
  ].join("\n");

  await page.evaluate((markdown) => window.plancalEditor.setContent(markdown), source);
  assert.equal(await page.evaluate(() => window.plancalEditor.getContent()), source);

  const lines = page.locator(".cm-line");
  await lines.last().click();
  const heading = page.locator(".cm-md-heading-3");
  await heading.waitFor();
  assert.equal((await heading.innerText()).trim(), "Focus");

  const firstTask = page.locator(".plancal-task-widget input").first();
  await firstTask.click();
  assert.match(
    await page.evaluate(() => window.plancalEditor.getContent()),
    /- \[x\] Finish the weekly review/
  );

  await page.evaluate(() => window.plancalEditor.setContent("important"));
  await page.locator(".cm-content").click();
  await page.keyboard.press("Meta+A");
  await page.keyboard.press("Meta+B");
  assert.equal(await page.evaluate(() => window.plancalEditor.getContent()), "**important**");

  await page.evaluate(() => window.plancalEditor.setContent("mIXed cASE"));
  await page.locator(".cm-content").click();
  await page.keyboard.press("Meta+A");
  await page.evaluate(() => window.plancalEditor.command({ name: "changeCase", value: "title" }));
  assert.equal(await page.evaluate(() => window.plancalEditor.getContent()), "Mixed Case");
  await page.evaluate(() => window.plancalEditor.command({ name: "changeCase", value: "uppercase" }));
  assert.equal(await page.evaluate(() => window.plancalEditor.getContent()), "MIXED CASE");
  await page.evaluate(() => window.plancalEditor.command({ name: "changeCase", value: "lowercase" }));
  assert.equal(await page.evaluate(() => window.plancalEditor.getContent()), "mixed case");

  await page.evaluate((markdown) => window.plancalEditor.setContent(markdown), source);
  await lines.nth(1).click();
  const renderedInlineMarkdown = await lines.last().innerText();
  assert.doesNotMatch(renderedInlineMarkdown, /\*\*|_italic_|~~|`code`|https:\/\//);
  assert.match(renderedInlineMarkdown, /Use bold, italic, strike, code, and links\./);
  await page.screenshot({ path: "/tmp/Plancal-CodeMirror.png" });
} finally {
  await browser.close();
}
