# Security

## Report a vulnerability

Do not open a public issue. Use **Report a vulnerability** under the *Security* tab of this repo (private message). You will get an answer as soon as the owner can. This is a hobby project with no guaranteed response time.

## What you give up by installing

Bindy is not ordinary software: to draw over the Start menu it needs **UI access** (`uiAccess`). Windows then requires the program to be signed and to live in a folder ordinary users cannot write to. The installer therefore does the following, as administrator:

1. Makes a self-signed code-signing certificate (`CN=Bindy local signing`) and signs `BindyStart.exe`.
2. Puts the certificate in the machine's **Root** and **TrustedPublisher** stores. Anything signed with that key is then trusted on the machine.
3. **Deletes the certificate and the private key** (`Remove-Item -DeleteKey`) right after signing, also on failure, so nobody can sign anything else with it. The key is made non-exportable and only lives while the script runs.
4. Copies the sources to `C:\Program Files\Bindy\staging` (only an administrator can write there), builds and shows the SHA-256 from there, and signs and copies **the same copy** to `C:\Program Files\Bindy\`. No ordinary process can swap the files between the hash display and the signing. Read the source before you run the installer: there is no published checksum to compare with.

This means:

- The process can control windows that run as administrator and draw over everything. Malicious code already running as you could try to abuse that.
- You must trust the code in the release you install. **Read `src/bindy.ps1` and `host/BindyHost.cs` first.** They are short enough to read.
- `scripts\uninstall.ps1` removes everything, including the certificates.

## What Bindy does not do

- No network calls other than the ones `claude` itself makes. Bindy has no telemetry of its own, and no server unless you turn on MCP (then only a local one on `127.0.0.1`, see below).
- No keys are recorded. During guidance only *where* and *when* you click with the left mouse button is read, and only whether the click hit the marked target (yes/no) is sent to Claude, not the position.
- Bindy never writes screenshots to disk. It also asks Claude Code not to store the session (`--no-session-persistence`).
- Claude gets **no tools** (`--tools ""`: no files, no web, no command line) and reads no settings or hooks from folders (`--setting-sources ""`). Bindy only starts an **executable** `claude` (never `.cmd` or `.ps1`) and removes `NODE_OPTIONS` from its environment.
- Outside Superguide, Bindy never pastes anything unless you press "Paste", and refuses to paste into password and banking windows.

## Superguide: Bindy acts for you (off by default)

**In short:** with **Superguide** on in Settings (confirmation the first time), Bindy clicks, scrolls, types, presses hotkeys and opens apps by itself to reach a goal you give it. Start it from the tray menu, or Claude Code asks with `bindy_superguide` (your click every time). This is the riskiest feature in Bindy: a wrong guess or a prompt injection can become a real click.

- **Who decides:** Bindy's own Claude (no tools), from screenshots of **all screens** sent to Anthropic, one action per call, always a fresh screenshot after each action. Screen text is told to be data, but that is a request to the model, not a guarantee.
- **Hard limits in code, not in the prompt** (`host/Superguide.cs`, in the signed launcher; Claude's answer is parsed strictly, one `SG:` line, and every action passes one gate): refuses when the foreground window or process matches the block list (passwords, banking, password managers), when a password field is focused or targeted (checked with UI Automation **and** the Win32 password style), on UAC and the secure desktop, in terminals and regedit, and on buttons or windows about paying, deleting, formatting, uninstalling, sending or security settings (matched on window title, element name and process). Those need **you** to click. Max 40 steps, 5 minutes and 30 app launches per run, 120 Claude calls per hour, at least 300 ms between actions, nothing starts unless the gate was initialised. Typed text is never logged; `%LOCALAPPDATA%\Bindy\superguide.log` has time, action and result.
- **Stopping:** hold **Esc**, press Pause, choose Stop in the tray menu, or touch the mouse or keyboard: the run ends (tested to stop within about a second). The tray icon is orange while it runs. If Bindy crashes, nothing keeps running.
- **Known weaknesses:** the block list and the "needs you" list are text matching on titles and names, not watertight; an app with an unusual title or an unlabelled button can slip through. Esc is only checked when an action runs, so a long Claude call finishes first (Pause and Stop work at once). Not tested at 150 % scaling, with several monitors of different scaling, or against elevated windows. A run on a PC with a Claude quota that is used up simply stops.
- **MCP:** `bindy_superguide` works only when both MCP and Superguide are on, asks for your click every time (max 3 questions per 10 minutes, none right after a no), and returns no result to the caller.
- Only use it on a PC you own, with nothing open that you cannot afford to lose, and watch it the first times.

## Claude Code as a client (MCP, off by default)

**In short:** it is off until you turn it on in Settings. It only works on this PC (nothing is opened to the network). Every screenshot and every guidance needs **your click** on Share or Start; Claude cannot click, type or paste for you through `bindy_se`, `bindy_pek` or `bindy_veiled`; only `bindy_superguide` can make Bindy act, and it asks for your click every time (see Superguide below). A screenshot you share goes to the Claude Code session that asked, which may have tools of its own, and text on the screen can try to steer that session. The text Claude shows in the question can be misleading, so judge by what you see on screen. Details:

With **Let Claude Code use Bindy (MCP)** on in Settings, Bindy listens on `127.0.0.1:47831/mcp` (never `0.0.0.0`, LAN or Funnel). Every request must come from the local machine, have the right `Host`, **no** `Origin` header, `Content-Type: application/json`, at most 16 KB and `Authorization: Bearer <token>`. The token is 32 random bytes stored with DPAPI in `bindy-mcp-token.bin` and compared in constant time; **New MCP token** in the tray menu replaces it. One request at a time. Tools: `bindy_status` (running, paused, guiding; no screen content) and `bindy_se` (screenshot of all screens or the active window). `bindy_se` shows a small window at the top of the screen, "Claude Code wants to see ... (reason)", and only takes the picture after you click **Share**: **one click per image**, no "remember", no keyboard (the window never takes focus, the button arms after 0.7 s, and the mouse must have rested on it for 0.4 s so a stray double-click cannot approve). Bindy refuses new questions for 60 s after a "no" and allows at most three questions per 10 minutes. The window opens on the screen where your mouse is and plays a sound, no answer in 30 s counts as declined, and pausing counts as declined. The reason text comes from Claude and is shown as plain text (control and direction characters removed, max 120 characters), so it can be misleading: judge by what you see. The block list is checked before asking (a blocked window gives a refusal without a prompt) and again when the picture is taken. The reply is marked as data, not instructions. `bindy_pek` draws a frame and/or the binder pointer from an image id and coordinates in image pixels (no click needed, it only draws; unknown or older than 5 minutes, or out-of-range coordinates, are refused; the label is cleaned like the reason). It fades after 30 s, or you remove it with Pause or Stop in the tray menu. It is refused while a guidance is running. `bindy_veiled` asks "Claude Code wants Bindy to guide you (screenshots go to Claude)" with the goal (max 160 characters, shown in full) and starts a guidance only after you click **Start** (same rules as Share: one click, no keyboard, 30 s timeout, block list checked first, refused while paused, while Bindy is answering you, or while a guidance runs; the state is checked again after you click). It replaces `bindy-start.txt`, which is **deprecated** (still works if its Settings option is on, but it starts without asking: prefer MCP). Bindy remembers only scale and offset per image id (max 10, 5 min), never the image, and never clicks, types or pastes for Claude. The log `bindy-sist.log` holds only time, machine, tool and outcome. The token is also stored in plain text in `~/.claude.json` by `claude mcp add -s user`, so DPAPI adds no protection against code already running as you. The tray menu puts the connect command on the clipboard marked "do not keep in history" (Windows clipboard history, the cloud clipboard and Bindy's own clip list skip it).

## Known limitations

- **The block list** for passwords and banking is title and process-name matching. It lets a lot through. It is not a guarantee.
- **Prompt injection through MCP:** a screenshot you share with a Claude Code session goes to *that* session, which may have tools (files, shell, network). Text on the screen can try to steer it. Only share when you trust the session and the reason, and keep the screen free of secrets. The tray icon turns red while a picture is taken.
- **Prompt injection:** text on the screen may try to steer Claude. Without Superguide the worst outcome is a misleading arrow or text: Claude has no tools to abuse, but you must judge what it suggests. With Superguide on, see below.
- **UI access** lowers the boundary between ordinary and administrator windows for this one process (see above).
- **Code already running as you** can try to get its own code into the Bindy process without touching `Program Files`: PowerShell compiles some helper classes (`Add-Type`) to `%TEMP%` at startup, and environment variables and `HKCU` are controlled by the user (for example `COR_PROFILER`). The launcher cleans `PSModulePath`, but this is not fully closed. It is a reason to only run Bindy on a machine you trust.
- Bindy does not copy links automatically. Text Claude suggests is only pasted when you press "Paste", and never into administrator windows, password or banking windows.
- **Claude can trigger "all screens":** if text on the screen makes Claude ask to see more, Bindy captures all screens without a new confirmation (the block list still applies). This only applies to questions you ask yourself; the automatic checks during guidance cannot trigger it. During guidance new screenshots are also sent automatically, also when you switch window.
- **Another program can start a guidance (off by default):** if "Let Claude Code start guidance" is on in Settings, any program running as you can write text to `%LOCALAPPDATA%\Bindy\bindy-start.txt`. Bindy then deletes the file, captures all screens and starts a guidance with that text as the goal, so the screenshot and the text are sent to Anthropic through your Claude login. Files older than 2 minutes are ignored, and nothing happens while Bindy is paused. Code already running as you can take screenshots itself, so the gain is small, but leave the setting off if you do not use it.
- **Settings files can be written by code running as you:** `bindy-del-utklipp`, `bindy-musefolger-av`, `bindy-settings.json` and `bindy-oppgave.md` in `%LOCALAPPDATA%\Bindy`. Code already running as you could therefore turn on clipboard sharing, change the hotkeys or put text into what Claude gets to see. It can already take screenshots itself, so the gain is small, but you should know. The settings file is validated when read (language and hotkeys only accept known values).
- The input box that appears beside the binder takes keyboard focus when you press the hotkey. If you press it in the middle of a password field, the rest of your keystrokes end up there.
- Bindy has not been audited by an independent party.

## Recommended use

Only run it on a machine you own. Do not install code you have not read. Do not let it look at windows with secret content: press **Ctrl+Alt+P** (pause) first.
