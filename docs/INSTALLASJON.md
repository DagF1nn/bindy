# Installasjon: få Bindy til å snakke med Claude

Bindy har ingen egen innlogging og ingen API-nøkkel. Den starter Claude Code (`claude`) i bakgrunnen og bruker **din egen** Claude-innlogging. Alt du sender fra Bindy, går dermed via din Claude-konto og teller mot din kvote.

Tid: ca. 15 minutter. Du trenger administrator bare i steg 3.

## Krav

| Hva | Detaljer |
|---|---|
| Windows | Windows 10 versjon 2004 eller nyere, eller Windows 11. (Claude Code selv krever Windows 10 1809+, men Bindy skjuler egne vinduer fra skjermbilder med en funksjon som kom i 2004.) |
| PowerShell | Windows PowerShell 5.1 (følger med Windows). Du trenger ikke PowerShell 7. |
| Claude-konto | Claude **Pro, Max, Ultra, Team, Enterprise** eller Console. Gratisplanen på claude.ai gir ikke Claude Code. |
| Claude Code | Steg 1 under. |

## Steg 1: Installer Claude Code

Åpne **PowerShell** (vanlig vindu, ikke administrator) og kjør én av disse:

```powershell
# Anbefalt (offisiell installasjon)
irm https://claude.ai/install.ps1 | iex

# eller WinGet
winget install Anthropic.ClaudeCode

# eller npm (krever Node.js 22 eller nyere)
npm install -g @anthropic-ai/claude-code
```

Lukk PowerShell og åpne et nytt vindu, så sjekk:

```powershell
claude --version
claude doctor
```

`claude --version` skal skrive et versjonsnummer, for eksempel `2.1.x (Claude Code)`.

**Får du «claude finnes ikke»?** Den offisielle installasjonen legger `claude.exe` i `%USERPROFILE%\.local\bin`, men setter ikke alltid PATH. Rett det slik, og åpne et nytt vindu etterpå:

```powershell
$p = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$p;$env:USERPROFILE\.local\bin", 'User')
```

Bindy finner `claude` via PATH, så dette må virke før du går videre.

## Steg 2: Logg inn og test at Claude svarer

```powershell
claude
```

Første gang åpnes nettleseren, og du logger inn med Claude-kontoen din. Når du ser `Login successful`, skriv `/exit`.

Test deretter akkurat den modusen Bindy bruker (uten skjerm, ett svar):

```powershell
claude -p "Svar med ordet OK"
```

Du skal få `OK` tilbake. Virker ikke dette, vil ikke Bindy virke heller.

> **Advarsel om kostnad:** Er miljøvariabelen `ANTHROPIC_API_KEY` satt på maskinen, bruker `claude -p` nøkkelen i stedet for abonnementet ditt, og du betaler per bruk. Sjekk med `echo $env:ANTHROPIC_API_KEY`. Er den tom, bruker Bindy abonnementet.

## Steg 3: Installer Bindy

1. Last ned nyeste utgivelse (`Bindy-x.y.z.zip`) fra **Releases** på GitHub. Sjekk SHA-256-summen mot den som står på utgivelsessiden:
   ```powershell
   Get-FileHash .\Bindy-x.y.z.zip -Algorithm SHA256
   ```
2. Pakk ut til en mappe, for eksempel `C:\Users\<deg>\Bindy`. Les gjerne `src\bindy.ps1` først. Det er hele programmet, i klartekst. Installasjonen kopierer filene til en mappe bare administrator kan skrive i, før den viser summene og signerer, så det er den kopien som blir installert.
3. Åpne **PowerShell som administrator** (Win+X, «Terminal (administrator)») og kjør:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\installer.ps1
   ```
4. Skriptet gjør dette, og ingenting annet:
   - lager et selvsignert kodesigneringssertifikat og signerer `BindyStart.exe` med det,
   - legger sertifikatet som betrodd på denne maskinen (Root og TrustedPublisher),
   - sletter sertifikatet og den private nøkkelen rett etter signeringen,
   - kopierer `BindyStart.exe` og `bindy.ps1` til `C:\Program Files\Bindy\`,
   - legger Bindy til i oppstart for din bruker (`HKCU\...\Run`).
5. Start Bindy: `& 'C:\Program Files\Bindy\BindyStart.exe'` (eller logg ut og inn).

**Hvorfor administrator og sertifikat?** Windows setter bare tegninger over Startmenyen og oppgavelinja for program som er signert og ligger i en mappe vanlige brukere ikke kan skrive i (`uiAccess`). Les `SECURITY.md` for hva det betyr for sikkerheten.

## Steg 4: Bruk det

Du ser en liten binders i tray (nederst til høyre, kanskje under pila for skjulte ikoner).

| Tast | Gjør |
|---|---|
| **Ctrl+Alt+H** | Spør med skjermbilde av vinduet du står i |
| **Ctrl+Alt+J** | Spør uten skjermbilde |
| **Ctrl+Alt+P** | Pause (stopper all skjermfangst) |
| **Ctrl+Alt+N** | Neste steg i veiledningen |
| **Enter** | Send spørsmålet |
| **Ctrl+Enter** eller **Veiled meg** | Veiledning steg for steg: Bindy peker på det du skal trykke, og sjekker underveis |
| **Esc** | Lukk panelet |

Tray-menyen har «Del utklipp med Claude» (av som standard), «Tøm utklipp», «Pause» og «Avslutt Bindy».

## Feilsøking

| Problem | Løsning |
|---|---|
| Ingenting skjer ved Ctrl+Alt+H | Er Bindy startet? Sjekk tray. En annen app kan ha tatt hurtigtasten. |
| «Noe gikk galt» i panelet | Kjør `claude -p "OK"` i et vanlig vindu. Logg inn på nytt med `claude` hvis innloggingen er utløpt. |
| «Fant ikke claude» | PATH mangler `%USERPROFILE%\.local\bin` (steg 1). Start Bindy på nytt etter at PATH er rettet. |
| Tegningen havner bak Startmenyen | Du kjører `bindy.ps1` direkte i stedet for `BindyStart.exe` fra `C:\Program Files\Bindy`. Bare den signerte starteren får UI-tilgang. |
| Windows SmartScreen advarer | Starteren er selvsignert, ikke kjøpt fra en sertifikatutsteder. Sjekk sjekksummen og velg «Mer info», «Kjør likevel» bare hvis den stemmer. |
| Feillogg | `%LOCALAPPDATA%\Bindy\bindy-feil.log` |

## Oppdatering

Last ned ny utgivelse, pakk ut, og kjør `scripts\installer.ps1` som administrator igjen. Det erstatter filene og rydder bort det gamle sertifikatet.

## Avinstallering

Som administrator:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\avinstaller.ps1
```

Skriptet stopper Bindy, fjerner `C:\Program Files\Bindy`, sertifikatene, oppstartsoppføringen og filene Bindy selv har laget i `%LOCALAPPDATA%\Bindy` (ukjente filer der blir liggende, og du får beskjed).
