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

# or npm (needs Node.js 22 or newer)
npm install -g @anthropic-ai/claude-code
```

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

1. Download the latest release (`Bindy-x.y.z.zip`) from **Releases** on GitHub. Check the SHA-256 sum against the one on the release page:
   ```powershell
   Get-FileHash .\Bindy-x.y.z.zip -Algorithm SHA256
   ```
2. Unzip to a folder, for example `C:\Users\<you>\Bindy`. Do read `src\bindy.ps1` first. It is the whole program, in plain text. The installer copies the files to a folder only an administrator can write to before it shows the sums and signs, so that copy is what gets installed.
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

Download the new release, unzip, and run `scripts\install.ps1` as administrator again. It replaces the files and cleans up the old certificate.

## Uninstalling

As administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1
```

The script stops Bindy and removes `C:\Program Files\Bindy`, the certificates, the startup entry, the Start menu shortcut and the files Bindy itself has made in `%LOCALAPPDATA%\Bindy` (unknown files there are left alone, and you are told).
