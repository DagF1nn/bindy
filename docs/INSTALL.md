# Installation: get Bindy talking to Claude

Bindy has no login of its own and no API key. It starts Claude Code (`claude`) in the background and uses **your own** Claude login. Everything you send from Bindy therefore goes through your Claude account and counts against your quota.

Time: about 15 minutes. You only need administrator rights in step 3.

## Requirements

| What | Details |
|---|---|
| Windows | Windows 10 version 2004 or newer, or Windows 11. (Claude Code itself needs Windows 10 1809+, but Bindy hides its own windows from screenshots with a function introduced in 2004.) |
| PowerShell | Windows PowerShell 5.1 (ships with Windows). You do not need PowerShell 7. |
| Claude account | Claude **Pro, Max, Ultra, Team, Enterprise** or Console. The free plan on claude.ai does not include Claude Code. |
| Claude Code | Step 1 below. |

## Step 1: Install Claude Code

Open **PowerShell** (a normal window, not administrator) and run one of these:

```powershell
# Recommended (official install)
irm https://claude.ai/install.ps1 | iex

# or WinGet
winget install Anthropic.ClaudeCode
```

Bindy only starts a real `claude.exe` (what these two install). An npm install gives a `claude.cmd` wrapper, which Bindy deliberately does not use.

Close PowerShell, open a new window, then check:

```powershell
claude --version
claude doctor
```

`claude --version` should print a version number, for example `2.1.x (Claude Code)`.

**Getting "claude is not recognized"?** The official installer puts `claude.exe` in `%USERPROFILE%\.local\bin` but does not always set PATH. Fix it like this, and open a new window afterwards:

```powershell
$p = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$p;$env:USERPROFILE\.local\bin", 'User')
```

Bindy finds `claude` through PATH, so this must work before you continue.

## Step 2: Sign in and test that Claude answers

```powershell
claude
```

The first time, the browser opens and you sign in with your Claude account. When you see `Login successful`, type `/exit`.

Then test exactly the mode Bindy uses (no screen, one answer):

```powershell
claude -p "Answer with the word OK"
```

You should get `OK` back. If this does not work, Bindy will not work either.

> **Cost warning:** If the environment variable `ANTHROPIC_API_KEY` is set on the machine, `claude -p` uses that key instead of your subscription and you pay per use. Check with `echo $env:ANTHROPIC_API_KEY`. If it is empty, Bindy uses your subscription.

## Step 3: Install Bindy

Bindy is installed from source: there is no ready-made exe. The installer builds and signs it on your own PC.

