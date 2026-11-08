# Slik publiserer du Bindy på GitHub

Retningslinjer for eieren av repoet. Gå gjennom i rekkefølge. **Repoet er privat til sjekklista i del 1 er krysset av.** Å gjøre det offentlig kan ikke angres: det kan være hentet og lagret av andre i løpet av sekunder, selv om du sletter det igjen.

## Del 1: Før noe er offentlig

- [ ] **Hemmeligheter:** ingen nøkler, tokens, passord, IP-adresser eller e-poster i koden. Søk: `git grep -n -i -E "token|secret|passord|password|api[_-]?key|100\.[0-9]+\.[0-9]+\.[0-9]+|C:\\\\Users\\\\"`.
- [ ] **Historikken:** søk også i gamle commits: `git log -p | Select-String -Pattern "token|secret|passord"`. Fant du noe, **lag repoet på nytt med ren historikk** (ikke bare slett filen i en ny commit, for den ligger igjen i historikken).
- [ ] **Forfatter-e-post:** commits viser e-posten du committer med. Bruk GitHubs noreply-adresse: GitHub, Settings, Emails, «Keep my email addresses private», og kopier `<id>+<brukernavn>@users.noreply.github.com`. Sett den: `git config user.email "<adressen>"` **før** første commit. Er den allerede brukt, lag historikken på nytt.
- [ ] **Egne ting:** ingen bilder eller skjermbilder med privat innhold i repoet eller README. Sjekk hvert eneste bilde. Ingen filer fra testing (`*.log`, `*.png` fra temp).
- [ ] **LICENSE:** uten lisens har andre ingen rett til å bruke koden. Repoet bruker MIT (enkel, tillater alt så lenge lisensteksten følger med). Vil du hindre at noen selger det videre uten å dele endringer, velg GPL-3.0 i stedet. Velg før du går offentlig.
- [ ] **README, SECURITY.md og PRIVACY.md** er lest av deg og stemmer med koden. Spesielt: hva som sendes til Anthropic, og risikoen ved administrator-installasjonen.
- [ ] **`.gitignore`** dekker loggfiler, bygg (`out/`), `.env`, nøkler og sertifikatfiler (`*.pfx`, `*.cer`, `*.key`).
- [ ] **Ingen binærfiler du ikke kan forklare** i repoet. Bygg `BindyStart.exe` fra kildekoden (`scripts\bygg.ps1`), ikke sjekk den inn.
- [ ] **Selvsjekken er ren:** `powershell -STA -File src\bindy.ps1 -Sjekk`.
- [ ] **Sikkerhetsgjennomgang** er kjørt (`/security-review` i Claude Code, og funnene er rettet eller noterte i SECURITY.md).

## Del 2: Opprett repoet

Du trenger en GitHub-konto. Velg **én** av tre veier.

**A. GitHub CLI (raskest):**
```powershell
winget install GitHub.cli        # én gang, åpne et nytt vindu etterpå
gh auth login                    # velg GitHub.com, HTTPS, nettleser
cd C:\Users\<deg>\bindy
git add -A
git status                       # les lista: er alt her meningen?
git commit -m "Første versjon"
gh repo create bindy --private --source=. --push
```

**B. GitHub Desktop:** File, Add local repository, velg mappen, «Publish repository», **kryss av for «Keep this code private»**.

**C. Nettsiden:** github.com/new, navn `bindy`, **Private**, ingen README/lisens (du har egne). Kjør deretter kommandoene GitHub viser under «push an existing repository».

Sjekk på github.com at filene ser riktige ut, og at ingen filer du ikke ville ha med, ligger der.

## Del 3: Slå på vern (Settings, Code security)

- **Secret scanning** og **Push protection**: på. Stopper at du pusher nøkler ved en feil. Gratis for offentlige repoer.
- **Dependabot alerts** og **security updates**: på. Bindy har få avhengigheter, men Actions-filene teller.
- **Private vulnerability reporting**: på. Da kan folk melde sårbarheter privat. Peker `SECURITY.md` på den.
- **Branch protection** på `main` (Settings, Rules): krev pull request og at sjekken (Actions) er grønn. Hindrer at en feil commit ødelegger utgivelsen.
- To-faktor på GitHub-kontoen din. Uten den kan en overtatt konto legge skadelig kode i en utgivelse folk installerer som administrator.

## Del 4: Gjør det offentlig

1. Sjekk del 1 en gang til.
2. Settings, nederst, **Change visibility**, Public.
3. Fyll inn **About**: kort beskrivelse, **Topics** (`windows`, `powershell`, `claude`, `accessibility`, `screen-assistant`), ingen nettside nødvendig.
4. Slå på **Issues**. Legg inn issue-malene i `.github/ISSUE_TEMPLATE`.

## Del 5: Utgivelser

Folk skal laste ned en utgivelse, ikke klone `main`.

```powershell
git tag -a v0.1.0 -m "Første utgivelse"
git push origin v0.1.0
# pakk (uten .git og uten out/):
Compress-Archive -Path src, host, scripts, docs, README.md, LICENSE, SECURITY.md, PRIVACY.md -DestinationPath Bindy-0.1.0.zip
(Get-FileHash Bindy-0.1.0.zip -Algorithm SHA256).Hash        # lim inn i utgivelsesteksten
gh release create v0.1.0 Bindy-0.1.0.zip --title "Bindy 0.1.0" --notes-file CHANGELOG.md
```

- Bruk **semantisk versjonering**: `0.x` mens ting kan endre seg, `1.0.0` når du lover at det virker.
- Skriv i utgivelsesteksten: SHA-256, hva som er nytt, og kjente begrensninger.
- Last ikke opp ferdig-bygde `.exe`-filer folk ikke kan sammenligne med kildekoden. Be dem bygge selv (`scripts\bygg.ps1`) eller verifiser summen.

## Del 6: Når andre begynner å bruke det

- **Issues:** svar kort. «Takk, jeg ser på det», eller «utenfor omfanget». Du skylder ingen noe.
- **Pull requests:** les **hver linje** av koden før du slår den sammen. Dette programmet kjører med UI-tilgang. En ondsinnet endring kan gjøre stor skade.
- **Sårbarhetsmeldinger:** rett først, publiser deretter, og skriv takk i `CHANGELOG.md`.
- **Hold `CHANGELOG.md` oppdatert** ved hver utgivelse.
- **Ikke lov mer enn det som er sant.** Sperrelista for passord og bank er en enkel tittelsjekk, ikke en garanti.

## Hvis du pushet noe du ikke skulle

1. **Anta at det er kompromittert.** Er det en nøkkel eller et passord: bytt/slett det hos tjenesten **først**.
2. Fjern det fra historikken (`git filter-repo` eller lag repoet på nytt), og tving gjennom: `git push --force`.
3. Be GitHub Support om å fjerne cachede visninger og commits hvis det var offentlig.
