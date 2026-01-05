# Sentrix-Restaurant

**Shared BaseClass**
De baseclass.lua in **src/shared/** wordt gebruikt om:
- Code-duplicatie te voorkomen.
- Logica overzichtelijk en uitbreidbaar te houden.
- Consistente structuur tussen client en server te behouden.

**Performance Aanpak**
- Geen onnodige while true do loops.
- Gebruik van events i.p.v. constante polling.
- Beperkt gebruik van client-side threads.
- Herbruikbare functies via shared code.

**Anti-Cheat Maatregelen**
- In server-side code validaties gemaakt om false triggering te voorkomen.
- Client geen belangrijke functies gegeven zoals client input
- Verder nog ratelimiting en logging toegevoegd
