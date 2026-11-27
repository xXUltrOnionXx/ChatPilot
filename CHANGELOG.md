# Changelog

## 1.9.0
- Neu: Streamer-Modus - Flüstertexte versteckt (Maus drüber zum Hineinschauen), BattleTag-Nummern, Nachnamen und Web-Links verdeckt, rotes LIVE-Schild mit Panik-Knopf (/chatpilot stream)
- Neu: Namen nach @ lassen sich mit Initial schreiben ("Frost W."), Idee aus dem Feedback
- Neu: Markdown-Farben für *fett*, _kursiv_ und `Code` (nur Anzeige, ausgeschaltet bis du es einschaltest)

## 1.8.1
- Neu: im Filter-Menü jedes Fensters wählst du mit „Kanäle auswählen...“, welche Kanäle und Communities es zeigt (Idee aus dem Feedback)

## 1.8.0
- Neu: Warnung bei Links in Flüsternachrichten von Fremden (falsche Gegenstands-Links und Community-Einladungen werden markiert, verdächtige mit Werbung ausgeblendet)
- Neu: Suche in allen Chats (Spielfenster, eigene Fenster und Archive) unter Gut zu wissen oder mit /chatpilot suche
- Behoben: Fehler beim Rechtsklick auf einen Namen in den eigenen Chatfenstern
- Verbessert: Kurznamen und Erwähnungen funktionieren auch ohne Realm-Angaben, falls das Spiel sie später nicht mehr liefert

## 1.7.28
- Verbessert: Kanalnamen (auch russisch, koreanisch, chinesisch) werden ohne Textmuster gekürzt und fallen bei Problemen auf den Originalnamen zurück.

## 1.7.27
- Neu: Online-/Offline-Meldungen lassen sich in jedem Chatfenster einschalten (Filter-Menü, Eintrag Online-/Offline-Meldungen).
- Neu: Flüsterfenster zeigen, wenn die Person online kommt oder offline geht; der Punkt am Tab wechselt sofort.

## 1.7.26
- Verbessert: Kanalnamen mit kyrillischen und anderen nicht-lateinischen Buchstaben werden sicherer verarbeitet (Russisch: Kanalname erschien ohne Text).
- Verbessert: alle neuen Texte (Export/Import, Archiv, Rundgang, Online-Anzeige) sind in allen Sprachen übersetzt.

## 1.7.25
- Behoben: Fehlermeldung beim Drücken von Escape, nachdem der Export in eine Datei gespeichert wurde (Namensgleichheit zwischen Fenster und Sicherungsdatei).

## 1.7.24
- Neu: Flüsterfenster zeigen einen Punkt am Tab (grün = online, grau = offline oder unbekannt).
- Neu: Schreibst du jemandem, der nicht online ist, erscheint ein Hinweis im Fenster.

## 1.7.23
- Neu: Probleme beim Anzeigen von Chatzeilen werden gemeldet statt still verschluckt (/chatpilot fehler).

## 1.7.22
- Neu: Archiv für eigene Chatfenster. Ältere Zeilen gehen nicht mehr verloren, sondern wandern als Text ins Archiv des Fensters (bis zu 3000 Zeilen). Lesen und Suchen unter Einstellungen > Gut zu wissen > Archiv oder mit /chatpilot archiv. Export und Import nehmen das Archiv mit.

## 1.7.21
- Neu: Export und Import für Einstellungen, Notizen und Chats, als Text in Seiten zum Kopieren oder als Datei (ChatPilotBackup.lua im SavedVariables-Ordner); Knopf zum Löschen aller Daten vor dem Entfernen des Addons.
- Neu: leuchtender Hinweis auf neue Nachrichten im hochgescrollten Fenster; die Eingabeleiste blitzt beim Senden auf.
- Verbessert: Enter öffnet den zuletzt genutzten Chat, auch nach einem Klick; beim Senden springt der Chat nach unten.
- Behoben: ausgeblendete Nachrichten lassen sich anzeigen; Shift-Klick auf Items fügt sie in eigene Chats ein.
- Neu: Anleitung im Export-/Import-Fenster; der Rundgang zeigt alle neuen Funktionen (drei neue Schritte).
- Behoben: fehlender Text im hochgescrollten Fenster, Text blieb nach dem Senden stehen, Export zeigte bei großen Datenmengen keinen Text (jetzt komprimiert und in Seiten).

## 1.7.20
- Behoben: Beim Export erschien kein Text zum Kopieren.

## 1.7.19
- Behoben (wichtig): War ein eigenes Chatfenster hochgescrollt, erschienen neue Nachrichten nur als Kopfzeile ohne Text. Ursache war ein Fehler im Hinweis „Neue Nachrichten“ aus 1.7.16. Jetzt kommt die Nachricht immer an, und der Hinweis kann sie nicht mehr stören.

