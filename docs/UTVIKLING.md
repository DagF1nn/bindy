# Utvikling

## Oppsett

- Windows 10 (2004+) eller 11, Windows PowerShell 5.1, git.
- Claude Code installert og innlogget (se [INSTALL.md](INSTALL.md)) for å prøve det ekte.
- Ingen SDK trengs: starteren bygges med `csc.exe` som følger med Windows (`scripts\bygg.ps1`).

## Struktur

| Sti | Hva |
|---|---|
| `src/bindy.ps1` | Hele programmet (WinForms, tegning, parsing av Claude-svar, veiledning) |
| `host/BindyHost.cs`, `host/app.manifest` | Signert starter: kjører `bindy.ps1` inni seg med `uiAccess` |
| `scripts/` | `bygg.ps1`, `installer.ps1`, `avinstaller.ps1` (oppdatering = kjør `installer.ps1` på nytt) |

## Kjøre og teste

```powershell
powershell -STA -File src\bindy.ps1 -Sjekk     # selvsjekk: parsing, utklipp, plassering, tegning (sender ingenting)
powershell -STA -File src\bindy.ps1            # kjør uten UI-tilgang (tegning havner bak Startmenyen)
```

Å teste den ekte installasjonen krever administrator og endrer maskinen (sertifikat, `C:\Program Files\Bindy`). Gjør det på en maskin du eier, og kjør `scripts\avinstaller.ps1` etterpå.

## Regler for endringer

- **Programmet kjører med UI-tilgang.** Hver endring skal leses linje for linje. Ingen `Invoke-Expression`, ingen nedlasting av kode, ingen nye avhengigheter uten god grunn.
- Alt Claude svarer med er **upålitelig input**: valider, begrens lengde og tall (se `Del-Svar`) og legg en test i `-Sjekk`.
- Claude får ingen verktøy i kallene (`--tools ""`). Endre ikke det uten å skrive hvorfor i `SECURITY.md`.
- Bindy skriver aldri skjermbilder til disk. Logg aldri innhold du skriver eller ser. Merk: `bindy-oppgave.md` inneholder Claudes steg-tekst, som kan komme fra skjermen.
- Hold `PRIVACY.md` og `SECURITY.md` i takt med koden i samme PR.

## Utgivelse

Se [PUBLISERE-PA-GITHUB.md](PUBLISERE-PA-GITHUB.md), del 5.
