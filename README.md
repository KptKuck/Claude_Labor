# BTCUSD Analyzer

Ein umfassendes MATLAB-GUI-Werkzeug zur Analyse von Bitcoin-Handelsdaten mit bidirektionalem LSTM (BILSTM) für die Vorhersage von Trendwechseln.

## Features

### 📊 Datenmanagement
- **Lokale CSV-Dateien**: Laden von BTCUSD-Handelsdaten aus lokalen Dateien
- **Binance API**: Download von Echtzeit-Daten mit verschiedenen Zeitintervallen (1h, 4h, 1d, 1w)
- **Datum & Intervall**: Flexible Datumswahl mit Quick-Buttons (+/- Tag, Woche, Monat, Jahr)

### 📈 Datenanalyse
- **Visualisierung**: Preisverlauf mit Tages-Extrema und Moving Averages
- **Extrema-Erkennung**: Automatische Identifikation von täglichen Hochs und Tiefs
- **Statistiken**: Grundlegende Volatilitäts- und Preismetriken

### 🤖 BILSTM Training
- **Trainingsdatenvorbereitung**: Automatische Generierung von Sequenzen und Labels
- **Parameter-Kontrolle**: Epochen, Batch-Size, Hidden Units, Learning Rate
- **GPU/CPU Support**: Flexible Auswahl zwischen GPU und CPU-Training
- **Modell-Speicherung**: Trainierte Modelle als .mat-Dateien speichern

### 🔮 Vorhersage
- **Trendwechsel-Erkennung**: BUY/SELL/HOLD Signale basierend auf BILSTM
- **Modell-Laden**: Laden vortrainierter Modelle
- **Live-Vorhersagen**: Vorhersagen auf aktuellen Daten

### 📝 Logging
- **Detailliertes Logging**: Alle Aktionen werden dokumentiert
- **Flexible Log-Modi**: Fenster-Only, Datei-Only oder beides
- **Farbcodierung**: Farben für Info, Success, Warning, Error
- **HTML-Logger**: Formatierte Anzeige mit einstellbarer Schriftgröße (8-16pt)

## Systemanforderungen

### Software
- **MATLAB R2021a oder neuer**
- **Deep Learning Toolbox**
- **Signal Processing Toolbox**
- **Parallel Computing Toolbox** (optional, für GPU-Support)

### Hardware (optional)
- NVIDIA GPU mit CUDA-Support (für GPU-Training)
- Mind. 4GB RAM für Datenvorbereitung
- Internet für Binance API Download

## Installation

### 1. Repository klonen
```bash
git clone https://github.com/yourusername/btc-analyzer.git
cd btc-analyzer
```

### 2. MATLAB öffnen
- Navigiere zum Projektverzeichnis
- Öffne `btc_analyzer_gui.m`

### 3. GUI starten
```matlab
btc_analyzer_gui()
```

## Dateistruktur

```
btc-analyzer/
├── btc_analyzer_gui.m              # Hauptgui (Einstiegspunkt)
├── read_btc_data.m                 # CSV-Daten einlesen
├── download_btc_data.m             # Binance API Download
├── find_daily_extrema.m            # Tages-Extrema finden
├── prepare_training_data.m         # Trainingsdaten vorbereiten
├── prepare_training_data_gui.m     # Trainingsdaten-Vorbereitungs-GUI
├── train_bilstm_model.m            # BILSTM Trainingslogik
├── visualize_training_signals.m    # Visualisierungs-GUI
├── main.m                          # Beispiel-Analyseskript
├── run_bilstm_training.m           # Eigenständiges Training-Skript
├── README.md                       # Diese Datei
├── .gitignore                      # Git Ignore Rules
└── python1/                        # Python-Varianten (optional)
    ├── download_btc_data.py
    ├── prepare_training_data.py
    ├── train_bilstm_model.py
    ├── visualize_training_data_gui.py
    └── requirements.txt
```

## Verwendung

### 1. Daten laden
Wählen Sie eine der beiden Optionen:
- **Lokale Datei**: CSV-Datei öffnen
- **Binance Download**: Datum & Intervall wählen → Download