## 1.7.18
- Sichern & übertragen: Unter „Gut zu wissen“ lassen sich Einstellungen, Notizen und Chats (eigene Fenster, Verlauf, Flüstern, Erwähnungen) als Text exportieren und später wieder importieren, z. B. nach einer Neuinstallation oder auf einem anderen Computer. Das Format ist einfaches JSON. Beim Import wird alles geprüft; Ungültiges wird verworfen. Auch per `/chatpilot export` und `/chatpilot import`.
- Hinweis zum Entfernen des Addons: Löscht man den Addon-Ordner, bleiben Notizen und Chatverlauf in der Speicherdatei von WoW liegen. Das steht jetzt ausdrücklich in „Gut zu wissen“. Neu: Der Knopf „ALLE Daten löschen und neu laden“ leert die Speicherdatei, bevor man das Addon entfernt.

## 1.7.17
- Behoben: War der Chat hochgescrollt, blieb der Text nach dem Absenden im Eingabefeld stehen. Das Feld wird jetzt zuerst geleert, danach springt der Chat nach unten.
- Sichtbare Rückmeldung beim Absenden: Die Eingabeleiste blitzt kurz in der Akzentfarbe auf.

## 1.7.16
- Itemlinks per Shift-Klick funktionieren jetzt auch in den eigenen Chatfenstern: Der Link landet im Eingabefeld des Fensters, in dem du gerade schreibst (aus Taschen, Chatlinks usw.).
- Nach oben gescrollt? Sobald du eine Nachricht mit Enter abschickst, springt dieser Chat ganz nach unten (eigene und normale Chatfenster). Nicht beim Tippen.
- Kommen in einem eigenen Fenster neue Nachrichten an, während du weiter oben liest, leuchtet unten ein kleiner Hinweis „Neue Nachrichten“. Ein Klick springt nach unten, der Hinweis verschwindet auch von selbst, sobald du unten bist. Deine Leseposition bleibt dabei erhalten.

## 1.7.15
- Enter merkt sich den Chat: Hast du ein eigenes Fenster angeklickt (irgendwo im Fenster, auf einem Tab oder im Eingabefeld) oder darin gesendet (auch ohne Text, nur Enter zum Schließen), bringt dich die nächste Enter-Taste wieder in dasselbe Fenster mit demselben Ziel (Flüstern, Kanal, Gilde ...). Sendest du danach im normalen Eingabefeld des Spiels, gilt wieder dessen Verhalten. Bei einer Flüstern-Antwort merkt sich auch das Spiel das Ziel.
- Ausgeblendete (anstößige) Nachrichten lassen sich wieder anzeigen: Der Link „Anzeigen“ gibt die Nachricht frei und schreibt sie in allen Chatfenstern neu. In deinen eigenen Fenstern steht bis zum Klick nur ein Hinweis statt des Textes, ohne Erwähnungs-Alarm oder Hinweisfenster. Bei Nachrichten aus einer früheren Sitzung steht „nicht mehr verfügbar“.
- Ausgeblendete Nachrichten im normalen Chat bleiben unverändert, so wie das Spiel sie schreibt, damit „Anzeigen“ sie sauber ersetzen kann.

## 1.7.14
- Verlauf verdoppelt: eigene Chatfenster zeigen bis zu 1.000 statt 500 Zeilen und speichern 200 statt 100 Zeilen über Reload/Logout.
- Blizzard-Chats: jeweilige Scrollback-Kapazität pro Fenster verdoppelt (auch Kampflog und temporäre Flüsterfenster); gespeicherter Verlauf 240 statt 120 Zeilen pro normalem Chatfenster. Der Kampflog wird weiterhin nicht über Logout gespeichert.
- Nachrichtenpuffer für den Designwechsel: 400 statt 200 Zeilen.
- Flüsterverlauf: 60 statt 30 Gespräche mit jeweils 50 statt 25 Nachrichten. Erwähnungsverlauf: 200 statt 100 Einträge.
- Bestehender Verlauf bleibt erhalten. Die bisherige Aufbewahrungsdauer und gewählte automatische Leerungen bleiben unverändert.

