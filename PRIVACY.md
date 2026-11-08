# Personvern

Bindy samler ikke inn noe selv, har ingen konto og ingen server. Men den sender innhold til Anthropic via din egen Claude Code-innlogging. Her er nøyaktig hva.

## Hva som sendes til Anthropic

| Når | Hva sendes | Merk |
|---|---|---|
| Ctrl+Alt+H og under veiledning | Skjermbilde av aktivt vindu (maks 1280 px bredt) eller alle skjermer (maks 2000 px) | Fanges bare når du trykker, når «Skjerm» er på, og under en veiledning du har startet |
| Alltid | Det du skriver, og de siste spørsmålene og svarene (maks 6, glemmes etter 10 min) | |
| Alltid | Oppgavenotatet (`bindy-oppgave.md`, maks 3000 tegn), hvis det finnes | Lagres lokalt, se under |
| **Bare hvis du slår på «Del utklipp med Claude»** | De 6 siste kopiene, hver maks 200 tegn | **Av som standard** |

Hva Anthropic gjør med dataene, avgjøres av din Claude-konto og Anthropics egne vilkår og personvernerklæring. Bindy kan ikke styre det.

## Hva som aldri fanges

- Vinduer med passord eller bank i tittelen, og passordbehandlere, fanges ikke. «Alle skjermer» nektes når et slikt vindu er synlig. **Dette er en enkel tittelsjekk og ikke en garanti.**
- Kopier markert som private av passordbehandlere (`ExcludeClipboardContentFromMonitorProcessing`) lagres ikke.

## Hva som lagres på maskinen din

Alt ligger i `%LOCALAPPDATA%\Bindy\`:

| Fil | Innhold |
|---|---|
| `bindy-oppgave.md` | Gjeldende mål og fremdrift, i klartekst. **Inneholder Claudes steg-tekst, som kan referere til det som sto på skjermen** |
| `bindy-oppgave.forrige.md` | Arkivert kopi av forrige oppgave |
| `bindy-feil.log` | Feilmeldinger (kan inneholde tekst fra Claude), kuttes ved 100 kB |
| `bindy-host-feil.log` | Feil fra starteren (`BindyStart.exe`), sjelden |
| `bindy-del-utklipp` | Tom fil: finnes den, er deling av utklipp på |

**Bindy skriver aldri skjermbilder til disk.** De ligger bare i minnet til de er sendt, og Bindy ber Claude Code om ikke å lagre økten (`--no-session-persistence`).
Utklippshistorikken (maks 8, maks 400 tegn, slettes etter 60 min) ligger bare i minnet.

## Slett alt

`scripts\avinstaller.ps1` fjerner programmet og mappen over. Eller slett `%LOCALAPPDATA%\Bindy` for hånd.
