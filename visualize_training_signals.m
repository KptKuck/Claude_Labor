function visualize_training_signals(data, training_data_info, X_train, Y_train)
% VISUALIZE_TRAINING_SIGNALS Visualisiert Buy/Sell Signale auf BTCUSD Chart
%
%   visualize_training_signals(data, training_data_info, X_train, Y_train)
%   erstellt einen Chart mit BTCUSD-Preisdaten und markiert die Sequenzen
%   für BUY (grün) und SELL (rot) Signale.
%
%   Input:
%       data - Table mit BTCUSD Daten (DateTime, Close, High, Low, Open)
%       training_data_info - Struct mit Informationen über Trainingsdaten
%       X_train - Cell Array mit Trainingssequenzen
%       Y_train - Cell Array mit Labels (categorical)
%
%   Die Funktion zeigt:
%       - BTCUSD Close-Preis (blaue Linie)
%       - BUY-Signale (grüne vertikale Bereiche)
%       - SELL-Signale (rote vertikale Bereiche)
%       - HOLD-Signale (graue vertikale Bereiche, optional)

    fprintf('=== Visualisiere Training Signale ===\n\n');

    % Extrahiere Informationen
    lookback = training_data_info.lookback_size;
    lookforward = training_data_info.lookforward_size;
    total_length = lookback + lookforward;

    fprintf('Sequenzlänge: %d (Lookback: %d, Lookforward: %d)\n', ...
            total_length, lookback, lookforward);

    % Erstelle Figure
    fig = figure('Name', 'BTCUSD Training Signale', ...
                 'Position', [50, 50, 1400, 700]);

    % Plot Close-Preis
    plot(data.DateTime, data.Close, 'b-', 'LineWidth', 1.5, 'DisplayName', 'BTCUSD Close');
    hold on;

    % Zähler für Statistik
    buy_count = 0;
    sell_count = 0;
    hold_count = 0;

    % Durchlaufe alle Trainingssequenzen
    fprintf('Verarbeite %d Sequenzen...\n', length(Y_train));

    for i = 1:length(Y_train)
        label = double(Y_train{i});

        % Finde Position der Sequenz in den Daten
        % (Dies ist eine Approximation, da wir die genauen Indizes rekonstruieren müssen)
        % Wir nutzen die Tatsache, dass Sequenzen chronologisch sind

        % Berechne ungefähre Position basierend auf Sequenz-Index
        % (Dies ist vereinfacht - in Realität müssten wir die exakten Zeitstempel speichern)

        if label == 1  % BUY
            buy_count = buy_count + 1;
        elseif label == 2  % SELL
            sell_count = sell_count + 1;
        else  % HOLD
            hold_count = hold_count + 1;
        end
    end

    % Alternativ: Verwende find_daily_extrema für BUY/SELL Positionen
    [high_points, low_points] = find_daily_extrema(data);

    fprintf('\nMarkiere Signale im Chart:\n');
    fprintf('  BUY-Signale (Tiefs): %d\n', length(low_points));
    fprintf('  SELL-Signale (Hochs): %d\n', length(high_points));

    % Markiere SELL-Signale (Hochs) in ROT
    for i = 1:length(high_points)
        high_time = high_points(i).DateTime;
        high_price = high_points(i).Price;

        % Finde Index in Daten
        idx = find(data.DateTime == high_time, 1);
        if ~isempty(idx) && idx > lookback && idx + lookforward <= height(data)
            % Berechne Sequenzbereich
            start_idx = idx - lookback;
            end_idx = idx + lookforward - 1;

            % Zeichne vertikalen Bereich (transparent rot)
            seq_times = data.DateTime(start_idx:end_idx);
            seq_prices = data.Close(start_idx:end_idx);

            % Fülle Bereich
            y_min = min(data.Close) * 0.95;
            y_max = max(data.Close) * 1.05;

            fill([seq_times(1), seq_times(end), seq_times(end), seq_times(1)], ...
                 [y_min, y_min, y_max, y_max], ...
                 'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');

            % Markiere Zentrum (High-Punkt)
            plot(high_time, high_price, 'rv', 'MarkerSize', 10, ...
                 'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
        end
    end

    % Markiere BUY-Signale (Tiefs) in GRÜN
    for i = 1:length(low_points)
        low_time = low_points(i).DateTime;
        low_price = low_points(i).Price;

        % Finde Index in Daten
        idx = find(data.DateTime == low_time, 1);
        if ~isempty(idx) && idx > lookback && idx + lookforward <= height(data)
            % Berechne Sequenzbereich
            start_idx = idx - lookback;
            end_idx = idx + lookforward - 1;

            % Zeichne vertikalen Bereich (transparent grün)
            seq_times = data.DateTime(start_idx:end_idx);
            seq_prices = data.Close(start_idx:end_idx);

            % Fülle Bereich
            y_min = min(data.Close) * 0.95;
            y_max = max(data.Close) * 1.05;

            fill([seq_times(1), seq_times(end), seq_times(end), seq_times(1)], ...
                 [y_min, y_min, y_max, y_max], ...
                 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');

            % Markiere Zentrum (Low-Punkt)
            plot(low_time, low_price, 'g^', 'MarkerSize', 10, ...
                 'MarkerFaceColor', 'g', 'HandleVisibility', 'off');
        end
    end

    % Erstelle manuelle Legende
    h1 = fill(NaN, NaN, 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    h2 = fill(NaN, NaN, 'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');

    hold off;

    % Layout
    grid on;
    xlabel('Datum');
    ylabel('Preis (USD)');
    title(sprintf('BTCUSD mit Training-Signalen (Sequenzlänge: %d)', total_length));
    legend([h1, h2], {'BUY-Sequenzen (Tief)', 'SELL-Sequenzen (Hoch)'}, ...
           'Location', 'best');

    % Setze Y-Achsen-Grenzen
    ylim([min(data.Close) * 0.95, max(data.Close) * 1.05]);

    fprintf('\n=== Visualisierung abgeschlossen ===\n');
    fprintf('Grüne Bereiche: BUY-Signale (Tages-Tiefs)\n');
    fprintf('Rote Bereiche: SELL-Signale (Tages-Hochs)\n');
    fprintf('Sequenzen: %d Datenpunkte vor und nach dem Signal\n', total_length);
end