## 1.7.13
- Fix aus 1.7.12: Modernes Design und Nachrichten-Aufbereitung werden jetzt auch an bereits beim Login erkannten Blizzard-Chatfenstern installiert. Einschalten nach dem Login funktioniert ohne Reload; neue Chatfenster werden weiterhin erfasst. Bei ausgeschaltetem modernem Design oder erkanntem Design-Konflikt werden diese Hooks nicht erstmals installiert.
- Andocken und Einrasten am Hauptchat verwenden den sichtbaren, ausgewählten Blizzard-Tab, auch wenn „Allgemein“ ausgeblendet ist (z. B. beim Kampflog).
- Die Titelleiste eines eigenen Fensters hat beim Andocken Vorrang vor dem dahinterliegenden Hauptchat. Vorschau und Ablegen wählen dasselbe Ziel; durch ausgeblendete Eltern unsichtbare Fenster sind keine Ziele.
- Paket enthält die benötigten Tippgeräusche unter `media/sounds`; Entwicklungstests werden nicht mitgeliefert.
- Prüfung: automatisierte Lua-5.1-Regressionstests mit simulierten WoW-Frames; kein Ingame-Test durchgeführt.

## 1.7.12
Ergebnis einer Tiefenprüfung aller Funktionen:
- Rundgang und Danke-Fenster gehen bei Kampfbeginn sofort aus dem Weg (der Rundgang dunkelte sonst den Bildschirm ab). Der Rundgang kommt nach dem Kampf an derselben Stelle zurück
- Mit normalem WoW-Design greift ChatPilot gar nicht mehr in die Chatfenster des Spiels ein (keine Hooks, keine Filter für den Look) – weniger mögliche Konflikte mit dem Spiel
- Sicherer bei geschützten Nachrichten im Bosskampf: Battle.net-Flüstern in eigenen Fenstern und im Flüster-Verlauf sowie der Spam-Zähler fassen geschützte Werte nicht mehr an
- Kein Sende-Ton mehr, wenn Enter nur einen @-Vorschlag übernimmt

## 1.7.11
- Rundgang aktualisiert: neue Schritte zu Tippgeräuschen & Pfeiltasten, zu den Tabs (umbenennen, laufende Namen, ▾) und zu „Gut zu wissen“ (Chats leeren, beim Ausloggen leeren, normales Design, Patchnotes). Erscheint nach dem Update einmal neu
- Alle Tabs haben eine **feste, gleiche Größe** für 10 Zeichen, egal wie lang der Name ist. Namen mit mehr als 10 Zeichen (Leerzeichen mitgezählt) laufen im Tab vom ersten bis zum letzten Zeichen durch. Passen nicht alle Tabs in die Leiste, stehen die übrigen im ▾-Menü
- Der ausgewählte Tab ist immer sichtbar und richtig markiert, auch direkt nach dem Umschalten
- Das ▾ im Hauptchat steht außerhalb des Chats, in einer Linie mit den Knöpfen daneben (Zahnrad, @ …)

## 1.7.10
- Fix: Im Fenster „Verpasste Flüsternachrichten“ verdeckten die Knöpfe den Namen – der Name steht jetzt in einer eigenen Zeile, die Knöpfe darunter
- Im Hauptchat sitzt das ▾ jetzt **außerhalb**, direkt rechts neben dem Chat – die Tabs haben die volle Breite des Chats
- Neu: Einstellungsseite **„Patchnotes“** mit allen bisherigen Updates in Kurzform, in allen 10 Sprachen (passend zur Sprache des Spiels)

## 1.7.8
- **Tabs umbenennen:** Rechtsklick auf einen Tab (im eigenen Fenster oder im Hauptchat) – Namen eintippen, Enter. Leer lassen = wieder der automatische Name
- **Tabs füllen die Leiste:** Deine Tabs werden so breit, dass sie die ganze Leiste ausfüllen – im Hauptchat bis zum ▾, das jetzt fest am rechten Rand sitzt (mit „+ Neues Fenster“ darin)
- **Lange Namen laufen durch:** Passt ein Name nicht ganz in seinen Tab, läuft er langsam von links nach rechts und zurück, so dass man ihn ganz lesen kann

## 1.7.7
- Neu: **Tippgeräusche** – leise Tastaturgeräusche beim Schreiben im Chat, dreizehn Klänge zur Wahl: **Aufnahme 1** (Standard) und **Aufnahme 2** – echte, aufgenommene Tastaturen –, **Metallisch**, **Klassisch**, **Mechanisch**, **Weich**, **Blue Switch** (mechanische Blue Switches) sowie die bekannten Tastatur-Klangrichtungen **Creamy**, **Thocky**, **Clacky**, **Poppy**, **Clicky** und **Lego**. Vier leicht unterschiedliche Tasten, eigene Töne für Leertaste, Löschen und Senden. Lautstärke einstellbar (Leise, Mittel, Normal, Laut). Alle Klänge sind sauber geschnitten: nur der Anschlag, kein Nachhall, kein Rauschen. Abschaltbar unter „Schreiben“ → „Tippgeräusche“; folgt der Effekt-Lautstärke des Spiels
- Neu: **Pfeiltasten bewegen den Cursor** zwischen den Buchstaben in jedem Chat-Eingabefeld – immer aktiv, kein Alt mehr nötig
- Das ▾-Menü hängt jetzt direkt hinter dem letzten sichtbaren Tab statt am rechten Rand

