# Intervalltrainer

iOS-App für Intervallläufe: Pläne aus Phasen und Wiederholungsblöcken erstellen und sich während des Laufs per Sprachausgabe führen lassen. Die App läuft parallel zu Strava, misst Zeit und Strecke selbst über GPS und stoppt nie das Audio anderer Apps.

- Swift + SwiftUI, iOS 17 oder neuer, nur iPhone, keine externen Abhängigkeiten
- Gebaut wird ausschließlich über GitHub Actions, ein Mac ist nicht nötig
- Installation unter Windows mit Sideloadly und einer kostenlosen Apple-ID

> **Stand:** Der Code wurde ohne Mac geschrieben und bisher weder kompiliert noch auf einem iPhone getestet. Der erste GitHub-Build zeigt, ob noch Compile-Fehler zu beheben sind.

## Aufbau

```
project.yml                  XcodeGen-Beschreibung, daraus entsteht das Xcode-Projekt
Config/Info.plist            Berechtigungstexte, Background Modes
.github/workflows/build.yml  Tests, Build, unsignierte .ipa
Packages/IntervalCore/       Logik ohne iOS-Abhängigkeiten (Modell, Engine, Ansagetexte, GPS-Filter) + Unit-Tests
App/                         SwiftUI-Oberfläche, Sprachausgabe, Standort, Speicherung
```

Die Trainings-Engine kennt weder Uhr noch GPS. Sie bekommt Zeit, Strecke und Pace von außen und meldet Ereignisse zurück. Die Unit-Tests simulieren damit komplette Läufe ohne Gerät.

## 1. Repository auf GitHub anlegen

