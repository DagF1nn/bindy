# Bindy

En hjelper på skjermen for Windows. Du trykker en hurtigtast, stiller et spørsmål, og Bindy (en liten binders i en «øy» øverst på skjermen) svarer med Claude, ut fra det du ser. Under **veiledning** tegner den en ramme og peker på det ene du skal trykke på, ett steg om gangen, og sjekker underveis om du kom riktig.

> **Status: 0.x, under utvikling.** Teksten i programmet er foreløpig bare på norsk.

## Hva den gjør

- **Ctrl+Alt+H**: spør med skjermbilde av vinduet du står i. **Ctrl+Alt+J**: spør uten skjerm.
- **Veiledning** (Ctrl+Enter eller «Veiled meg»): ett steg om gangen, ramme og binders-peker på målet. Står du stille, forklarer den enklere.
- **Valgknapper:** må Claude spørre om noe, får du knapper å trykke på i stedet for å skrive.
- **Tegner over alt**, også over Startmenyen og oppgavelinja.
- **Utklippshistorikk** (bare i minnet) som kan limes inn med ett klikk.
- Ingen egen konto og ingen API-nøkkel: den bruker **din** Claude Code-innlogging.

## Slik virker det

```
hurtigtast -> skjermbilde (i minnet) -> `claude -p` (din innlogging) -> svar + tegnekoder -> ramme/peker/knapper
```

Bindy er ett PowerShell-skript (`src/bindy.ps1`) som kjører inni en liten signert C#-starter (`host/`). Starteren trengs bare for at tegningen skal kunne ligge over Startmenyen (`uiAccess`).

## Installer

Se **[docs/INSTALL.md](docs/INSTALL.md)** (ca. 15 min). Kort: installer Claude Code, logg inn, kjør `scripts\installer.ps1` som administrator.

## Før du installerer: les dette

1. **Skjermbilder og tekst sendes til Anthropic.** Aktivt vindu (eller alle skjermer), det du skriver, og eventuelt utklipp (hvis du slår på deling) går via din egen `claude`-innlogging og teller mot din kvote. Se [PRIVACY.md](PRIVACY.md).
2. **Installasjonen krever administrator.** Den legger et selvsignert sertifikat som betrodd på maskinen og gir én eksefil UI-tilgang. Det senker en sikkerhetsgrense i Windows. Se [SECURITY.md](SECURITY.md) og les koden først.
3. **Sperrelista for passord og bank er en enkel tittelsjekk**, ikke en garanti. Ikke bruk Bindy med skjermen full av ting du ikke vil sende.
4. **Claude kan ta feil.** Piler og tekst kan peke feil. Bindy limer aldri inn noe uten at du trykker «Lim inn».

## Krav

Windows 10 (2004+) eller 11, Windows PowerShell 5.1, Claude Code og en Claude-konto (Pro, Max, Team, Enterprise eller Console).

## Bygge selv

```powershell
powershell -File scripts\bygg.ps1        # krever bare csc.exe som følger med Windows
powershell -STA -File src\bindy.ps1 -Sjekk   # selvsjekk, sender ingenting
```

## Bidra og rapportere

Se [docs/UTVIKLING.md](docs/UTVIKLING.md). Sårbarheter: se [SECURITY.md](SECURITY.md), ikke åpne en offentlig issue.

## Lisens

MIT, se [LICENSE](LICENSE).
