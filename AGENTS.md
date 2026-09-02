# AGENTS.md

## What this project is

Erbele is a feature-rich text editor for macOS, built on AppKit: a document editor with
a project window, syntax highlighting for many languages and a large set of text tools.
It carries a long lineage — Smultron → Fraise → Erbele — and most of its behaviour is
accumulated over twenty years rather than freshly designed.

## Language and stack

* **Objective-C** is the bulk of the codebase: 56 `.m` files, roughly 14,900 lines under
  `Sources/`. This is where nearly all the application logic lives.
* **Swift 5** covers newer additions: 7 files, roughly 400 lines.
* AppKit, Core Data and TextKit 1. ARC is enabled throughout.
* No external dependencies and no package manager. `PSMTabBar/` and `ICU/` are vendored
  third-party code and live under `Vendor/` — do not edit them.
* Built with Xcode from `Erbele.xcodeproj`. Deployment target is macOS 10.13; the product
  is a universal binary (Intel and Apple Silicon).

## Repository layout

| Directory | Contents |
| --- | --- |
| `Sources/` | Application code: `Classes/`, `TextView/`, `LineNumbers/` |
| `Vendor/` | Vendored third-party code: `PSMTabBar/`, `ICU/` |
| `Resources/` | Interface files, graphics, syntax definitions, translations |
| `Docs/` | Manual and screenshots |
| `Other/` | Core Data model, default commands and snippets, scripting definition |

## Repository language

**English is the official language of this repository.** Every comment must be written in
English, without exception. The same goes for commit messages, documentation, identifiers,
branch names and issues.

This holds regardless of the language being used in conversation: a discussion held in
Spanish still produces English code, English comments and English commit messages.
