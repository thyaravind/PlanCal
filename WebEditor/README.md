# Plancal Markdown editor

This directory contains Plancal's CodeMirror 6 editor source. Markdown remains
the canonical document format. Vite bundles the TypeScript, CodeMirror, and the
Lezer GFM parser into one local HTML resource consumed by `WKWebView` on iOS,
iPadOS, and macOS.

```sh
npm install
npm run check
npm test
npm run build
```

The build output is `../Plancal/Resources/MarkdownEditor.html`. It is committed
so Xcode builds do not require Node.js or network access.

CodeMirror and Lezer are distributed under the MIT license. Their package
license files are included in the npm dependency tree and their source projects
are linked from `package-lock.json`.
