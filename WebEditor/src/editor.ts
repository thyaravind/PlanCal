import { markdown } from "@codemirror/lang-markdown";
import { defaultHighlightStyle, syntaxHighlighting, syntaxTree } from "@codemirror/language";
import { Compartment, EditorSelection, EditorState } from "@codemirror/state";
import {
  Decoration,
  type DecorationSet,
  EditorView,
  keymap,
  placeholder,
  ViewPlugin,
  type ViewUpdate,
  WidgetType
} from "@codemirror/view";
import { GFM } from "@lezer/markdown";
import { basicSetup } from "codemirror";

type EditorCommand = {
  name: string;
  value?: string | number | boolean;
};

type NativeMessageHandler = {
  postMessage(message: unknown): void;
};

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: Record<string, NativeMessageHandler>;
    };
    plancalEditor?: {
      setContent(content: string): void;
      getContent(): string;
      setPlaceholder(value: string): void;
      setTheme(theme: "light" | "dark"): void;
      command(command: EditorCommand): void;
      focus(): void;
    };
  }
}

const placeholderCompartment = new Compartment();

function postToNative(name: string, message: unknown): void {
  window.webkit?.messageHandlers?.[name]?.postMessage(message);
}

class TaskCheckboxWidget extends WidgetType {
  constructor(
    private readonly checked: boolean,
    private readonly from: number,
    private readonly to: number,
    private readonly bullet: string
  ) {
    super();
  }

  eq(other: TaskCheckboxWidget): boolean {
    return this.checked === other.checked &&
      this.from === other.from &&
      this.to === other.to &&
      this.bullet === other.bullet;
  }

  toDOM(view: EditorView): HTMLElement {
    const wrapper = document.createElement("span");
    wrapper.className = "plancal-task-widget";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = this.checked;
    checkbox.setAttribute("aria-label", this.checked ? "Mark task incomplete" : "Mark task complete");
    checkbox.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      const replacement = `${this.bullet} [${this.checked ? " " : "x"}] `;
      view.dispatch({
        changes: { from: this.from, to: this.to, insert: replacement },
        userEvent: "input.complete-task"
      });
      view.focus();
    });

    wrapper.appendChild(checkbox);
    return wrapper;
  }

  ignoreEvent(): boolean {
    return true;
  }
}

function markdownDecorations(view: EditorView): DecorationSet {
  const decorations: Array<ReturnType<Decoration["range"]>> = [];
  const activeLines = new Set<number>();
  const mainSelection = view.state.selection.main;
  const firstActiveLine = view.state.doc.lineAt(mainSelection.from).number;
  const lastActiveLine = view.state.doc.lineAt(mainSelection.to).number;

  for (let lineNumber = firstActiveLine; lineNumber <= lastActiveLine; lineNumber += 1) {
    activeLines.add(view.state.doc.line(lineNumber).from);
  }

  const taskRanges: Array<{ from: number; to: number }> = [];
  for (let lineNumber = 1; lineNumber <= view.state.doc.lines; lineNumber += 1) {
    const line = view.state.doc.line(lineNumber);
    const match = /^(\s*)([-+*])\s+\[([ xX])\]\s?/.exec(line.text);
    if (!match) continue;

    const from = line.from + match[1].length;
    const to = line.from + match[0].length;
    taskRanges.push({ from, to });
    decorations.push(
      Decoration.replace({
        widget: new TaskCheckboxWidget(match[3].toLowerCase() === "x", from, to, match[2]),
        inclusive: false
      }).range(from, to)
    );
  }

  const lineClasses = new Map<number, Set<string>>();
  const addLineClass = (position: number, className: string): void => {
    const line = view.state.doc.lineAt(Math.min(position, view.state.doc.length));
    const classes = lineClasses.get(line.from) ?? new Set<string>();
    classes.add(className);
    lineClasses.set(line.from, classes);
  };

  const intersectsTaskWidget = (from: number, to: number): boolean =>
    taskRanges.some((range) => from < range.to && to > range.from);

  syntaxTree(view.state).iterate({
    enter(node) {
      const name = node.type.name;

      const headingMatch = /^ATXHeading([1-6])$/.exec(name);
      if (headingMatch) {
        addLineClass(node.from, `cm-md-heading-${headingMatch[1]}`);
      } else if (name === "Blockquote") {
        const startLine = view.state.doc.lineAt(node.from).number;
        const endLine = view.state.doc.lineAt(Math.max(node.from, node.to - 1)).number;
        for (let number = startLine; number <= endLine; number += 1) {
          addLineClass(view.state.doc.line(number).from, "cm-md-quote-line");
        }
      } else if (name === "FencedCode") {
        const startLine = view.state.doc.lineAt(node.from).number;
        const endLine = view.state.doc.lineAt(Math.max(node.from, node.to - 1)).number;
        for (let number = startLine; number <= endLine; number += 1) {
          addLineClass(view.state.doc.line(number).from, "cm-md-code-line");
        }
      } else if (name === "StrongEmphasis") {
        decorations.push(Decoration.mark({ class: "cm-md-strong" }).range(node.from, node.to));
      } else if (name === "Emphasis") {
        decorations.push(Decoration.mark({ class: "cm-md-emphasis" }).range(node.from, node.to));
      } else if (name === "Strikethrough") {
        decorations.push(Decoration.mark({ class: "cm-md-strike" }).range(node.from, node.to));
      } else if (name === "InlineCode") {
        decorations.push(Decoration.mark({ class: "cm-md-inline-code" }).range(node.from, node.to));
      } else if (name === "Link") {
        decorations.push(Decoration.mark({ class: "cm-md-link" }).range(node.from, node.to));
      }

      const markerNames = new Set([
        "HeaderMark",
        "EmphasisMark",
        "CodeMark",
        "QuoteMark",
        "ListMark",
        "LinkMark",
        "StrikethroughMark"
      ]);
      const line = view.state.doc.lineAt(node.from);
      if (
        markerNames.has(name) &&
        !activeLines.has(line.from) &&
        node.to > node.from &&
        !intersectsTaskWidget(node.from, node.to)
      ) {
        decorations.push(Decoration.replace({}).range(node.from, node.to));
      }

      if (
        (name === "URL" || name === "LinkTitle") &&
        !activeLines.has(line.from) &&
        line.text.includes("](") &&
        node.to > node.from
      ) {
        decorations.push(Decoration.replace({}).range(node.from, node.to));
      }
    }
  });

  for (const [from, classes] of lineClasses) {
    decorations.push(Decoration.line({ class: [...classes].join(" ") }).range(from));
  }

  return Decoration.set(decorations, true);
}

