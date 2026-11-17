# ChatPilot Forever

**ChatPilot Forever – der intuitivere Chat für WoW: Forever** – @-Erwähnungen mit Namensvorschlägen, Erwähnungs-Alarme, anklickbare Links, Chat kopieren und ein eingebautes Feedback-System.

*English below.*

## 🌍 Sprachen
ChatPilot passt sich automatisch der Sprache deines WoW-Clients an:
Englisch · Deutsch · Français · Español (ES/MX) · Italiano · Português (BR) · Русский · 한국어 · 简体中文 · 繁體中文

## 💬 Feedback, Fehler & Ideen
**Ohne Anmeldung, anonym:** 👉 **[Feedback-Formular](https://forms.gle/zpQr4CFqMkBETFVV6)**

Mit GitHub-Konto – bitte über die Vorlagen:
- 🐞 **[Fehler melden](https://github.com/xXUltrOnionXx/ChatPilot/issues/new?template=bug_report.yml)**
- 💡 **[Idee vorschlagen](https://github.com/xXUltrOnionXx/ChatPilot/issues/new?template=feature_request.yml)**
- ⭐ **[Feedback / Lob](https://github.com/xXUltrOnionXx/ChatPilot/issues/new?template=feedback.yml)**

Im Spiel geht's am einfachsten: `/chatpilot feedback` → Nachricht schreiben → **Senden**. Du bekommst **einen fertig ausgefüllten Link**: Strg+C, im Browser einfügen, auf Absenden klicken – fertig.

## Funktionen

### Schreiben
- **@-Erwähnungen:** Tippe `@` und ChatPilot schlägt Namen vor – Leute aus deiner Gruppe, deinem Ziel, wer gerade im Chat geschrieben hat, Freunde, Gildenmitglieder und Mitglieder deiner Communities. Die Namen sind in Klassenfarben.
  - Wer gerade schreibt, steht weiter oben. `@` allein zeigt die aktivsten Leute.
  - **Tab** oder **Klick** fügt den Namen ein, **Pfeil hoch/runter** wählt aus.
- **/w, /inv, /who:** Auch hier gibt es Namensvorschläge (bei anderen Realms mit Realm-Namen).
- **Zielmarkierungen:** `{` + Name, z. B. `{ste` → Stern. Funktioniert in jeder Sprache (`{rt1}`–`{rt8}`).
- **Zeichenzähler:** zeigt `123/255` im Eingabefeld, orange kurz vor dem Limit, rot wenn es voll ist.
- Funktioniert auch im **Community-Fenster**.

### Erwähnungen
- Erkennt, wenn jemand deinen Namen oder eins deiner **Stichwörter** schreibt (z. B. Spitznamen).
- Hebt den Namen im Chat **orange** hervor, spielt einen Ton ab, lässt das Taskleisten-Symbol blinken und zeigt eine kleine Benachrichtigung.
- **Erwähnungs-Verlauf:** `/chatpilot mentions` zeigt die letzten 100 Erwähnungen (auch die, die du verpasst hast).
- Namen in Item- und Quest-Links lösen keinen Alarm aus.

### Chat verstehen
- **Abkürzungen erklärt:** Begriffe wie `LFG`, `WTS`, `pst`, `LF2M`, `gz` und Dungeon-Kürzel wie `SM`, `BRD`, `UBRS`, `MC` sind leicht hellblau. Fährst du mit der Maus darüber, erscheint die Erklärung auf Deutsch. Mehrdeutige Kürzel (`AH`, `SM`, `ST` …) zählen nur in GROSSBUCHSTABEN, damit normale Wörter nicht markiert werden.
- **Fremde Sprachen:** Nachrichten in einer Sprache, die dein Charakter nicht kann (z. B. Gemeinsprache, wenn du Horde spielst), werden grau mit dem Hinweis „(fremde Sprache – nicht lesbar)“ angezeigt oder auf Wunsch ganz ausgeblendet. **Übersetzt werden sie nicht** – das ist technisch unmöglich (der Server schickt nur das Kauderwelsch) und von Blizzard nicht erlaubt.
- **Spam-Filter:** Wer in öffentlichen Kanälen (Handel, Suche nach Gruppe …) innerhalb von 90 Sekunden dasselbe noch mal schreibt, wird nur einmal angezeigt.
- **Tipp:** Eigene Stichwörter funktionieren auch als Suchalarm, z. B. `BRD` oder `Ony` – dann wirst du benachrichtigt, sobald jemand eine Gruppe dafür sucht.

### Verpasste Flüsternachrichten
- Unbeantwortete Flüsternachrichten werden am **Brief-Knopf** neben dem Chat gezählt.
- Ein Fenster zeigt alle Gespräche; **Antworten** öffnet dein Eingabefeld mit dem richtigen Namen (abschicken tust du selbst).
- Kommst du aus dem **AFK** oder einem **Kampf** zurück, siehst du, wer dir geschrieben hat.
- Während Bosskämpfen kann das Spiel den Text verbergen – dann zählt ChatPilot die Nachricht nur und verweist auf den Chat.

### Noch mehr Komfort
- **Werbe-Spam weg:** Goldverkäufer, bezahlte Boosts und Webseiten-Werbung werden ausgeblendet. Normaler Handel, Freunde, Gilde und Gruppe bleiben unberührt.
- **Chatverlauf bleibt:** Nach `/reload` oder erneutem Einloggen ist dein Chat noch da.
- **Stufe im Chat:** `[18:Arthas]` – farbig nach Schwierigkeit, sobald die Stufe bekannt ist (Gruppe, Ziel, Maus, Gilde, Freunde, /who).
- **Textbausteine:** In den Einstellungen Texte speichern, im Chat `#Kürzel` + Tab – fertig.
- **Chat durchsuchen** im Kopierfenster.

### Sonstiges
- **Anklickbare Links:** Internetadressen im Chat werden blau. Ein Klick öffnet ein Fenster, aus dem du den Link mit Strg+C kopierst.
- **Chat kopieren:** kleiner Knopf oben rechts an jedem Chatfenster.
- **Feedback-System:** `/chatpilot feedback` – Art wählen (Fehler/Idee/Lob), Sterne vergeben, Text schreiben. ChatPilot erstellt einen fertigen Bericht (inkl. Addon- und Client-Version), den du kopierst und als Issue auf GitHub postest: https://github.com/xXUltrOnionXx/ChatPilot/issues

## Bedienung
- **Zahnrad** direkt rechts neben dem Chatfenster → Einstellungen (Knöpfe wahlweise auch über dem Chat)
- **@** daneben → Erwähnungs-Verlauf (orange Zahl = ungelesene Erwähnungen)
- **Brief** → verpasste Flüsternachrichten
- **Notiz-Symbol** → Chat kopieren
- Oder über das **Addon-Menü an der Minimap**, `/chatpilot` bzw. Spieloptionen → AddOns → ChatPilot

## Befehle
| Befehl | Wirkung |
|---|---|
| `/chatpilot` oder `/cpilot` | Einstellungen öffnen |
| `/chatpilot mentions` | Erwähnungs-Verlauf |
| `/chatpilot whispers` | Verpasste Flüsternachrichten |
| `/chatpilot copy` | Aktuellen Chat kopieren |
| `/chatpilot feedback` | Feedback geben |
| `/chatpilot add <Wort>` / `del <Wort>` / `list` | Stichwörter verwalten |
| `/chatpilot test` | Test-Alarm |

## Blizzard-Regeln (UI Add-On Development Policy)
ChatPilot wurde so gebaut, dass es die Regeln einhält:
- **Sendet nie selbst Nachrichten.** Es ändert nur den Text in deinem Eingabefeld; abschicken tust du immer selbst mit Enter. Keine Automatisierung, kein Spam, keine Server-Last.
- **Kostenlos**, Quellcode offen und lesbar (nicht verschleiert), MIT-Lizenz.
- **Keine Werbung, keine Spendenaufrufe, keine Pop-ups im Spiel.** Das Feedback-Fenster öffnet sich nur, wenn du es selbst aufrufst.
- **Kein Internetzugriff, keine Datensammlung:** Feedback wird nur lokal gespeichert; du entscheidest, ob du es auf GitHub postest.
- Respektiert die Midnight-Addon-Einschränkungen: „geheime“ Chatwerte (Secret Values) werden nicht ausgelesen – ChatPilot macht in solchen Momenten einfach nichts.
- Nutzt nur `HookScript`/`hooksecurefunc` und Chat-Filter, ersetzt keine Blizzard-Funktionen, die Fehler („Aktion blockiert“) verursachen könnten.

---

## English

**A smarter, more intuitive chat for WoW: Forever.**

- **@-mention autocomplete:** type `@` to get name suggestions from your group, target, recent chatters, friends, guild and communities (class-coloured, most active first). Tab/click to insert, arrow keys to select.
- Name suggestions after `/w`, `/inv`, `/who`; raid marker suggestions after `{`; character counter.
- **Mention alerts:** highlight, sound, taskbar flash and an on-screen notice when someone writes your name or a keyword. Mention history with `/chatpilot mentions`.
- **Abbreviation tooltips** (LFG, WTS, LF2M, SM, BRD ...), **dims or hides messages in languages you can't read** (no translation - the server only sends scrambled text, and bypassing it is not allowed), **repeat-spam filter** for public channels.
- **Clickable links** with a copy box, **copy chat** button, and an **in-game feedback system** (`/chatpilot feedback`).
- Never sends messages on its own, no ads, no internet access, respects secret values. Free & open source (MIT).
