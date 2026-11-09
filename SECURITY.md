# Security

## Report a vulnerability

Do not open a public issue. Use **Report a vulnerability** under the *Security* tab of this repo (private message). You will get an answer as soon as the owner can. This is a hobby project with no guaranteed response time.

## What you give up by installing

Bindy is not ordinary software: to draw over the Start menu it needs **UI access** (`uiAccess`). Windows then requires the program to be signed and to live in a folder ordinary users cannot write to. The installer therefore does the following, as administrator:

1. Makes a self-signed code-signing certificate (`CN=Bindy local signing`) and signs `BindyStart.exe`.
2. Puts the certificate in the machine's **Root** and **TrustedPublisher** stores. Anything signed with that key is then trusted on the machine.
3. **Deletes the certificate and the private key** (`Remove-Item -DeleteKey`) right after signing, also on failure, so nobody can sign anything else with it. The key is made non-exportable and only lives while the script runs.
4. Copies the sources to `C:\Program Files\Bindy\staging` (only an administrator can write there), builds and shows the SHA-256 from there, and signs and copies **the same copy** to `C:\Program Files\Bindy\`. No ordinary process can swap the files between the hash display and the signing. Still compare the `bindy.ps1` sum with the one on the release page.

This means:

- The process can control windows that run as administrator and draw over everything. Malicious code already running as you could try to abuse that.
- You must trust the code in the release you install. **Read `src/bindy.ps1` and `host/BindyHost.cs` first.** They are short enough to read.
- `scripts\uninstall.ps1` removes everything, including the certificates.

## What Bindy does not do

- No network calls other than the ones `claude` itself makes. Bindy has no server and no telemetry of its own.
- No keys are recorded. During guidance only *where* and *when* you click with the left mouse button is read, and only whether the click hit the marked target (yes/no) is sent to Claude, not the position.
- Bindy never writes screenshots to disk. It also asks Claude Code not to store the session (`--no-session-persistence`).
- Claude gets **no tools** (`--tools ""`: no files, no web, no command line) and reads no settings or hooks from folders (`--setting-sources ""`). Bindy only starts an **executable** `claude` (never `.cmd` or `.ps1`) and removes `NODE_OPTIONS` from its environment.
- Bindy never pastes anything unless you press "Paste", and refuses to paste into password and banking windows.

## Claude Code as a client (MCP, off by default)

With **Let Claude Code use Bindy (MCP)** on in Settings, Bindy listens on `127.0.0.1:47831/mcp` (never `0.0.0.0`, LAN or Funnel). Every request must come from the local machine, have the right `Host`, **no** `Origin` header, `Content-Type: application/json`, at most 16 KB and `Authorization: Bearer <token>`. The token is 32 random bytes stored with DPAPI in `bindy-mcp-token.bin` and compared in constant time; **New MCP token** in the tray menu replaces it. One request at a time. Tools: `bindy_status` (running, paused, guiding; no screen content) and `bindy_se` (screenshot of all screens or the active window). `bindy_se` shows a small window at the top of the screen, "Claude Code wants to see ... (reason)", and only takes the picture after you click **Share**: **one click per image**, no "remember", no keyboard (the window never takes focus and the buttons arm after 0.7 s so a stray click or Enter cannot approve), no answer in 30 s counts as declined, and pausing counts as declined. The reason text comes from Claude and is shown as plain text (control and direction characters removed, max 120 characters), so it can be misleading: judge by what you see. The block list is checked before asking (a blocked window gives a refusal without a prompt) and again when the picture is taken. The reply is marked as data, not instructions. `bindy_pek` draws a frame and/or the binder pointer from an image id and coordinates in image pixels (no click needed, it only draws; unknown or older than 5 minutes, or out-of-range coordinates, are refused; the label is cleaned like the reason). It fades after 30 s, or you remove it with Pause or Stop in the tray menu. It is refused while a guidance is running. `bindy_veiled` asks "Claude Code wants Bindy to guide you (screenshots go to Claude)" with the goal (max 160 characters, shown in full) and starts a guidance only after you click **Start** (same rules as Share: one click, no keyboard, 30 s timeout, block list checked first, refused while paused or while a guidance runs). The optional context (max 1000 characters) is passed to the guide without being shown. It replaces `bindy-start.txt`, which is **deprecated** (still works if its Settings option is on, but it starts without asking: prefer MCP). Bindy remembers only scale and offset per image id (max 10, 5 min), never the image, and never clicks, types or pastes for Claude. The log `bindy-sist.log` holds only time, machine, tool and outcome. Any program running as you can ask DPAPI for the token, so it adds no protection against code already running as you.

## Known limitations

- **The block list** for passwords and banking is title and process-name matching. It lets a lot through. It is not a guarantee.
- **Prompt injection through MCP:** a screenshot you share with a Claude Code session goes to *that* session, which may have tools (files, shell, network). Text on the screen can try to steer it. Only share when you trust the session and the reason, and keep the screen free of secrets. The tray icon turns red while a picture is taken.
- **Prompt injection:** text on the screen may try to steer Claude. The worst outcome is a misleading arrow or text. Claude has no tools to abuse, but you must judge what it suggests.
- **UI access** lowers the boundary between ordinary and administrator windows for this one process (see above).
- **Code already running as you** can try to get its own code into the Bindy process without touching `Program Files`: PowerShell compiles some helper classes (`Add-Type`) to `%TEMP%` at startup, and environment variables and `HKCU` are controlled by the user (for example `COR_PROFILER`). The launcher cleans `PSModulePath`, but this is not fully closed. It is a reason to only run Bindy on a machine you trust.
- Bindy does not copy links automatically. Text Claude suggests is only pasted when you press "Paste", and never into administrator windows, password or banking windows.
- **Claude can trigger "all screens":** if text on the screen makes Claude ask to see more, Bindy captures all screens without a new confirmation (the block list still applies). This only applies to questions you ask yourself; the automatic checks during guidance cannot trigger it. During guidance new screenshots are also sent automatically, also when you switch window.
- **Another program can start a guidance (off by default):** if "Let Claude Code start guidance" is on in Settings, any program running as you can write text to `%LOCALAPPDATA%\Bindy\bindy-start.txt`. Bindy then deletes the file, captures all screens and starts a guidance with that text as the goal, so the screenshot and the text are sent to Anthropic through your Claude login. Files older than 2 minutes are ignored, and nothing happens while Bindy is paused. Code already running as you can take screenshots itself, so the gain is small, but leave the setting off if you do not use it.
- **Settings files can be written by code running as you:** `bindy-del-utklipp`, `bindy-musefolger-av`, `bindy-settings.json` and `bindy-oppgave.md` in `%LOCALAPPDATA%\Bindy`. Code already running as you could therefore turn on clipboard sharing, change the hotkeys or put text into what Claude gets to see. It can already take screenshots itself, so the gain is small, but you should know. The settings file is validated when read (language and hotkeys only accept known values).
- The input box that appears beside the binder takes keyboard focus when you press the hotkey. If you press it in the middle of a password field, the rest of your keystrokes end up there.
- Bindy has not been audited by an independent party.

## Recommended use

Only run it on a machine you own. Do not install a release whose checksum you have not checked. Do not let it look at windows with secret content: press **Ctrl+Alt+P** (pause) first.