## 1.7.6
- Das **„+“ (neues Fenster) sitzt jetzt direkt hinter dem letzten Tab** – wie bei Browser-Tabs – statt fest oben rechts. Die Tab-Leiste bekommt dadurch die ganze Breite des Chats, die Namen deiner eigenen Fenster sind vollständig zu sehen
- Wird es eng, wandert das „+“ ins ▾-Menü („+ Neues Fenster“), damit es nie Platz von den Tab-Namen nimmt

## 1.7.5
- **Zurück zum normalen WoW-Design sofort und vollständig:** „Modernes Chatfenster“ aus stellt den normalen Chat ohne /reload wieder komplett original her – Rahmen, Tabs und Eingabefeld, und auch alle Zeilen, die schon dastehen: keine Blöcke, Level, kurzen Namen, kurzen Kanalnamen, Links oder Hervorhebungen mehr. Wieder einschalten macht alles wieder modern. Hintergrundfunktionen (Spamfilter, Erwähnungs-Hinweise, verpasste Flüsternachrichten) laufen weiter
- **@-Suche findet auch völlig Unbekannte:** neue Quellen „In der Nähe“ (Spieler um dich herum, Mouseover, Fokus) und die **Wer-Liste** – letzte Zeile „Auf dem Server suchen: …“ (Enter oder Klick) sucht online nach dem Namen, die Treffer erscheinen direkt in der Liste. Auch Ergebnisse deines eigenen /who landen dort
- **Beim Ausloggen automatisch leeren:** Unter „Gut zu wissen“ wählst du einzeln, welche Chats beim Ausloggen oder Beenden des Spiels geleert werden – jeder normale Chat-Tab, jedes eigene Fenster, der Flüster-Verlauf und die Erwähnungen. Ein /reload leert nichts. Anfangs ist nichts ausgewählt
- **Neue Notizen kommen nach vorne**, über alle anderen Notizen
- Fix: Umbrochene Zeilen sind nicht mehr eingerückt – sie stehen bündig unter der ersten Zeile (das Spiel-Original wird beim Wechsel aufs normale Design wiederhergestellt)
- Fix: Tabs werden nie mehr halb abgeschnitten (z. B. „;licht“) – die Leiste beginnt immer an einem Tab, scrollt tabweise, und was nicht ganz passt, steckt im ▾-Menü

## 1.7.4
- Fix: Über dem Chat erschienen leere Streifen und Kästen – das waren Blöcke von Zeilen, die schon aus dem sichtbaren Bereich gescrollt waren. Blöcke werden jetzt nur noch innerhalb der Chatfläche gezeichnet (angeschnittene Blöcke am Rand werden sauber abgeschnitten) und laufend an die Zeilen angepasst
- Etwas mehr Luft zwischen den Nachrichten-Blöcken

## 1.7.3
- Aufgeräumterer Chat: Jede Nachricht (Kopfzeile + Text) steht jetzt in einem eigenen **Block mit ganz leichtem grauem Hintergrund und einem farbigen Strich links** – in der Klassenfarbe des Absenders, in deiner Akzentfarbe für eigene Nachrichten, orange bei Erwähnungen. So sieht man sofort, wo eine Nachricht anfängt und aufhört und wer schreibt
- Namen ohne eckige Klammern, Text ohne Einrückung – umbrochene Zeilen stehen sauber untereinander
- Online-/Offline- und andere Systemmeldungen sind ruhig grau, Emotes sanft orange, ohne Block – so heben sich die echten Nachrichten ab
- Die Blöcke blenden mit dem Chat aus und verschwinden mit dem normalen WoW-Design („Modernes Chatfenster“ aus) komplett

## 1.7.2
- Neu: **Der normale Chat im neuen Look** – dieselben aufgeräumten zweizeiligen Nachrichten wie in den eigenen Fenstern: oben Kanal-Punkt, Name (Klassenfarbe, „Du“ für dich), kleine Uhrzeit und Kanal („· Handel“, „· Gilde“, „· an Tom“), darunter die Nachricht. Mehrere Nachrichten einer Person hintereinander werden gruppiert, Erwähnungen von dir sind orange. Namen und Kanäle bleiben anklickbar
- Gilt nur, solange „Modernes Chatfenster“ an ist. **Aus = normales WoW-Design: ChatPilot lässt den normalen Chat dann komplett so, wie Blizzard ihn schreibt** (die alten Farbbalken entfallen)
- Neu: **Chats leeren** – jedes eigene Fenster (Trichter → „Dieses Fenster leeren“), den normalen Chat (`/chatpilot clear`, `/chatpilot clear all`), den Flüster-Verlauf, die Erwähnungen oder alles auf einmal. Zweimal klicken zur Sicherheit
- Neu: Einstellungsseite **„Gut zu wissen“** – was ChatPilot speichert und wie viel gerade gespeichert ist, Leeren-Knöpfe, normales WoW-Design, Bosskämpfe und Blizzard-Regeln kurz erklärt (`/chatpilot info`)

