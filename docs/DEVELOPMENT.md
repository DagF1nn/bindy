# Development

## Setup

- Windows 10 (2004+) or 11, Windows PowerShell 5.1, git.
- Claude Code installed and signed in (see [INSTALL.md](INSTALL.md)) to try the real thing.
- No SDK needed: the launcher is built with `csc.exe`, which ships with Windows (`scripts\build.ps1`).

## Structure

| Path | What |
|---|---|
| `src/bindy.ps1` | The whole program (WinForms, drawing, parsing of Claude answers, guidance, settings) |
| `host/BindyHost.cs`, `host/app.manifest`, `host/bindy.ico` | Signed launcher: runs `bindy.ps1` inside itself with `uiAccess` |
| `scripts/` | `build.ps1`, `install.ps1`, `uninstall.ps1`, `make-icon.ps1` (updating = run `install.ps1` again) |

## Run and test

```powershell
powershell -STA -File src\bindy.ps1 -Sjekk     # self-check: parsing, clipboard, placement, drawing (sends nothing)
powershell -STA -File src\bindy.ps1            # run without UI access (the drawing ends up behind the Start menu)
```

Testing the real installation needs administrator rights and changes the machine (certificate, `C:\Program Files\Bindy`). Do it on a machine you own, and run `scripts\uninstall.ps1` afterwards.

## Text and languages

User-visible text is written in English in the code and wrapped as `(L 'English text')`. The Norwegian translation lives in the `$script:NO` dictionary at the top of `src/bindy.ps1` (English text as the key). Add a new string in both places. Texts sent to Claude are English and end with a "Reply in …" instruction taken from the language setting. Note: C# class names in `Add-Type` must be ASCII.

## The MCP server

`src/bindy.ps1` has a small MCP server (Streamable HTTP, JSON-RPC over POST, stateless) in the block "MCP: Claude Code kan bruke Bindy som verktøy". A C# class (`McpServer`, `McpGuard`) does the network part (loopback only, Host/Origin/token/size checks) and puts requests in a queue; PowerShell reads the queue on the UI thread (`Mcp-Behandle`, called from the main clock) so all UI and capture happens there. Tools: `bindy_status`, `bindy_se`, `bindy_pek`, `bindy_veiled` (see `Mcp-Rpc`). Approval is `Mcp-Spør` (a non-activating window, one click, 30 s timeout).

Rules for changes: everything in a request is untrusted (validate types, lengths and numbers, and add a case to `-Sjekk`); never add an MCP tool that clicks, types or pastes without a per-use click from the user (only `bindy_superguide` does, and only through `SgUtforer`); never write screenshots to disk; the block list must be checked before asking and again when capturing; keep the log to time, tool, machine and outcome.

## Letting Claude Code start a guidance (deprecated: use the MCP tool `bindy_veiled`)

Prefer the MCP tool `bindy_veiled`, which asks you first (see SECURITY.md). The file route below is kept for one version. With "Let Claude Code start guidance" on in Settings, a program (typically Claude Code in a terminal) starts guidance by writing the goal, plus any useful context, to `%LOCALAPPDATA%\Bindy\bindy-start.txt` (UTF-8, max 3000 characters):

```powershell
[IO.File]::WriteAllText("$env:LOCALAPPDATA\Bindy\bindy-start.txt", "Goal: show where to update drivers in Device Manager. Context: Windows 11, Norwegian UI.")
```

Bindy picks the file up within about a second, deletes it, captures all screens and starts the guidance. Write the file only when the user has asked to be guided.

## Rules for changes

- **The program runs with UI access.** Read every change line by line. No `Invoke-Expression`, no downloading code, no new dependencies without a good reason.
- Everything Claude answers with is **untrusted input**: validate, limit lengths and numbers (see `Del-Svar`) and add a test in `-Sjekk`.
- Claude gets no tools in the calls (`--tools ""`). Do not change that without writing why in `SECURITY.md`.
- Bindy never writes screenshots to disk. Never log content you type or see. Note: `bindy-oppgave.md` contains Claude's step text, which may come from the screen.
- Settings files are writable by code running as you: validate everything read from `bindy-settings.json` (see `Les-Innst`).
- Keep `PRIVACY.md` and `SECURITY.md` in step with the code in the same PR.

## Releasing

See [PUBLISH-ON-GITHUB.md](PUBLISH-ON-GITHUB.md), part 5.
