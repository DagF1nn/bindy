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

## Known limitations

- **The block list** for passwords and banking is title and process-name matching. It lets a lot through. It is not a guarantee.
- **Prompt injection:** text on the screen may try to steer Claude. The worst outcome is a misleading arrow or text. Claude has no tools to abuse, but you must judge what it suggests.
- **UI access** lowers the boundary between ordinary and administrator windows for this one process (see above).
- **Code already running as you** can try to get its own code into the Bindy process without touching `Program Files`: PowerShell compiles some helper classes (`Add-Type`) to `%TEMP%` at startup, and environment variables and `HKCU` are controlled by the user (for example `COR_PROFILER`). The launcher cleans `PSModulePath`, but this is not fully closed. It is a reason to only run Bindy on a machine you trust.
- Bindy does not copy links automatically. Text Claude suggests is only pasted when you press "Paste", and never into administrator windows, password or banking windows.
- **Claude can trigger "all screens":** if text on the screen makes Claude ask to see more, Bindy captures all screens without a new confirmation (the block list still applies). This only applies to questions you ask yourself; the automatic checks during guidance cannot trigger it. During guidance new screenshots are also sent automatically, also when you switch window.
- **Settings files can be written by code running as you:** `bindy-del-utklipp`, `bindy-musefolger-av`, `bindy-settings.json` and `bindy-oppgave.md` in `%LOCALAPPDATA%\Bindy`. Code already running as you could therefore turn on clipboard sharing, change the hotkeys or put text into what Claude gets to see. It can already take screenshots itself, so the gain is small, but you should know. The settings file is validated when read (language and hotkeys only accept known values).
- The input box that appears beside the binder takes keyboard focus when you press the hotkey. If you press it in the middle of a password field, the rest of your keystrokes end up there.
- Bindy has not been audited by an independent party.

## Recommended use

Only run it on a machine you own. Do not install a release whose checksum you have not checked. Do not let it look at windows with secret content: press **Ctrl+Alt+P** (pause) first.