## 1.7.1
- Neu: **Strukturierter Chat** in den eigenen Fenstern – klassischer WoW-Look, aber aufgeräumt: oben eine Kopfzeile mit Kanal-Punkt, Name (Klassenfarbe / „Du“), kleiner grauer Uhrzeit und Kanal-Label („· Handel“, „· an Lia“), darunter die Nachricht eingerückt. Mehrere Nachrichten einer Person hintereinander nur als weitere Textzeilen. Ruhigere Farben (Flüstern lila, Gilde grün, Handel/Allgemein hellgrau, System gedämpft mit Punkt), umbrochene Zeilen bleiben eingerückt
- Normaler Chat: kurze Kanal-Tags – „[Handel]“ statt „[2. Handel - Deutsch 41]“ (Klick auf den Kanal funktioniert weiter)
- Dunklerer, leicht transparenter Hintergrund für Chat und eigene Fenster

## 1.7.0
- Neu: **Gesprächs-Look** nach gängigen Chat-Design-Regeln – vor jeder Nachricht ein schmaler Farbbalken in der Klassenfarbe des Absenders, so lassen sich die Antworten aller sofort auseinanderhalten. **Eigene Nachrichten** haben einen breiten Balken in der Akzentfarbe (in eigenen Fenstern steht „Du“ statt des Namens), **Erwähnungen von dir** einen breiten orangen Balken, Systemmeldungen einen grauen
- In den eigenen Fenstern: mehrere Nachrichten einer Person hintereinander werden **gruppiert** (Name und Uhrzeit nur einmal, der Rest eingerückt), nach längeren Pausen erscheint eine **Zeitlinie**, und die Zeilen haben etwas mehr Abstand
- Gilt auch für den normalen Chat (Balken). Abschaltbar unter Design & Fenster → „Gesprächs-Look“

## 1.6.9
- Neu: **Leuchtende Benachrichtigungen** – kommt eine neue Erwähnung, Flüsternachricht oder Nachricht in einem eigenen Fenster, zieht sich eine weiche Lichtkugel in den Zähler bzw. den Punkt am Tab, blitzt kurz auf und leuchtet danach sanft „atmend“, solange etwas ungelesen ist. Abschaltbar unter Design & Fenster

## 1.6.8
- Tab-Leisten: Statt der Pfeile gibt es jetzt einen **Dropdown-Knopf ▾**, sobald nicht alle Tabs hineinpassen. Er listet alle Fenster mit **vollem, gut lesbarem Namen** (aktives markiert, ungelesene mit orangem Punkt). Klick = auswählen, **Eintrag herausziehen = abdocken** – genau wie beim Tab selbst. Gilt für die eigenen Fenster und für die Tabs im Hauptchat. Das Mausrad über den Tabs scrollt weiterhin

## 1.6.7
- Fix: Ein im Hauptchat angedocktes Fenster lag über Bank, Taschen, Händler und anderen Spielfenstern. Es hängt jetzt direkt am Chat und liegt damit immer genau eine Stufe über dem Chat – flackerfrei, und Spielfenster öffnen sich wieder ganz normal darüber. Dasselbe gilt für die Tabs der angedockten Fenster und das „+“ am Chat

## 1.6.6
- Fix: Im Hauptchat angedockte Fenster flackerten – sie liegen jetzt immer fest über dem Chat, statt mit ihm um den Vordergrund zu „kämpfen“, und ihre Tabs werden nur noch neu ausgerichtet, wenn sich die Chat-Tabs wirklich bewegt haben
- Fix: Größe ändern bei angedockten Fenstern brachte alles durcheinander. Angedockte Fenster haben jetzt keinen Größengriff mehr – sie sind immer genau so groß wie der Hauptchat (Größe über den Chat selbst ändern). Herausgezogen bekommen sie ihren Griff zurück

## 1.6.5
- Fix: Andocken im Hauptchat klappte nicht – die Position des Hauptchats wurde bei skaliertem Chat falsch erkannt. Jetzt fragt ChatPilot das Spiel direkt, ob die Maus über dem Chat oder seinen Tabs ist
- Fix: Ein über dem Chat eingerastetes Fenster „stahl“ das Ablegen – der Hauptchat hat jetzt Vorrang
- Fix: Die Tab-Leiste der eigenen Fenster im Hauptchat war falsch verankert
- Nach dem Andocken erscheint eine kurze Bestätigung im Chat