1. Auf [github.com](https://github.com) anmelden und oben rechts **+ › New repository** wählen.
2. Name z. B. `Intervalltrainer`, Sichtbarkeit **Public**, keine README und keine .gitignore anhaken, **Create repository**.
   In öffentlichen Repositories sind die macOS-Runner kostenlos. In privaten zählt jede macOS-Minute zehnfach gegen das Freikontingent.
3. In einem Terminal im Projektordner (`E:\claude\Intervalltrainer`) nacheinander ausführen. `DEIN-NAME` durch deinen GitHub-Benutzernamen ersetzen:

```bash
git init -b main
```

```bash
git add .
```

```bash
git commit -m "Intervalltrainer: erste Version"
```

```bash
git remote add origin https://github.com/DEIN-NAME/Intervalltrainer.git
```

```bash
git push -u origin main
```

Beim ersten Push öffnet Git ein Browserfenster für die GitHub-Anmeldung.

## 2. Workflow starten und .ipa herunterladen

1. Der Push startet den Workflow automatisch. Von Hand geht es unter **Actions › Build › Run workflow**.
2. Unter **Actions** den laufenden Build öffnen. Er dauert einige Minuten.
3. Ist der Build grün: auf der Seite des Laufs ganz unten unter **Artifacts** auf **Intervalltrainer-ipa** klicken. Dafür musst du bei GitHub angemeldet sein.
4. Die heruntergeladene ZIP-Datei entpacken. Darin liegt `Intervalltrainer.ipa`.

Ist der Build rot: den fehlgeschlagenen Schritt aufklappen und das Log kopieren (oder über das Zahnrad **Download log archive**). Mit dem Log lässt sich der Fehler beheben.

Das Artefakt wird nach 30 Tagen gelöscht. Danach den Workflow einfach erneut starten.

## 3. Mit Sideloadly installieren (Windows)

Einmalige Vorbereitung:

1. **iTunes** und **iCloud** direkt von der Apple-Website installieren, nicht aus dem Microsoft Store. Sideloadly braucht die darin enthaltenen Treiber; die Download-Links stehen auf der Sideloadly-Seite.
2. **Sideloadly** von [sideloadly.io](https://sideloadly.io) installieren.
3. iPhone per USB anschließen, entsperren und **Diesem Computer vertrauen** bestätigen.

Installation:

1. Sideloadly öffnen. Das iPhone erscheint unter **iDevice**.
2. `Intervalltrainer.ipa` in das Fenster ziehen.
3. Unter **Apple ID** deine Apple-ID eintragen und **Start** klicken. Sideloadly fragt nach dem Passwort und ggf. dem Code der Zwei-Faktor-Anmeldung und signiert die App mit einem kostenlosen 7-Tage-Zertifikat.
4. Warten, bis **Done** erscheint.

## 4. Auf dem iPhone freischalten

1. **Entwickler vertrauen:** Einstellungen › Allgemein › VPN & Geräteverwaltung › unter „Entwickler-App“ deine Apple-ID antippen › **Vertrauen**.
2. **Entwicklermodus** (ab iOS 16 nötig): Einstellungen › Datenschutz & Sicherheit › Entwicklermodus einschalten. Das iPhone startet neu, danach das Einschalten bestätigen. Der Punkt erscheint erst, nachdem eine App per Sideloading installiert wurde.
3. App öffnen. Beim ersten Lauf die Standortfrage mit **Beim Verwenden der App erlauben** beantworten und „Genauer Standort“ eingeschaltet lassen.

## 5. Alle 7 Tage neu signieren

Die Signatur einer kostenlosen Apple-ID gilt 7 Tage. Danach startet die App nicht mehr, bis sie neu signiert ist. Pläne und Einstellungen bleiben erhalten, wenn du die App nicht löschst.

- **Von Hand:** iPhone anschließen, dieselbe `.ipa` mit derselben Apple-ID erneut in Sideloadly installieren (Schritt 3). Die App wird überschrieben, die Daten bleiben.
- **Automatisch:** Bei der Installation in Sideloadly die Option für automatisches Erneuern aktiviert lassen. Der Sideloadly-Hintergrunddienst signiert dann neu, sobald PC und iPhone verbunden sind (USB oder gleiches WLAN mit aktivierter WLAN-Synchronisierung).

Grenzen der kostenlosen Apple-ID: höchstens 3 per Sideloading installierte Apps gleichzeitig pro Gerät und 10 neue App-IDs pro 7 Tage.

## Bedienung

- **Pläne:** Plus oben rechts legt einen Plan an oder fügt die Beispielvorlagen erneut hinzu. Wischen nach links löscht, Wischen nach rechts dupliziert, langes Drücken zeigt alle Aktionen.
- **Editor:** Phasen (Einlaufen, Belastung, Trabpause, Auslaufen) und Wiederholungsblöcke hinzufügen. Jede Phase hat entweder eine Zeit oder eine Strecke und optional eine Ziel-Pace als Bereich. Über „Bearbeiten“ lassen sich Einträge umsortieren.
- **Lauf:** Plan öffnen › **Lauf starten**. Die Laufansicht sucht schon vor dem Start nach GPS. Warte, bis „GPS gut“ angezeigt wird, und tippe dann auf **Start**. Strava kannst du vorher oder nachher starten.
- **Einstellungen:** Zahnrad oben links (Audio-Verhalten, Lautstärke, Stimme, Sprechgeschwindigkeit, Ansagetypen, Bildschirmsperre).

Ansagen:

| Ereignis | Beispiel |
|---|---|
| Phasenwechsel | „Intervall drei von sechs. Vierhundert Meter schnell. Ziel-Pace vier Minuten dreißig.“ |
| Halbzeit (Zeitphasen ab 1:00, Streckenphasen ab 400 m) | „Halbzeit. Noch zweihundert Meter.“ |
| Vorwarnung (Zeitphasen ab 0:20, Streckenphasen ab 150 m) | „Noch zehn Sekunden.“ / „Noch fünfzig Meter.“ |
| Countdown (Zeitphasen ab 0:10) | „drei“, „zwei“, „eins“ |
| Ziel-Pace | „Schneller.“ / „Langsamer.“ / „Pace passt.“ |
| Ende | „Training beendet. Fünf Komma zwei drei Kilometer in achtundzwanzig Minuten zehn. Durchschnitts-Pace …“ |

Pace-Hinweise kommen frühestens 20 Sekunden nach Phasenbeginn und höchstens im eingestellten Abstand (Standard 30 Sekunden).

## Änderungen einspielen

Code ändern, dann:

```bash
git add .
```

```bash
git commit -m "Beschreibung der Änderung"
```

```bash
git push
```

Der Workflow baut eine neue `.ipa`. Die Unit-Tests laufen dabei mit `swift test` direkt auf dem macOS-Runner.

## Bekannte Einschränkungen

- **Noch ungetestet:** Der Code ist bisher weder kompiliert noch auf einem Gerät gelaufen. Besonders das Verhalten im Hintergrund, das Absenken der Musik und die Darstellung auf kleinen iPhones müssen sich am Gerät zeigen.
- **7-Tage-Signatur:** Ohne bezahlten Developer-Account muss die App wöchentlich neu signiert werden.
- **App nicht beenden:** Wird die App während des Laufs aus dem App-Umschalter gewischt oder vom System beendet, ist der Lauf weg. Es gibt keine Wiederherstellung.
- **Start im Vordergrund:** Der Lauf muss bei geöffneter App gestartet werden. Danach läuft er bei gesperrtem Bildschirm weiter, iOS zeigt dabei den blauen Standort-Hinweis.
- **GPS-Genauigkeit:** Strecke und Pace weichen etwas von Strava ab. Punkte mit einer Genauigkeit schlechter als 25 m und Sprünge über 12 m/s werden verworfen. In Tunneln, Häuserschluchten oder dichtem Wald enden Streckenphasen dadurch später. Die Pace ist ein Mittel über etwa 15 Sekunden und reagiert entsprechend verzögert.
- **Ohne Standortzugriff** enden Streckenphasen nicht von selbst. Sie lassen sich dann nur überspringen.
- **Keine Laufhistorie, kein Export:** Die Zusammenfassung wird nach dem Schließen nicht gespeichert. Die Aufzeichnung übernimmt Strava.
- **Kein Auto-Pause:** Pausiert wird nur über den Button.
- **Audio:** Ansagen sind auch bei stummgeschaltetem iPhone zu hören. Während eines Telefonats können sie ausfallen. Die Qualität der Stimme hängt von den installierten iOS-Stimmen ab.
- **Planfortschritt** wird nach Schritten gezählt, nicht nach Zeit.
- **Abstand der Pace-Hinweise:** Eine Änderung in den Einstellungen gilt erst ab dem nächsten Lauf.
- Kein Querformat, kein iPad, keine Apple Watch, keine Herzfrequenz.
