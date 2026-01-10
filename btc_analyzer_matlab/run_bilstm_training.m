% RUN_BILSTM_TRAINING - Hauptskript für BILSTM Training
%
% Dieses Skript führt den kompletten Workflow aus:
% 1. Daten laden
% 2. Trainingsdaten vorbereiten
% 3. BILSTM Netzwerk trainieren
% 4. Modell speichern

clear;
clc;
close all;

fprintf('╔════════════════════════════════════════════════╗\n');
fprintf('║   BILSTM Trendwechsel-Erkennung Training      ║\n');
fprintf('╚════════════════════════════════════════════════╝\n\n');

%% 1. Daten laden
fprintf('SCHRITT 1: Daten laden\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

filename = 'BTCUSD_H1_202509250000_202512311700.csv';

if ~isfile(filename)
    error('Datei nicht gefunden: %s', filename);
end

data = read_btc_data(filename);

fprintf('\n✓ Daten erfolgreich geladen\n');
fprintf('  Zeitraum: %s bis %s\n', ...
        datestr(data.DateTime(1)), datestr(data.DateTime(end)));

%% 2. Trainingsdaten vorbereiten
fprintf('\n\nSCHRITT 2: Trainingsdaten vorbereiten\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Parameter:
% - 5% Lookback (Daten VOR dem Ereignis)
% - 20% Lookforward (Daten NACH dem Ereignis)
[X_train, Y_train, training_info] = prepare_training_data(data, ...
    'lookback_percent', 5, ...
    'lookforward_percent', 20);

fprintf('\n✓ Trainingsdaten vorbereitet\n');

%% 3. Klassenverteilung visualisieren
fprintf('\n\nSCHRITT 3: Datenanalyse\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Zähle Labels
labels_array = zeros(length(Y_train), 1);
for i = 1:length(Y_train)
    labels_array(i) = double(Y_train{i});
end

figure('Name', 'Klassenverteilung', 'Position', [100, 100, 800, 400]);
histogram(categorical(labels_array, [0, 1, 2], training_info.classes));
title('Verteilung der Trainingsklassen');
xlabel('Klasse');
ylabel('Anzahl');
grid on;

fprintf('\nKlassenverteilung:\n');
for i = 1:3
    count = sum(labels_array == (i-1));
    percentage = (count / length(labels_array)) * 100;
    fprintf('  %s: %d (%.1f%%)\n', training_info.classes{i}, count, percentage);
end

%% 4. BILSTM Netzwerk trainieren
fprintf('\n\nSCHRITT 4: BILSTM Netzwerk trainieren\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Training starten
[net, training_results] = train_bilstm_model(X_train, Y_train, training_info, ...
    'epochs', 50, ...
    'validation_split', 0.2, ...
    'batch_size', 32);

fprintf('\n✓ Training abgeschlossen\n');

%% 5. Modell speichern
fprintf('\n\nSCHRITT 5: Modell speichern\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% Timestamp für Dateinamen
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
model_filename = sprintf('bilstm_trendwechsel_%s.mat', timestamp);

% Speichere Modell und Metadaten
save(model_filename, 'net', 'training_info', 'training_results');

fprintf('✓ Modell gespeichert: %s\n', model_filename);

%% 6. Zusammenfassung
fprintf('\n\n╔════════════════════════════════════════════════╗\n');
fprintf('║              TRAINING ABGESCHLOSSEN            ║\n');
fprintf('╚════════════════════════════════════════════════╝\n\n');

fprintf('Modell-Details:\n');
fprintf('  Netzwerk-Typ: BILSTM mit 100 Neuronen\n');
fprintf('  Klassen: %s\n', strjoin(training_info.classes, ', '));
fprintf('  Trainingsbeispiele: %d\n', training_info.total_sequences);
fprintf('  Sequenzlänge: %d Zeitpunkte\n', training_info.sequence_length);
fprintf('  Features: %d\n', training_info.num_features);
fprintf('\n');
fprintf('Performance:\n');
fprintf('  Training Accuracy: %.2f%%\n', training_results.train_accuracy);
fprintf('  Validation Accuracy: %.2f%%\n', training_results.val_accuracy);
fprintf('  Trainingszeit: %.2f Minuten\n', training_results.training_time / 60);
fprintf('\n');
fprintf('Gespeichert als: %s\n', model_filename);
fprintf('\n');

%% 7. Visualisierung der Confusion Matrix
figure('Name', 'Confusion Matrix', 'Position', [200, 200, 600, 500]);
cm = training_results.confusion_matrix;
confusionchart(cm, training_info.classes);
title('Confusion Matrix (Validation Set)');

fprintf('Training erfolgreich abgeschlossen!\n');
fprintf('\nNächste Schritte:\n');
fprintf('  1. Modell laden: load(''%s'')\n', model_filename);
fprintf('  2. Vorhersagen: predictions = classify(net, new_data)\n');
fprintf('  3. Modell testen mit neuen Daten\n');
