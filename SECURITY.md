# Sikkerhet

## Meld en sårbarhet

Ikke åpne en offentlig issue. Bruk **Report a vulnerability** under fanen *Security* i dette repoet (privat melding). Du får svar så fort eieren rekker det. Dette er et fritidsprosjekt uten garanti for svartid.

## Hva du gir fra deg ved å installere

Bindy er ikke vanlig programvare: for å tegne over Startmenyen trenger den **UI-tilgang** (`uiAccess`). Windows krever da at programmet er signert og ligger i en mappe vanlige brukere ikke kan skrive i. Installasjonen gjør derfor, som administrator:

1. Lager et selvsignert kodesigneringssertifikat (`CN=Bindy lokal signering`) og signerer `BindyStart.exe`.
2. Legger sertifikatet i maskinens **Root**- og **TrustedPublisher**-lager. Alt som signeres med nøkkelen blir dermed betrodd på maskinen.
3. **Sletter den private nøkkelen** rett etter signeringen, så ingen kan signere noe annet med den.
4. Kopierer `BindyStart.exe` og `bindy.ps1` til `C:\Program Files\Bindy\` (bare administrator kan endre dem).

Dette betyr:

- Prosessen kan styre vinduer som kjører som administrator og legge tegninger over alt. Skadelig kode som allerede kjører som deg, kan prøve å misbruke det.
- Du må stole på koden i utgivelsen du installerer. **Les `src/bindy.ps1` og `host/BindyHost.cs` først.** De er korte nok til å leses.
- `scripts\avinstaller.ps1` fjerner alt, inkludert sertifikatene.

## Hva Bindy ikke gjør

- Ingen nettverkskall bortsett fra de `claude` selv gjør. Bindy har ingen egen server og ingen egen telemetri.
- Ingen taster registreres. Under veiledning leses bare *hvor* og *når* du klikker med venstre museknapp.
- Skjermbilder lagres aldri på disk.
- Claude får **ingen verktøy** (ikke filer, ikke nett, ikke kommandolinje) i kallene Bindy gjør.
- Bindy limer aldri inn noe uten at du trykker «Lim inn», og nekter å lime inn i passord- og bankvinduer.

## Kjente begrensninger

- **Sperrelista** for passord og bank er tittel- og prosessnavn-matching. Den slipper gjennom mye. Den er ingen garanti.
- **Prompt-injeksjon:** tekst på skjermen kan forsøke å styre Claude. Verste utfall er en villedende pil eller tekst. Claude har ingen verktøy å misbruke, men du må selv vurdere det den foreslår.
- **UI-tilgang** senker grensen mellom vanlige og administrator-vinduer for denne ene prosessen (se over).
- **Kode som allerede kjører som deg** kan prøve å få egen kode inn i Bindy-prosessen uten å røre `Program Files`: PowerShell kompilerer noen hjelpeklasser (`Add-Type`) til `%TEMP%` ved oppstart, og miljøvariabler og `HKCU` styres av brukeren (for eksempel `COR_PROFILER`). Verten rydder `PSModulePath`, men dette er ikke fullt lukket. Det er en grunn til å bare kjøre Bindy på en maskin du stoler på.
- Bindy kopierer ikke automatisk lenker. Tekst Claude foreslår limes inn først når du trykker «Lim inn», og aldri i administrator-vinduer, passord- eller bankvinduer.
- Bindy er ikke revidert av en uavhengig part.

## Anbefalt bruk

Kjør den bare på en maskin du eier. Ikke installer en utgivelse du ikke har sjekket sjekksummen på. Ikke la den se på vinduer med hemmelig innhold: trykk **Ctrl+Alt+P** (pause) først.
