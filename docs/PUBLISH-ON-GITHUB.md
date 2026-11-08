# How to publish Bindy on GitHub

Guidelines for the owner of the repo. Go through them in order. **The repo stays private until the checklist in part 1 is ticked off.** Making it public cannot be undone: others may have fetched and stored it within seconds, even if you delete it again.

## Part 1: Before anything is public

- [ ] **Secrets:** no keys, tokens, passwords, IP addresses or emails in the code. Search: `git grep -n -i -E "token|secret|password|api[_-]?key|100\.[0-9]+\.[0-9]+\.[0-9]+|C:\\\\Users\\\\"`.
- [ ] **History:** search old commits too: `git log -p | Select-String -Pattern "token|secret|password"`. If you find anything, **recreate the repo with a clean history** (do not just delete the file in a new commit, because it stays in the history).
- [ ] **Author email:** commits show the email you commit with. Use GitHub's noreply address: GitHub, Settings, Emails, "Keep my email addresses private", and copy `<id>+<username>@users.noreply.github.com`. Set it: `git config user.email "<the address>"` **before** the first commit. If it has already been used, rebuild the history.
- [ ] **Personal things:** no pictures or screenshots with private content in the repo or README. Check every single image. No files from testing (`*.log`, `*.png` from temp).
- [ ] **LICENSE:** without a license nobody else has the right to use the code. The repo uses MIT (simple, allows everything as long as the license text comes along). If you want to stop anyone reselling it without sharing changes, choose GPL-3.0 instead. Choose before going public.
- [ ] **README, SECURITY.md and PRIVACY.md** have been read by you and match the code. Especially: what is sent to Anthropic, and the risk of the administrator install.
- [ ] **`.gitignore`** covers log files, builds (`out/`), `.env`, keys and certificate files (`*.pfx`, `*.cer`, `*.key`).
- [ ] **No binary files you cannot explain** in the repo. Build `BindyStart.exe` from source (`scripts\build.ps1`), do not check it in.
- [ ] **The self-check is clean:** `powershell -STA -File src\bindy.ps1 -Sjekk`.
- [ ] **A security review** has been run (`/security-review` in Claude Code, and the findings are fixed or noted in SECURITY.md).

## Part 2: Create the repo

You need a GitHub account. Choose **one** of three ways.

**A. GitHub CLI (fastest):**
```powershell
winget install GitHub.cli        # once, open a new window afterwards
gh auth login                    # choose GitHub.com, HTTPS, browser
cd C:\Users\<you>\bindy
git add -A
git status                       # read the list: is everything meant to be here?
git commit -m "First version"
gh repo create bindy --private --source=. --push
```

**B. GitHub Desktop:** File, Add local repository, choose the folder, "Publish repository", **tick "Keep this code private"**.

**C. The website:** github.com/new, name `bindy`, **Private**, no README/license (you have your own). Then run the commands GitHub shows under "push an existing repository".

Check on github.com that the files look right and that no files you did not want are there.

## Part 3: Turn on protection (Settings, Code security)

- **Secret scanning** and **Push protection**: on. Stops you pushing keys by mistake. Free for public repos.
- **Dependabot alerts** and **security updates**: on. Bindy has few dependencies, but the Actions files count.
- **Private vulnerability reporting**: on. Then people can report vulnerabilities privately. `SECURITY.md` points to it.
- **Branch protection** on `main` (Settings, Rules): require a pull request and a green check (Actions). Stops a bad commit from breaking the release.
- Two-factor on your GitHub account. Without it, a hijacked account can put malicious code in a release that people install as administrator.

## Part 4: Make it public

1. Check part 1 once more.
2. Settings, at the bottom, **Change visibility**, Public.
3. Fill in **About**: short description, **Topics** (`windows`, `powershell`, `claude`, `accessibility`, `screen-assistant`), no website needed.
4. Turn on **Issues**. Add the issue templates in `.github/ISSUE_TEMPLATE`.

## Part 5: Releases

People should download a release, not clone `main`.

```powershell
git tag -a v0.1.0 -m "First release"
git push origin v0.1.0
# pack (without .git and without out/):
Compress-Archive -Path src, host, scripts, docs, README.md, LICENSE, SECURITY.md, PRIVACY.md -DestinationPath Bindy-0.1.0.zip
(Get-FileHash Bindy-0.1.0.zip -Algorithm SHA256).Hash        # paste into the release text
gh release create v0.1.0 Bindy-0.1.0.zip --title "Bindy 0.1.0" --notes-file CHANGELOG.md
```

- Use **semantic versioning**: `0.x` while things can change, `1.0.0` when you promise that it works.
- In the release text, write: the SHA-256, what is new, and known limitations.
- Do not upload prebuilt `.exe` files people cannot compare with the source. Ask them to build it themselves (`scripts\build.ps1`) or verify the sum.

## Part 6: When others start using it

- **Issues:** answer briefly. "Thanks, I will look at it", or "out of scope". You owe nobody anything.
- **Pull requests:** read **every line** of the code before you merge it. This program runs with UI access. A malicious change can do great damage.
- **Vulnerability reports:** fix first, publish afterwards, and write a thank-you in `CHANGELOG.md`.
- **Keep `CHANGELOG.md` up to date** with every release.
- **Do not promise more than is true.** The block list for passwords and banking is a simple title check, not a guarantee.

## If you pushed something you should not have

1. **Assume it is compromised.** If it is a key or a password: change or delete it at the service **first**.
2. Remove it from the history (`git filter-repo` or recreate the repo), and force it through: `git push --force`.
3. Ask GitHub Support to remove cached views and commits if it was public.