1. Get the code: on the GitHub page choose **Code → Download ZIP**, or run `git clone https://github.com/DagF1nn/bindy.git`. Use a tagged release (for example `git checkout v0.1.2`) if you want a version that has been tested.
2. Unzip to a folder, for example `C:\Users\<you>\Bindy` (skip this after `git clone`). Do read `src\bindy.ps1` first. It is the whole program, in plain text. The installer copies the files to a folder only an administrator can write to before it shows the sums and signs, so that copy is what gets installed.
3. Open **PowerShell as administrator** (Win+X, "Terminal (Admin)") and run:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
   ```
4. The script does this, and nothing else:
   - makes a self-signed code-signing certificate and signs `BindyStart.exe` with it,
   - makes the certificate trusted on this machine (Root and TrustedPublisher),
   - deletes the certificate and the private key right after signing,
   - copies `BindyStart.exe` and `bindy.ps1` to `C:\Program Files\Bindy\`,
   - adds a Start menu shortcut and adds Bindy to startup for your user (`HKCU\...\Run`).
5. Start Bindy from the Start menu, or: `& 'C:\Program Files\Bindy\BindyStart.exe'` (or sign out and in).

**Why administrator and a certificate?** Windows only lets programs draw over the Start menu and taskbar if they are signed and live in a folder ordinary users cannot write to (`uiAccess`). Read `SECURITY.md` for what that means for security.

## Step 4: Use it

You will see a small paperclip in the tray (bottom right, maybe under the arrow for hidden icons).

| Key | Does |
|---|---|
| **Ctrl+Alt+H** | Ask with a screenshot of the window you are in |
| **Ctrl+Alt+J** | Ask without a screenshot |
| **Ctrl+Alt+P** | Pause (stops all screen capture) |
| **Ctrl+Alt+N** | Next guidance step |
| **Enter** | Send the question |
| **Shift+Enter** | New line in the question box |
| **Ctrl+Enter** or **Guide me** | Step-by-step guidance: Bindy points at what to click and checks along the way |
| **Esc** | Close the panel |

The four global hotkeys can be changed in **Settings** (the gear in the panel, or "Settings…" in the tray menu). Settings also holds the language (English or Norwegian; a change takes effect after restarting Bindy), "Follow the mouse with the binder", "Share clips with Claude" (off by default) and "Start Bindy with Windows". The tray menu also has "Clear clips", "Pause" and "Quit Bindy".

## Troubleshooting

| Problem | Fix |
|---|---|
| Nothing happens on Ctrl+Alt+H | Is Bindy running? Check the tray. Another app may have taken the hotkey; change it in Settings. |
| "Something went wrong" in the panel | Run `claude -p "OK"` in a normal window. Sign in again with `claude` if your login has expired. |
| "Could not find claude" | PATH is missing `%USERPROFILE%\.local\bin` (step 1). Restart Bindy after fixing PATH. |
| The drawing ends up behind the Start menu | You are running `bindy.ps1` directly instead of `BindyStart.exe` from `C:\Program Files\Bindy`. Only the signed launcher gets UI access. |
| Windows SmartScreen warns | The launcher is self-signed, not bought from a certificate authority. Check the checksum and choose "More info", "Run anyway" only if it matches. |
| Error log | `%LOCALAPPDATA%\Bindy\bindy-feil.log` |

## Updating

Download the new code (or run `git pull`), and run `scripts\install.ps1` as administrator again. It replaces the files and cleans up the old certificate.

## Uninstalling

As administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

The script stops Bindy and removes `C:\Program Files\Bindy`, the certificates, the startup entry, the Start menu shortcut and the files Bindy itself has made in `%LOCALAPPDATA%\Bindy` (unknown files there are left alone, and you are told).

## Optional: let Claude Code use Bindy (MCP)

Off by default. It lets a Claude Code session on **this PC** use three tools: `bindy_se` (screenshot), `bindy_pek` (frame and pointer) and `bindy_veiled` (start a guidance), plus `bindy_status`. Each screenshot and each guidance needs one click from you.

1. Install and start Bindy as above, then open the tray menu, **Settings…**, and turn on **Let Claude Code use Bindy (MCP)**.
2. Tray menu (the paperclip icon by the clock), **Connect Claude Code (MCP)…** puts a command on the clipboard (with your own secret token). Open a normal PowerShell window (Start menu, type "PowerShell"), paste it and press Enter. It looks like this (`-s user` means "for my user, in every folder"):
   ```powershell
   claude mcp add --transport http bindy http://127.0.0.1:47831/mcp --header "Authorization: Bearer <token>" -s user
   ```
3. Check with `claude mcp list` (it should say Connected), then start a **new** Claude Code session and ask it to look at your screen. You will see a small window at the top of the screen, "Claude Code wants to see …", and you must click **Share** (or **Decline**).

Notes: the token is a secret (it is also saved in plain text in your `.claude.json`). If you installed Bindy before MCP existed, run `scripts\install.ps1` again to update. Bindy only listens on `127.0.0.1` (this PC), never on the network. **New MCP token** in the tray menu replaces the token (then run `claude mcp remove bindy -s user` and add it again). Turning the setting off stops the server. Read the MCP parts of [SECURITY.md](SECURITY.md) first.