## 1.6.4
- Fix: Tabs ragten bei vielen Tabs oder schmalen Fenstern aus dem Fenster. Die Tab-Leiste ist jetzt **scrollbar** – die Tabs behalten ihre volle Größe. Mausrad über den Tabs oder die kleinen Pfeile schieben die Leiste, der aktive Tab wird automatisch ins Bild geholt
- Dasselbe für die eigenen Tabs im Hauptchat: Sie bleiben innerhalb der Chatbreite und lassen sich scrollen

## 1.6.3
- Neu: **Verpasste Flüsternachrichten als eigener Chat** – im Fenster „Verpasste Flüsternachrichten“ öffnet „Als Chat öffnen“ das Gespräch als eigenes Chat-Fenster. Oder das Gespräch einfach links aus der Liste herausziehen. Das Fenster zeigt nur Nachrichten mit dieser Person, bringt den bisherigen Verlauf mit und ist gleich auf sie als Ziel eingestellt. Ist es schon offen, wird es nur nach vorne geholt

## 1.6.2
- Rundgang aktualisiert: neuer Schritt „Kurze Namen, mehr Infos“ (kurze Nachnamen + Spieler-Info), Andocken im Hauptchat und Mausrad über den Tabs, Chat-Befehle (/w, /r, /g …) in den eigenen Fenstern, Glocke, Spam-Zähler am Zahnrad und Zeichenzähler. Erscheint nach dem Update einmal automatisch
- Rundgang: Hintergrund deutlich stärker abgedunkelt – nur der erklärte Knopf bleibt hell (Spotlight)

## 1.6.1
- Fix: Der Zeichenzähler (z. B. „42/255“) ist jetzt in allen Eingabefeldern zuverlässig sichtbar – im normalen Chat, im Community-Fenster und in den eigenen Chat-Fenstern. Er erscheint, sobald das Feld aktiv ist (auch bei 0), wird ab 80 % orange und am Limit rot, und kann von keinem Hintergrund mehr verdeckt werden
- Eigene Chat-Fenster nutzen dasselbe Limit wie der normale Chat (255 Zeichen), der Text läuft nicht mehr unter den Zähler

## 1.6.0
- Neu: **Eigene Fenster im Hauptchat andocken** – ein Fenster auf den Hauptchat ziehen (er leuchtet auf), dann bekommt es einen eigenen Tab neben den normalen Chat-Tabs. Klick auf den Tab zeigt das Fenster genau dort, Klick auf einen normalen Tab wechselt zurück. Tab herausziehen = wieder freies Fenster. Neue Nachrichten zeigen einen orangen Punkt am Tab
- Neu: **Mausrad über den Chat-Tabs** blättert durch die Tabs – auch zu den eigenen Fenstern im Hauptchat. Abschaltbar unter Chat-Hilfen
- Funktioniert mit dem modernen Chatfenster und mit dem originalen WoW-Look
- Schönere Glocke in den eigenen Fenstern: echtes Glocken-Symbol statt gezeichneter Pixel (an = farbig, aus = grau und durchgestrichen)
- Neu: **Spieler-Info beim Drüberfahren** – Maus über einen Namen im Chat (und in den eigenen Fenstern) zeigt vollen Namen in Klassenfarbe, Stufe, Klasse und ob die Person in Gruppe, Gilde oder Freundesliste ist. Die @-Vorschläge zeigen die Stufe gleich mit. Abschaltbar unter Chat-Hilfen
- Neu: Chat-Befehle direkt im eigenen Fenster – wie beim normalen Chat. `/w Name` + Leertaste oder Enter wird zum festen Ziel (der Befehl verschwindet, der Name lässt sich nicht mehr versehentlich buchstabenweise löschen). Was du danach schreibst, wird aus dem Fenster geflüstert und springt nicht mehr in den normalen Chat
- Funktioniert auch für `/g`, `/o`, `/p`, `/ra`, `/i`, `/s`, `/y`, `/e`, Kanäle wie `/2` und `/r` (Antwort an die letzte Flüsternachricht); `/w Name Text` + Enter flüstert sofort
- Rücktaste im leeren Eingabefeld entfernt das gewählte Ziel als Ganzes und springt zurück zum automatischen Ziel
- Andere Befehle (z. B. `/dance`) gehen wie bisher an den normalen Chat

## 1.5.1
- Fix (wichtig): Nach dem Senden in einem eigenen Chat-Fenster bleibt das Eingabefeld nicht mehr aktiv – die Tastatur geht sofort zurück ans Spiel, wie beim normalen Chat. Vorher landeten Tastendrücke (z. B. Fähigkeiten im Kampf) im Eingabefeld
- Sicherung: Beginnt ein Kampf, geben leere Eingabefelder der Chat-Fenster und Notizzettel die Tastatur automatisch ans Spiel zurück