const liveMarkdownDecorations = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = markdownDecorations(view);
    }

    update(update: ViewUpdate): void {
      if (update.docChanged || update.selectionSet || update.viewportChanged) {
        this.decorations = markdownDecorations(update.view);
      }
    }
  },
  {
    decorations: (value) => value.decorations
  }
);

function replaceSelection(open: string, close = open): boolean {
  const state = editor.state;
  const selection = state.selection.main;
  const selectedText = state.sliceDoc(selection.from, selection.to);
  const beforeFrom = Math.max(0, selection.from - open.length);
  const afterTo = Math.min(state.doc.length, selection.to + close.length);
  const hasOuterMarkers =
    state.sliceDoc(beforeFrom, selection.from) === open &&
    state.sliceDoc(selection.to, afterTo) === close;

  if (hasOuterMarkers) {
    editor.dispatch({
      changes: [
        { from: beforeFrom, to: selection.from, insert: "" },
        { from: selection.to, to: afterTo, insert: "" }
      ],
      selection: EditorSelection.range(beforeFrom, selection.to - open.length),
      userEvent: "input.format"
    });
  } else {
    const replacement = `${open}${selectedText}${close}`;
    const anchor = selection.from + open.length;
    editor.dispatch({
      changes: { from: selection.from, to: selection.to, insert: replacement },
      selection: EditorSelection.range(anchor, anchor + selectedText.length),
      userEvent: "input.format"
    });
  }
  editor.focus();
  return true;
}

function setLinePrefix(pattern: RegExp, prefix: string): boolean {
  const state = editor.state;
  const selection = state.selection.main;
  const line = state.doc.lineAt(selection.head);
  const match = pattern.exec(line.text);
  const existingPrefixLength = match?.[0].length ?? 0;
  const replacement = match?.[0] === prefix ? "" : prefix;
  const cursorOffset = Math.max(0, selection.head - line.from - existingPrefixLength);

  editor.dispatch({
    changes: { from: line.from, to: line.from + existingPrefixLength, insert: replacement },
    selection: EditorSelection.cursor(line.from + replacement.length + cursorOffset),
    userEvent: "input.format.block"
  });
  editor.focus();
  return true;
}

function insertLink(url: string): void {
  const selection = editor.state.selection.main;
  const selectedText = editor.state.sliceDoc(selection.from, selection.to) || "link";
  const replacement = `[${selectedText}](${url})`;
  editor.dispatch({
    changes: { from: selection.from, to: selection.to, insert: replacement },
    selection: EditorSelection.range(selection.from + 1, selection.from + 1 + selectedText.length),
    userEvent: "input.format.link"
  });
  editor.focus();
}

