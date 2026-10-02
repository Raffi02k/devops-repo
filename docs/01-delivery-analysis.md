# DevOps-analys av Almqvist Logistik AB

## 1. Flödet
Ett team på nio personer förvaltar ett bokningssystem för godstransporter. En ändring går från beslut på ett planeringsmöte, via utveckling och kodgranskning (pull request), till ett manuellt bygge. Därefter testas paketet i en gemensam testmiljö och väntar sedan på ett månatligt releasefönster innan det driftsätts manuellt.

## 2. Värdeflödeskarta
| Steg | Bearbetningstid | Väntetid | Rätt första gången |
|---|---|---|---|
| Utveckling | 3 d | - | 100% |
| Granskning | 20 min (0,04 d) | 4 d | 100% |
| Bygge för hand | 45 min (0,09 d) | - | 100% |
| Test | 2 d | 3 d | 60% (40% fel) |
| Vänta på releasefönster | - | 11 d | - |
| Driftsättning | 4 h (0,5 d) | - | 75% (25% fel) |

**Total ledtid:** ~23,6 arbetsdagar
**Andel värdeskapande tid:** 5,6 / 23,6 = ~24%

## 3. De tre största väntetiderna
**Releasefönstret (11 dagar)**
Den i särklass längsta väntetiden. Koden är färdigtestad och klar, men ligger helt still i väntan på den sista torsdagen i månaden.

**Granskningskön (4 dagar)**
Här väntar 20 minuters arbete i hela fyra dagar. Förhållandet mellan väntan och faktiskt arbete är sämst i hela flödet.

**Testmiljön upptagen (3 dagar)**
Beror på en delad resurs. Det finns bara en testmiljö och den är ofta upptagen av föregående release.

## 4. DORA-måtten för det här flödet
* **Driftsättningsfrekvens:** 12 per år (ett låst releasefönster i månaden).
* **Tid från ändring till drift:** ~24 arbetsdagar (den totala ledtiden uträknad i steg 2).
* **Andel misslyckade ändringar:** ~25% (var fjärde release kräver en akut åtgärd dagen efter).
* **Återställningstid:** Minst ett dygn (6 timmars manuellt arbete, plus att felet ofta upptäcks först dagen efter).

## 5. Bedömning mot kvalitetskriterierna
* **Utvecklingskrav (Dev):**
  * *Korrekthet:* Uppfylls inte helt. Även om test görs, studsar 40% av ändringarna tillbaka på grund av fel.
  * *Spårbarhet:* Uppfylls inte alls. Paketet byggs för hand och skickas vidare, vilket gör det omöjligt att i drift veta exakt vilken kod-commit som körs.
* **Driftkrav (Ops):**
  * *Förutsägbarhet:* Uppfylls inte alls. Manuella byggen och driftsättningar gör att slutresultatet beror på vem som utför uppgiften och hur trött personen är.
  * *Återställbarhet:* Uppfylls inte alls. En manuell återställning på sex timmar innebär enorm risk och lång nertid.

## 6. Vad jag skulle ändra först, och varför
Jag skulle rekommendera en teamöverenskommelse om att prioritera kodgranskningar över nytt eget arbete. 

*Motivering:* Granskningskön är den flaskhals som är snabbast och billigast att lösa. Vi har 20 minuters arbete som väntar i 4 dagar. Till skillnad från releasefönstret kräver detta inga nya tekniska verktyg eller tunga automatiseringsprojekt för att åtgärda, bara en ändring i teamets kultur.