## 1.5.0
- Neu: **Kurze Nachnamen** im Chat – „Frost Winterborn“ wird zu „Frost W.“. Gibt es zwei Frosts mit W, wird es automatisch „Frost Wi.“ / „Frost Wo.“. Maus über den Namen zeigt den vollen Namen; Flüstern, Einladen und Klicks nutzen weiter den vollen Namen. Auch in den eigenen Chat-Fenstern. Abschaltbar unter Chat-Hilfen
- Neu: **Spam-Zähler** – das Zahnrad am Chat und die Einstellungen zeigen, wie viele Spam-Nachrichten heute ausgeblendet wurden
- Neu: **Verträglich mit anderen Chat-Addons** – ist z. B. Prat, ElvUI, Chat Forever, PrimeChat oder GudaChat aktiv, lässt ChatPilot den Look des Chats in Ruhe (alle anderen Funktionen laufen weiter)

## 1.4.1
- Fix: In den eigenen Chat-Fenstern verschwand beim Drüberfahren der Text im Ziel-Menü und die Symbole oben im Fenster (Glocke, Filter, +, ×)
- Ziel-Knopf zeigt Kanäle kürzer („1. Allgemein“ statt „1. Allgemein - Sturmwind“)
- Fix: Das „+“ am Chat verschwand, wenn ein anderer angedockter Chat-Tab (z. B. Kampflog) ausgewählt war
- Fix: Der Hintergrund des modernen Chatfensters liegt jetzt sicher immer unter dem Chattext
- Fix: Viele Tabs in einem Fenster schieben sich nicht mehr unter die Symbole oben rechts
- Fix: Nach einer Filteränderung zeigt der Ziel-Knopf sofort ein passendes Ziel
- Fix: Ein neues Fenster bei „alle versteckt“ zeigt die anderen Fenster wieder, damit „Alle zeigen / verstecken“ stimmt
- Fix: Kanalnamen mit Sonderzeichen konnten eine Nachricht in den eigenen Fenstern verschlucken
- Fix: Der ausgewählte Bereich in den Einstellungen behält beim Design-Wechsel seine Farbe

## 1.4.0
- Neu: zweites Design „Forever“ – fröhlich, frisch, hoffnungsvoll (Meergrün, Minze, Sonnenaufgang-Gold). Umschalten unter Einstellungen → Design & Fenster, wirkt sofort
- Neu: modernes Chatfenster – der normale Chat bekommt einen flachen Look mit klaren Tabs und Eingabefeld im gewählten Design (abschaltbar)
- Neu: eigene Chat-Fenster mit Filtern (Flüstern, Gilde, Gruppe, Schlachtzug, Sagen, Schreien, Emotes, Allgemein, Handel, andere Kanäle, Communities, System). Frei verschiebbar, als Tabs andockbar (auf die Titelleiste eines anderen Fensters ziehen), über dem Chat einrastbar, Größe änderbar. Die letzten Nachrichten bleiben gespeichert
- Neu: **+** oben rechts am Chat – neues Chat-Fenster mit einem Klick
- Neu: direkt in den eigenen Fenstern schreiben. Der Knopf links zeigt das Ziel (standardmäßig dorthin, woher die letzte Nachricht kam), Klick auf einen Namen = flüstern. /Befehle und gesperrte Momente gehen ans normale Eingabefeld
- Neu: Glocke pro Fenster – Ton und Hinweis bei neuen Nachrichten
- Neu: moderner Rundgang, der alles Schritt für Schritt erklärt und die passenden Knöpfe hervorhebt. Jederzeit wieder ansehen über die Einstellungen oder `/chatpilot tutorial`
- Neue Befehle: `/chatpilot window`, `/chatpilot design forever|modern`, `/chatpilot tutorial`

## 1.3.5
- Neu: Notizzettel. Kleine Zettel, die du frei verschieben, in der Größe ändern und minimieren kannst (Knopf mit gelbem Zettel neben dem Chat). Linksklick zeigt/versteckt alle Notizen, Rechtsklick legt eine neue an. Notizen bleiben gespeichert, für alle Charaktere
- Hinweis in der Vorschlagsliste nennt jetzt auch Enter

## 1.3.4
- Enter übernimmt jetzt den markierten Vorschlag (Name, Textbaustein, Zielmarkierung), statt die Nachricht mit „@“ sofort abzuschicken. Ein zweites Enter sendet wie gewohnt

## 1.3.3
- Einstellungen aufgeräumt: Unteroptionen sind jetzt aufklappbar (Pfeil mit Anzahl der Unterpunkte), ebenso die Karten für Stichwörter, Textbausteine und Schrift. Der Zustand wird gespeichert