### 2. Datenanalyse
- **Analysieren**: Erstellt Diagramme mit Preisverlauf und Extrema
- **Training vorbereiten**: Öffnet GUI für Trainingsdaten-Generierung

### 3. BILSTM Training
1. Training vorbereiten (erzeugt Sequenzen)
2. Parameter einstellen (Epochen, Batch, Hidden Units, Learning Rate)
3. CPU/GPU wählen
4. **Training starten** → Modell wird trainiert und kann gespeichert werden

### 4. Vorhersage
1. Modell laden (oder trainiertes Modell verwenden)
2. **Vorhersage** → Zeigt BUY/SELL/HOLD für aktuelle Sequenz

## Datenfluss

```
CSV/API
   ↓
read_btc_data / download_btc_data
   ↓
app_data (Table: DateTime, OHLC)
   ├→ analyzeData() → Visualisierungen
   └→ prepareTrainingData() → find_daily_extrema()
      ↓
      training_data (X_train, Y_train, info)
      ↓
      train_bilstm_model()
      ↓
      trained_model + training_results
      ↓
      makePrediction() → BUY/SELL/HOLD
```

## Kategorisierung der Signale

- **0 = HOLD**: Normale Preisbewegungen (Standard)
- **1 = BUY**: Punkt ist ein erkanntes Tages-Tief
- **2 = SELL**: Punkt ist ein erkanntes Tages-Hoch

## Logger-Modi

1. **Fenster**: Nur GUI-Anzeige mit HTML-Formatter
2. **Fenster + Datei** (Standard): Beides, Log-Datei mit Zeitstempel
3. **Nur Datei**: Nur in Datei speichern

Log-Dateien werden in `log/` erstellt mit Format: `btc_analyzer_YYYY-MM-DD_HH-MM-SS.txt`

## Ordnerstruktur (wird automatisch erstellt)

```
project/
├── Daten_csv/     # Exportierte CSV-Daten
├── log/           # Log-Dateien
└── Network/       # Trainierte Modelle (.mat)
```

## Tipps & Tricks

### Performance
- Für große Datenmengen (>100k Punkte) GPU-Modus verwenden
- Batch-Size auf GPU mit 64+ experimentieren
- Learning Rate bei längeren Trainings senken (0.0001-0.0005)

### Datenqualität
- Mindestens 100 Tage Daten für aussagekräftiges Training
- Lookback 5%, Lookforward 20% sind gute Standard-Werte
- Validation Split von 20% empfohlen

### Modellspeicherung
- Modelle werden mit Metadaten gespeichert (training_info, training_results)
- Können jederzeit wieder geladen werden
- Format: `BILSTM_YYYY-MM-DD_HH-MM-SS.mat`

## GPU-Support

### Aktivieren
1. GPU-Schalter auf "GPU" setzen
2. System prüft automatisch GPU-Verfügbarkeit
3. CUDA Forward Compatibility wird aktiviert (für neuere GPUs)

### Fehlerbehandlung
- Bei GPU-Fehler wird automatisch auf CPU ausgewichen
- Alle GPU-Informationen werden im Logger angezeigt

## Python-Varianten

Optional: Verwenden Sie die Python-Implementierungen in `python1/`:
```bash
cd python1
pip install -r requirements.txt
python train_bilstm_model.py
```

## Bekannte Einschränkungen

- Binance API hat Rate Limits (bei vielen Anfragen hintereinander)
- BILSTM-Training benötigt genug RAM bei großen Sequenzen
- GPU-Support nur für NVIDIA (mit CUDA)

## Lizenz

MIT License

## Support

Bei Fragen oder Problemen:
1. Log-Dateien in `log/` überprüfen
2. Logger-Modus auf "Fenster + Datei" setzen
3. Console-Fehler in MATLAB überprüfen

## Changelog

### v1.0 (Initial Release)
- GUI-Interface mit Logger
- CSV und Binance Download
- BILSTM Training und Vorhersage
- GPU/CPU Support
- Umfassendes Logging

---

**Developed with ❤️ for Bitcoin Analysis**
