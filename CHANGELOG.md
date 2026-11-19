# Changelog

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
