# Modul 03: Kontinuerlig integration (CI) och kvalitetsgrindar

Denna dokumentation beskriver implementationen av repots första automatiserade CI-pipeline samt hur lokala skript används som gränssnitt för att säkerställa repots struktur och kvalitet.

## Arkitektur och gränssnitt

Ett centralt designmönster i detta upplägg är att **pipelinen anropar ett namn, inte ett innehåll**. Genom att låta GitHub Actions köra fasta skriptfiler (`build.sh` och `test.sh`) blir pipelinen frikopplad från applikationsspecifik logik. 

När applikationen introduceras i Modul 04 ändras endast *innehållet* i skripten, medan själva pipeline-definitionen (`build-test-pipeline.yml`) förblir oförändrad.

### Lokala skript

1. **`scripts/build.sh`**
   - **Syfte:** Fungerar som en tidig statisk analys och byggkontroll.
   - **Logik:** Kör `shellcheck` för att validera alla `.sh`-filer om verktyget finns installerat lokalt. Kontrollerar därefter att kritiska filer som `README.md` och `.gitignore` existerar i repots rot. Använder `set -euo pipefail` för att avbryta omedelbart vid första fel.

2. **`scripts/test.sh`**
   - **Syfte:** Kör funktionella och strukturella tester.
   - **Logik:** Validerar existens av filer, körrättigheter på byggskriptet samt att `README.md` innehåller en korrekt rubrikstruktur (`^# `). Använder inte `-e` globalt för att tillåta att samtliga kontroller körs och rapporteras, men returnerar en samlad exit-kod (`$fail`) i slutet.

---

## Pipeline-konfiguration (GitHub Actions)

Pipelinen är konfigurerad i `.github/workflows/build-test-pipeline.yml` och triggas automatiskt vid två specifika händelser:
- `push` till grenen `main`.
- `pull_request` mot grenen `main`.

Den körs på en virtuell maskin med `ubuntu-latest` och består av tre huvudsakliga steg:
1. **Check Out the Code:** Hämtar repots källkod med hjälp av `actions/checkout@v7`.
2. **Run the Build Script:** Exekverar `./scripts/build.sh`.
3. **Run the Test Script:** Exekverar `./scripts/test.sh`.

Om något av skripten returnerar en exit-kod som inte är `0`, markeras bygget som misslyckat (rött), vilket blockerar eventuella pull requests från att slås ihop ovetande om felen.

---

## Verifiering av kvalitetsgrind (Break-on-purpose)

För att bevisa att pipelinen fungerar som en effektiv kvalitetsgrind genomfördes ett kontrollerat test på grenen `break-on-purpose`:
1. `.gitignore` raderades avsiktligt och ändringen pushades på en ny gren.
2. En Pull Request öppnades, vilket triggade `build-test-pipeline.yml`.
3. Pipelinen misslyckades helt enligt förväntan då `test.sh` flaggade för `FAIL  .gitignore exists` och returnerade exit-kod `1`.
4. Ändringen återställdes med `git revert`, vilket återigen gjorde pipelinen grön och bevisade att grinden effektivt stoppar trasig kod från att nå `main`.
