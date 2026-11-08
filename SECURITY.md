# Sikkerhet

## Meld en sårbarhet

Ikke åpne en offentlig issue. Bruk **Report a vulnerability** under fanen *Security* i dette repoet (privat melding). Du får svar så fort eieren rekker det. Dette er et fritidsprosjekt uten garanti for svartid.

## Hva du gir fra deg ved å installere

Bindy er ikke vanlig programvare: for å tegne over Startmenyen trenger den **UI-tilgang** (`uiAccess`). Windows krever da at programmet er signert og ligger i en mappe vanlige brukere ikke kan skrive i. Installasjonen gjør derfor, som administrator:

1. Lager et selvsignert kodesigneringssertifikat (`CN=Bindy lokal signering`) og signerer `BindyStart.exe`.
2. Legger sertifikatet i maskinens **Root**- og **TrustedPublisher**-lager. Alt som signeres med nøkkelen blir dermed betrodd på maskinen.
3. **Sletter sertifikatet og den private nøkkelen** (`Remove-Item -DeleteKey`) rett etter signeringen, også ved feil, så ingen kan signere noe annet med den. Nøkkelen er laget ikke-eksporterbar og lever bare mens skriptet kjører.
4. Kopierer kildene til `C:\Program Files\Bindy\staging` (bare administrator kan skrive der), bygger og viser SHA-256 derfra, og signerer og kopierer **den samme kopien** til `C:\Program Files\Bindy\`. Ingen vanlig prosess kan bytte filene mellom hash-visningen og signeringen. Sammenlign likevel `bindy.ps1`-summen med den på utgivelsessiden.

Dette betyr:

- Prosessen kan styre vinduer som kjører som administrator og legge tegninger over alt. Skadelig kode som allerede kjører som deg, kan prøve å misbruke det.
- Du må stole på koden i utgivelsen du installerer. **Les `src/bindy.ps1` og `host/BindyHost.cs` først.** De er korte nok til å leses.
- `scripts\avinstaller.ps1` fjerner alt, inkludert sertifikatene.

## Hva Bindy ikke gjør

- Ingen nettverkskall bortsett fra de `claude` selv gjør. Bindy har ingen egen server og ingen egen telemetri.
- Ingen taster registreres. Under veiledning leses bare *hvor* og *når* du klikker med venstre museknapp, og til Claude sendes bare om klikket traff det markerte målet (ja/nei), ikke posisjonen.
- Bindy skriver aldri skjermbilder til disk. Den ber også Claude Code om ikke å lagre økten (`--no-session-persistence`).
- Claude får **ingen verktøy** (`--tools ""`: ikke filer, ikke nett, ikke kommandolinje) og leser ingen innstillinger eller hooks fra mapper (`--setting-sources ""`). Bindy starter bare en **programfil** `claude` (aldri `.cmd` eller `.ps1`) og fjerner `NODE_OPTIONS` fra miljøet til den.
- Bindy limer aldri inn noe uten at du trykker «Lim inn», og nekter å lime inn i passord- og bankvinduer.

## Kjente begrensninger

- **Sperrelista** for passord og bank er tittel- og prosessnavn-matching. Den slipper gjennom mye. Den er ingen garanti.
- **Prompt-injeksjon:** tekst på skjermen kan forsøke å styre Claude. Verste utfall er en villedende pil eller tekst. Claude har ingen verktøy å misbruke, men du må selv vurdere det den foreslår.
- **UI-tilgang** senker grensen mellom vanlige og administrator-vinduer for denne ene prosessen (se over).
- **Kode som allerede kjører som deg** kan prøve å få egen kode inn i Bindy-prosessen uten å røre `Program Files`: PowerShell kompilerer noen hjelpeklasser (`Add-Type`) til `%TEMP%` ved oppstart, og miljøvariabler og `HKCU` styres av brukeren (for eksempel `COR_PROFILER`). Verten rydder `PSModulePath`, men dette er ikke fullt lukket. Det er en grunn til å bare kjøre Bindy på en maskin du stoler på.
- Bindy kopierer ikke automatisk lenker. Tekst Claude foreslår limes inn først når du trykker «Lim inn», og aldri i administrator-vinduer, passord- eller bankvinduer.
- **Claude kan utløse «alle skjermer»:** står det tekst på skjermen som får Claude til å be om å se mer, tar Bindy bilde av alle skjermer uten ny bekreftelse (sperrelista gjelder). Det gjelder spørsmål du selv stiller; de automatiske sjekkene under veiledning kan ikke utløse det. Under veiledning sendes dessuten nye bilder automatisk, også når du bytter vindu.
- **Innstillingsfiler kan skrives av kode som kjører som deg:** `bindy-del-utklipp`, `bindy-musefolger-av` og `bindy-oppgave.md` i `%LOCALAPPDATA%\Bindy`. Kode som allerede kjører som deg kan dermed slå på deling av utklipp eller legge tekst inn i det Claude får se. Den kan allerede ta skjermbilder selv, så gevinsten er liten, men du bør vite det.
- Skrivefeltet som kommer ved bindersen tar tastaturfokus når du trykker hurtigtasten. Trykker du den midt i et passordfelt, havner resten av tastetrykkene der.
- Bindy er ikke revidert av en uavhengig part.

## Anbefalt bruk

Kjør den bare på en maskin du eier. Ikke installer en utgivelse du ikke har sjekket sjekksummen på. Ikke la den se på vinduer med hemmelig innhold: trykk **Ctrl+Alt+P** (pause) først.
