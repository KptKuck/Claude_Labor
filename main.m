% MAIN - Hauptskript zur Analyse von BTCUSD-Daten
%
% Dieses Skript lädt Bitcoin-Handelsdaten ein und führt
% grundlegende Analysen und Visualisierungen durch.

clear;
clc;
close all;

%% 1. Daten einlesen
fprintf('=== Bitcoin Trading Daten Analyse ===\n\n');

filename = 'BTCUSD_H1_202509250000_202512311700.csv';
data = read_btc_data(filename);

%% 2. Grundlegende Statistiken
fprintf('\n--- Datenübersicht ---\n');
fprintf('Zeitraum: %s bis %s\n', datestr(data.DateTime(1)), datestr(data.DateTime(end)));
fprintf('Anzahl Datenpunkte: %d\n', height(data));

fprintf('\n--- Preis-Statistiken ---\n');
fprintf('Höchster Preis:  %.2f\n', max(data.High));
fprintf('Niedrigster Preis: %.2f\n', min(data.Low));
fprintf('Durchschnittspreis: %.2f\n', mean(data.Close));
fprintf('Schlusskurs (letzter): %.2f\n', data.Close(end));

%% 3. Preisbewegungen berechnen
data.PriceChange = [0; diff(data.Close)];
data.PriceChangePercent = [0; (diff(data.Close) ./ data.Close(1:end-1)) * 100];

fprintf('\n--- Volatilität ---\n');
fprintf('Größter Anstieg: %.2f (%.2f%%)\n', max(data.PriceChange), max(data.PriceChangePercent));
fprintf('Größter Rückgang: %.2f (%.2f%%)\n', min(data.PriceChange), min(data.PriceChangePercent));
fprintf('Standardabweichung: %.2f\n', std(data.Close));

%% 4. Visualisierung
figure('Name', 'BTCUSD Analyse', 'Position', [100, 100, 1200, 600]);

% Plot 1: Candlestick Chart mit Tages-Extrema
subplot(2, 1, 1);
plot(data.DateTime, data.Close, 'b-', 'LineWidth', 1.5);
hold on;
plot(data.DateTime, data.High, 'g--', 'LineWidth', 0.5);
plot(data.DateTime, data.Low, 'r--', 'LineWidth', 0.5);
grid on;
xlabel('Datum');
ylabel('Preis (USD)');
title('BTCUSD Preisverlauf (H1) mit Tages-Extrema');
legend('Close', 'High', 'Low', 'Location', 'best');

% Plot 2: Prozentuale Preisänderung
subplot(2, 1, 2);
bar(data.DateTime, data.PriceChangePercent, 'FaceColor', [0.8, 0.4, 0.2]);
grid on;
xlabel('Datum');
ylabel('Änderung (%)');
title('Stündliche Preisänderung in %');

%% 5. Tages-Extrema finden und markieren
fprintf('\n--- Tages-Extrema ---\n');
[high_points, low_points] = find_daily_extrema(data);

% Extrema im ersten Plot markieren
figure(1);
subplot(2, 1, 1);
% Hochpunkte markieren
high_times = [high_points.DateTime];
high_prices = [high_points.Price];
plot(high_times, high_prices, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', 'Tages-Hoch');

% Tiefpunkte markieren
low_times = [low_points.DateTime];
low_prices = [low_points.Price];
plot(low_times, low_prices, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'Tages-Tief');

legend('Close', 'High', 'Low', 'Tages-Hoch', 'Tages-Tief', 'Location', 'best');
hold off;

%% 6. Zusätzliche Analyse: Moving Averages
window_short = 24;  % 24 Stunden (1 Tag)
window_long = 168;  % 168 Stunden (1 Woche)

if height(data) >= window_long
    data.MA_Short = movmean(data.Close, window_short);
    data.MA_Long = movmean(data.Close, window_long);

    figure('Name', 'Moving Averages', 'Position', [150, 150, 1000, 500]);
    plot(data.DateTime, data.Close, 'b-', 'LineWidth', 1);
    hold on;
    plot(data.DateTime, data.MA_Short, 'g-', 'LineWidth', 2);
    plot(data.DateTime, data.MA_Long, 'r-', 'LineWidth', 2);
    grid on;
    xlabel('Datum');
    ylabel('Preis (USD)');
    title('BTCUSD mit Moving Averages');
    legend('Close', sprintf('MA %dh', window_short), sprintf('MA %dh', window_long), 'Location', 'best');
end

%% 7. Ergebnisse speichern (optional)
fprintf('\n--- Analyse abgeschlossen ---\n');
fprintf('Diagramme wurden erstellt.\n');

% Optional: Daten mit berechneten Werten exportieren
% writetable(data, 'btc_analysis_results.csv');
