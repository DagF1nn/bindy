# Bindy

A helper on your screen for Windows. Press a hotkey, ask a question, and Bindy (a small paperclip in an "island" at the top of the screen) answers with Claude, based on what you see. During **guidance** it draws a frame and points at the one thing you should click, one step at a time, and checks along the way that you got it right.

> **Status: 0.x, under development.** The interface is in English by default; Norwegian is available in Settings.

## What it does

- **Ctrl+Alt+H**: ask with a screenshot of the window you are in. **Ctrl+Alt+J**: ask without the screen. All hotkeys can be changed in **Settings** (the gear in the panel, or the tray menu).
- **Guidance** (Ctrl+Enter or "Guide me"): one step at a time, a frame and a paperclip pointer on the target. If you stand still, it explains more simply. **Ctrl+Alt+N** (or the "Next step" button) moves on.
- **Eyes for Claude Code (MCP):** Bindy can be an MCP server on your own PC, so a Claude Code session can look at your screen, point at things and start a guidance for you. **Off by default** (Settings: "Let Claude Code use Bindy (MCP)"). Every screenshot and every guidance needs **one click from you** (Share / Start); nothing is ever clicked or typed for you. See [docs/INSTALL.md](docs/INSTALL.md#optional-let-claude-code-use-bindy-mcp) and [SECURITY.md](SECURITY.md).
- **Choice buttons:** if Claude has to ask something, you get buttons to press instead of typing.
- **Draws over everything**, including the Start menu and the taskbar.
- **Clipboard history** (in memory only) that can be pasted with one click.
- **Languages:** English (default) and Norwegian.
- No account and no API key of its own: it uses **your** Claude Code login.

## How it works

```
hotkey -> screenshot (in memory) -> `claude -p` (your login) -> answer + drawing codes -> frame/pointer/buttons
```

Bindy is one PowerShell script (`src/bindy.ps1`) that runs inside a small signed C# launcher (`host/`). The launcher is only needed so the drawing can sit above the Start menu (`uiAccess`).

## Install

See **[docs/INSTALL.md](docs/INSTALL.md)** (about 15 minutes). In short: install Claude Code, sign in, and run `scripts\install.ps1` as administrator.

## Before you install: read this

1. **Screenshots and text are sent to Anthropic.** The active window (or all screens), what you type, and optionally clipboard items (if you turn sharing on) go through your own `claude` login and count against your quota. If you turn on MCP, a screenshot you share goes to the Claude Code session that asked, which sends it on. See [PRIVACY.md](PRIVACY.md).
2. **Installation needs administrator rights.** It makes a self-signed certificate trusted on the machine and gives one executable UI access. That lowers a security boundary in Windows. See [SECURITY.md](SECURITY.md) and read the code first.
3. **The block list for passwords and banking is a simple title check**, not a guarantee. Do not use Bindy with a screen full of things you do not want to send.
4. **Claude can be wrong.** Arrows and text can point the wrong way. Bindy never pastes anything unless you press "Paste".

## Requirements

Windows 10 (2004+) or 11, Windows PowerShell 5.1, Claude Code and a Claude account (Pro, Max, Team, Enterprise or Console).

## Build it yourself

```powershell
powershell -File scripts\build.ps1               # only needs csc.exe, which ships with Windows
powershell -STA -File src\bindy.ps1 -Sjekk       # self-check, sends nothing
```

## Contribute and report

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). For vulnerabilities see [SECURITY.md](SECURITY.md); do not open a public issue.

## License

MIT, see [LICENSE](LICENSE).