function titleCase(value: string): string {
  return value
    .toLocaleLowerCase()
    .replace(/(^|[^\p{L}\p{N}])(\p{L})/gu, (_match, boundary: string, letter: string) =>
      boundary + letter.toLocaleUpperCase()
    );
}

function changeCase(value: string): void {
  const selection = editor.state.selection.main;
  if (selection.empty) {
    editor.focus();
    return;
  }

  const selectedText = editor.state.sliceDoc(selection.from, selection.to);
  const replacement = (() => {
    switch (value) {
      case "lowercase":
        return selectedText.toLocaleLowerCase();
      case "uppercase":
        return selectedText.toLocaleUpperCase();
      case "title":
        return titleCase(selectedText);
      default:
        return selectedText;
    }
  })();

  if (replacement !== selectedText) {
    editor.dispatch({
      changes: { from: selection.from, to: selection.to, insert: replacement },
      selection: EditorSelection.range(selection.from, selection.from + replacement.length),
      userEvent: "input.format.case"
    });
  }
  editor.focus();
}

function executeCommand(command: EditorCommand): void {
  switch (command.name) {
    case "bold":
      replaceSelection("**");
      break;
    case "italic":
      replaceSelection("_");
      break;
    case "strikethrough":
      replaceSelection("~~");
      break;
    case "inlineCode":
      replaceSelection("`");
      break;
    case "heading": {
      const level = Math.min(6, Math.max(0, Number(command.value ?? 0)));
      setLinePrefix(/^#{1,6}\s+/, level === 0 ? "" : `${"#".repeat(level)} `);
      break;
    }
    case "bulletList":
      setLinePrefix(/^\s*[-+*]\s+(?!\[[ xX]\])/, "- ");
      break;
    case "orderedList":
      setLinePrefix(/^\s*\d+[.)]\s+/, "1. ");
      break;
    case "taskList":
      setLinePrefix(/^\s*[-+*]\s+\[[ xX]\]\s+/, "- [ ] ");
      break;
    case "blockquote":
      setLinePrefix(/^\s*>\s+/, "> ");
      break;
    case "codeBlock":
      replaceSelection("```\n", "\n```");
      break;
    case "link":
      insertLink(String(command.value ?? ""));
      break;
    case "changeCase":
      changeCase(String(command.value ?? ""));
      break;
    case "focus":
      editor.focus();
      break;
  }
}

const editorElement = document.getElementById("editor");
if (!editorElement) throw new Error("Missing editor host element");

const editor = new EditorView({
  parent: editorElement,
  state: EditorState.create({
    doc: "",
    extensions: [
      basicSetup,
      markdown({ extensions: [GFM] }),
      syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
      EditorView.lineWrapping,
      EditorView.contentAttributes.of({
        "aria-label": "Markdown note",
        autocapitalize: "sentences",
        autocorrect: "on",
        spellcheck: "true"
      }),
      keymap.of([
        { key: "Mod-b", run: () => replaceSelection("**") },
        { key: "Mod-i", run: () => replaceSelection("_") },
        { key: "Mod-Shift-s", run: () => replaceSelection("~~") },
        { key: "Mod-e", run: () => replaceSelection("`") },
        { key: "Mod-k", run: () => { postToNative("requestLink", null); return true; } }
      ]),
      placeholderCompartment.of(placeholder("Write a note…")),
      liveMarkdownDecorations,
      EditorView.updateListener.of((update) => {
        if (update.docChanged) {
          postToNative("markdownChanged", update.state.doc.toString());
        }
        if (update.focusChanged) {
          postToNative("focusChanged", update.view.hasFocus);
        }
      })
    ]
  })
});

window.plancalEditor = {
  setContent(content: string): void {
    const current = editor.state.doc.toString();
    if (current === content) return;
    editor.dispatch({ changes: { from: 0, to: editor.state.doc.length, insert: content } });
  },

  getContent(): string {
    return editor.state.doc.toString();
  },

  setPlaceholder(value: string): void {
    editor.dispatch({ effects: placeholderCompartment.reconfigure(placeholder(value)) });
  },

  setTheme(theme: "light" | "dark"): void {
    document.documentElement.dataset.theme = theme;
  },

  command(command: EditorCommand): void {
    executeCommand(command);
  },

  focus(): void {
    editor.focus();
  }
};

postToNative("editorReady", null);
