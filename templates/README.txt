Den här zip-filen innehåller data som är insamlat från Kape och sedan bearbetat.

* Varje underkatalog innehåller CSV-filer per server som har analyserats.
* Filerna i root-katalogen är sammanlagning av alla servrar

Timeline.xlsx             - En tidslinje skapad från de CSV-filer som innehåller tidsstämplar.
Timeline.csv              - Samma men i CSV-format.

ip-addresses.txt          - En lista på alla IP-adresser som förekommer (tagen från alla CSV-filer)
ip-addresses.csv          - En lista på alla IP-adresser som förekommer, berikad med land, stad osv som IP-adressen härstammar från.
ip-addresses-timeline.csv - Samma som ovan men dessutom med tidsstämpel då IP-adressen förekom.

run.log                   - Logg från körning av Kape och bearbetning. Bra att dubbelkolla så inget har gått fel och data missas.

Timeline filtrerar bort händelser som är äldre än ett år för att undvika att tidslinjen blir för stor.
