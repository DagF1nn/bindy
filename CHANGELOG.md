# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/), versioning follows [SemVer](https://semver.org/).

## [Unreleased]

### MCP (Claude Code can use Bindy)
- Optional MCP server on `127.0.0.1` (off by default): `bindy_status`, `bindy_se` (screenshot, one click per image), `bindy_pek` (frame and pointer), `bindy_veiled` (start guidance, one click). Token with DPAPI, Host/Origin/size checks, block list checked before asking.
- A tip beside the mouse ("Stuck? Press Ctrl+Alt+N") when a guidance step has been waiting for 20 seconds.
- Next step no longer fails when the Start menu or taskbar has focus: Bindy uses all screens then.
- `bindy-start.txt` is deprecated in favour of `bindy_veiled`.

### First version
- Ask Claude with a hotkey and a screenshot, or without the screen.
- Step-by-step guidance with a frame, arrow and paperclip pointer, choice buttons, and help when you stand still. The current step shows in a clear card at the top of the screen.
- A paperclip that follows the mouse, with a small input field beside it.
- Drawing over the Start menu via a signed launcher with `uiAccess`.
- Clipboard history in memory. Sharing with Claude is off by default, and a notice shows what Bindy puts on the clipboard.
- Settings window: language (English default, Norwegian), options, and hotkeys that can be changed.