## 1.3.2
- Schrift in Flüster-, Erwähnungs- und Kopierfenster einstellbar: Größe (10–20) und Normal/Fett, mit Vorschau (Einstellungen → Flüstern)
- Schöneres, flaches Design: kein Schriftschatten mehr auf Knöpfen und Texten in den ChatPilot-Fenstern
- Neuer Schalter „Hintergrund der Knöpfe“: dunklen Hintergrund und Rahmen hinter den Chat-Knöpfen ausschalten (nur Symbole)

## 1.3.1
- Fix: Stufe wird jetzt auch bei „ist online“-Meldungen angezeigt – auch für Battle.net-Freunde, neue Freunde und Spieler, die mal mit und mal ohne Nachnamen auftauchen
- Gilden- und Freundesliste werden bei unbekannten Spielern automatisch aktualisiert

## 1.3.0
- Neuer Name: **ChatPilot Forever**
- Werbe-Spam-Filter (Gold, Boosts, Echtgeld, Webseiten) – Freunde, Gilde und Gruppe werden nie gefiltert
- Chatverlauf bleibt nach /reload und erneutem Einloggen erhalten
- Stufe im Chat, z. B. [18:Arthas]
- Textbausteine: #Kürzel + Tab fügt gespeicherten Text ein
- Neue Sprachen passend zu allen WoW-Regionen: Englisch, Deutsch, Französisch, Spanisch (Spanien & Mexiko), Italienisch, Portugiesisch (Brasilien), Russisch, Koreanisch, Chinesisch (vereinfacht & traditionell)
- ChatPilot erkennt die Sprache deines WoW-Clients automatisch
- Feedback mit einem einzigen Link: Das Addon füllt das Formular vorab aus – Strg+C, im Browser einfügen, Absenden. Nichts mehr doppelt schreiben
- Chat durchsuchen im Kopierfenster
- @-Vorschläge zeigen den Nachnamen (WoW: Forever), bei gleichem Vornamen wird der volle Name eingefügt
- Keine Eingabefeld-Änderungen während Blizzards Chat-Einschränkungen (Bosskämpfe)

## 1.2.1
- Update-Hinweis im Spiel: Nutzt jemand aus Gilde oder Gruppe eine neuere ChatPilot-Version, bekommst du einmal eine Meldung (ohne Internet, unsichtbare Addon-Nachrichten, nicht in Instanzen)

## 1.2.0
- Komplett neues, modernes Einstellungsfenster mit Seitenleiste (Schreiben, Erwähnungen, Chat-Hilfen, Über), Kippschaltern und Erklärung zu jeder Option
- Stichwörter als Chips: hinzufügen mit Enter, entfernen per Klick
- Gut sichtbare Knöpfe direkt neben dem Chatfenster (untereinander, auf Höhe des Eingabefelds): Zahnrad (Einstellungen), @ (Erwähnungen mit Zähler für ungelesene) und Kopieren – wahlweise auch in einer Reihe über dem Chat
- Eintrag im Addon-Menü an der Minimap
- Erwähnungs-, Kopier- und Feedback-Fenster im neuen Design
- Verpasste Flüsternachrichten: Brief-Knopf mit Zähler, Gesprächsfenster mit Antworten-Knopf, Zusammenfassung nach AFK oder Kampf (/chatpilot whispers)
- Anonymes Feedback ohne Anmeldung über ein Online-Formular (zusätzlich zu GitHub)
- Fehler behoben: Fenster ließen sich nicht mit dem X schließen

## 1.1.1
- Feedback geht jetzt an GitHub Issues

## 1.1.0
- Abkürzungen und Dungeon-Kürzel werden per Maus-Hover erklärt (LFG, WTS, LF2M, SM, BRD ...)
- Nachrichten in fremden Sprachen (andere Fraktion) werden abgedunkelt oder auf Wunsch ausgeblendet
- Spam-Filter für wiederholte Nachrichten in öffentlichen Kanälen
- Einstellungsfenster ist jetzt scrollbar

## 1.0.0
- Erste Version / first release
- @-Erwähnungen mit Namensvorschlägen (Gruppe, Ziel, Chat, Freunde, Gilde, Communities)
- Namensvorschläge für /w, /inv, /who
- Zielmarkierungs-Vorschläge nach {
- Zeichenzähler im Eingabefeld
- Erwähnungs-Alarme (Hervorhebung, Ton, Blinken, Benachrichtigung) und Erwähnungs-Verlauf
- Eigene Stichwörter
- Anklickbare Links mit Kopierfenster
- Chat-Kopieren-Knopf
- Feedback-System im Spiel
- Deutsch und Englisch
