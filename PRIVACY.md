# Privacy

Bindy collects nothing itself, has no account and no server. But it does send content to Anthropic through your own Claude Code login. Here is exactly what.

## What is sent to Anthropic

| When | What is sent | Note |
|---|---|---|
| Ctrl+Alt+H and during guidance | Screenshot of the active window (max 1280 px wide) or all screens (max 2000 px) | Captured when you press the hotkey, when "Screen" is on, and **automatically during a guidance you have started**: on click, when the screen changes (also without a click, and also when you switch to another window), and when you have stood still for over 30 s (max 30 images, stops after 5 min without activity). **Claude can also ask to see all screens** when you ask a question, and Bindy then takes the picture without a new confirmation (not from the automatic checks). The block list still applies |
| When Claude Code starts a guidance (Settings option, off by default) | Screenshot of **all screens** and the text Claude Code wrote to `bindy-start.txt` (max 3000 characters, may contain context from your terminal conversation) | Shown as a short message when it starts |
| During guidance | A short note on whether you clicked **inside** or **outside** the marked target, or that no click was registered | Only yes/no, never coordinates or which app |
| Always | What you type, and the latest questions and answers (max 6, forgotten after 10 min) | |
| Always | The task note (`bindy-oppgave.md`, max 3000 characters), if it exists | Stored locally, see below |
| **Only if you turn on "Share clips with Claude"** | The 6 latest copies, each max 200 characters | **Off by default** |

What Anthropic does with the data is decided by your Claude account and Anthropic's own terms and privacy policy. Bindy cannot control that.

## What is never captured

- Windows with password or banking in the title, and password managers, are not captured. "All screens" is refused when such a window is visible. **This is a simple title check and not a guarantee.**
- Copies marked private by password managers (`ExcludeClipboardContentFromMonitorProcessing`) are not stored.

## What is stored on your machine

Everything is in `%LOCALAPPDATA%\Bindy\`:

| File | Contents |
|---|---|
| `bindy-oppgave.md` | Current goal and progress, in plain text. **Contains Claude's step text, which may refer to what was on the screen** |
| `bindy-oppgave.forrige.md` | Archived copy of the previous task |
| `bindy-settings.json` | Language, hotkeys and whether Claude Code may start guidance |
| `bindy-feil.log` | Error messages (may contain text from Claude), cut at 100 kB |
| `bindy-host-feil.log` | Errors from the launcher (`BindyStart.exe`), rare |
| `bindy-start.txt` | Only exists for a moment: a request to start guidance, deleted as soon as Bindy reads it |
| `bindy-del-utklipp` | Empty file: if it exists, sharing clips is on |
| `bindy-musefolger-av` | Empty file: if it exists, the mouse follower (paperclip by the mouse pointer) is switched off |

**Bindy never writes screenshots to disk.** They only live in memory until they have been sent, and Bindy asks Claude Code not to store the session (`--no-session-persistence`).
The clipboard history (max 8, max 400 characters, deleted after 60 min) only lives in memory.

## Delete everything

`scripts\uninstall.ps1` removes the program and the folder above. Or delete `%LOCALAPPDATA%\Bindy` by hand.
