# INP_Projects2021
První a druhý projekt do INP 2021.


# Hodnocení

## První projekt

Overeni cinnosti kodu CPU:

   testovany program (kod)        vysledek
   1.  ++++++++++                    ok
   2.  ----------                    ok
   3.  +>++>+++                      ok
   4.  <+<++<+++                     ok
   5.  .+.+.+.                       ok
   6.  ,+,+,+,                       chyba
   7.  [........]noLCD[.........]    ok
   8.  +++[.-]                       ok
   9.  +++++[>++[>+.<-]<-]           ok
  10.  +[+~.------------]+           ok

Podpora jednoduchych cyklu: ano

Podpora vnorenych cyklu: ano

Poznamky k implementaci:
Procesor nereaguje korektne na signal RESET nebo se pri nekterem programu zacykli

Data z klavesnice korektne nactena, ale chybne zapsana do RAM (zpozdeni jeden takt)

Mozne problematicke rizeni nasledujicich signalu: DATA_WREN

Celkem bodu za CPU implementaci: 14 (z 17)
