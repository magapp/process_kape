Den här zip-filen innehåller data som är insamlat från Kape och sedan bearbetat.


Timeline.xlsx             - En tidslinje skapad från de CSV-filer som innehåller tidsstämplar.
Timeline.csv              - Samma tidslinje men utan markeringar och flera flikar.

ip-addresses.txt          - En lista på alla IP-adresser som förekommer (tagen från alla CSV-filer)
ip-addresses.csv          - En lista på alla IP-adresser som förekommer, berikad med land, stad osv som IP-adressen härstammar från.
ip-addresses-timeline.csv - Samma som ovan men dessutom med tidsstämpel då IP-adressen förekom.

run.log                   - Logg från körning av Kape och bearbetning. Bra att dubbelkolla så inget har gått fel och data missas.

Respektive .zip-fil är per datorn som är processad och innehåller CSV-filer.

Timeline filtrerar bort händelser som är äldre än ett år för att undvika att tidslinjen blir för stor.
