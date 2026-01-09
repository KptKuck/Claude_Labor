function [X_train, Y_train, training_info] = prepare_training_data(data, varargin)
% PREPARE_TRAINING_DATA Erstellt Trainingsdaten für BILSTM Trendwechsel-Erkennung
%
%   [X_train, Y_train, training_info] = PREPARE_TRAINING_DATA(data)
%   bereitet Trainingsdaten vor, um Trendwechsel anhand von Tages-Hochs
%   und Tiefs zu erkennen.
%
%   Input:
%       data - Table mit DateTime, Open, High, Low, Close Spalten
%       varargin - Optional: 'lookback_percent', wert (default: 5)
%                           'lookforward_percent', wert (default: 20)
%
%   Output:
%       X_train - Cell Array mit Sequenzen (Features) für Training
%       Y_train - Cell Array mit Labels (1=Buy bei Tief, 2=Sell bei Hoch, 0=Hold)
%       training_info - Struct mit Informationen über den Datensatz
%
%   Kategorisierung:
%       - Tages-Tief  -> BUY  (Label: 1)
%       - Tages-Hoch  -> SELL (Label: 2)
%       - Sonstiges   -> HOLD (Label: 0)
%
%   Sequenzlänge:
%       - 5% der Datenpunkte VOR dem Ereignis (lookback)
%       - 20% der Datenpunkte NACH dem Ereignis (lookforward)
%
%   Beispiel:
%       data = read_btc_data('BTCUSD_H1_202509250000_202512311700.csv');
%       [X, Y, info] = prepare_training_data(data);

    % Default Parameter
    p = inputParser;
    addParameter(p, 'lookback_percent', 5, @isnumeric);
    addParameter(p, 'lookforward_percent', 20, @isnumeric);
    parse(p, varargin{:});

    lookback_pct = p.Results.lookback_percent;
    lookforward_pct = p.Results.lookforward_percent;

    fprintf('=== Trainingsdaten-Vorbereitung für BILSTM ===\n\n');

    %% 1. Tages-Extrema finden
    fprintf('Schritt 1: Finde Tages-Hochs und Tiefs...\n');
    [high_points, low_points] = find_daily_extrema(data);

    num_highs = length(high_points);
    num_lows = length(low_points);
    fprintf('  Gefunden: %d Hochs, %d Tiefs\n', num_highs, num_lows);

    %% 2. Sequenzlängen berechnen
    total_points = height(data);
    lookback_size = round(total_points * (lookback_pct / 100));
    lookforward_size = round(total_points * (lookforward_pct / 100));
    sequence_length = lookback_size + lookforward_size;

    fprintf('\nSchritt 2: Sequenzparameter\n');
    fprintf('  Gesamtdatenpunkte: %d\n', total_points);
    fprintf('  Lookback (%.1f%%): %d Datenpunkte\n', lookback_pct, lookback_size);
    fprintf('  Lookforward (%.1f%%): %d Datenpunkte\n', lookforward_pct, lookforward_size);
    fprintf('  Gesamte Sequenzlänge: %d Datenpunkte\n', sequence_length);

    %% 3. Erstelle Index-Mapping für schnellen Zugriff
    datetime_to_idx = containers.Map();
    for i = 1:height(data)
        datetime_to_idx(char(data.DateTime(i))) = i;
    end

    %% 4. Extrahiere Features (Preis-Daten normalisiert)
    fprintf('\nSchritt 3: Extrahiere Features...\n');

    % Features: Close, High, Low, Open (normalisiert)
    close_prices = data.Close;
    high_prices = data.High;
    low_prices = data.Low;
    open_prices = data.Open;

    % Zusätzliche Features berechnen
    price_change = [0; diff(close_prices)];
    price_change_pct = [0; (diff(close_prices) ./ close_prices(1:end-1)) * 100];

    % Kombiniere alle Features
    features = [close_prices, high_prices, low_prices, open_prices, ...
                price_change, price_change_pct];

    fprintf('  Features pro Zeitpunkt: %d\n', size(features, 2));

    %% 5. Erstelle Trainingssequenzen
    fprintf('\nSchritt 4: Erstelle Trainingssequenzen...\n');

    X_train = {};
    Y_train = {};
    sequence_counter = 0;

    % Verarbeite alle SELL-Signale (Hochs)
    for i = 1:num_highs
        high_time = high_points(i).DateTime;
        key = char(high_time);

        if isKey(datetime_to_idx, key)
            idx = datetime_to_idx(key);

            % Prüfe ob genug Daten vor und nach dem Punkt
            if idx > lookback_size && idx + lookforward_size <= total_points
                % Extrahiere Sequenz
                start_idx = idx - lookback_size;
                end_idx = idx + lookforward_size - 1;

                sequence = features(start_idx:end_idx, :);

                % Normalisiere Sequenz (Z-Score)
                sequence_norm = normalize(sequence, 'zscore');

                % Speichere als Cell
                X_train{end+1} = sequence_norm';  % Transponieren für LSTM Format
                Y_train{end+1} = categorical(2);  % Label: 2 = SELL

                sequence_counter = sequence_counter + 1;
            end
        end
    end

    num_sell_sequences = sequence_counter;

    % Verarbeite alle BUY-Signale (Tiefs)
    for i = 1:num_lows
        low_time = low_points(i).DateTime;
        key = char(low_time);

        if isKey(datetime_to_idx, key)
            idx = datetime_to_idx(key);

            % Prüfe ob genug Daten vor und nach dem Punkt
            if idx > lookback_size && idx + lookforward_size <= total_points
                % Extrahiere Sequenz
                start_idx = idx - lookback_size;
                end_idx = idx + lookforward_size - 1;

                sequence = features(start_idx:end_idx, :);

                % Normalisiere Sequenz
                sequence_norm = normalize(sequence, 'zscore');

                % Speichere als Cell
                X_train{end+1} = sequence_norm';
                Y_train{end+1} = categorical(1);  % Label: 1 = BUY

                sequence_counter = sequence_counter + 1;
            end
        end
    end

    num_buy_sequences = sequence_counter - num_sell_sequences;

    %% 6. Erstelle negative Beispiele (HOLD - kein Trendwechsel)
    fprintf('\nSchritt 5: Erstelle negative Beispiele (HOLD)...\n');

    % Sammle alle Extrema-Indizes
    extrema_indices = [];
    for i = 1:num_highs
        key = char(high_points(i).DateTime);
        if isKey(datetime_to_idx, key)
            extrema_indices(end+1) = datetime_to_idx(key);
        end
    end
    for i = 1:num_lows
        key = char(low_points(i).DateTime);
        if isKey(datetime_to_idx, key)
            extrema_indices(end+1) = datetime_to_idx(key);
        end
    end

    % Erstelle gleich viele HOLD-Beispiele wie BUY+SELL zusammen
    num_hold_samples = num_buy_sequences + num_sell_sequences;
    hold_counter = 0;
    max_attempts = num_hold_samples * 100;  % Maximal 100x mehr Versuche
    attempts = 0;

    % Zufällige Punkte wählen, die NICHT Extrema sind
    rng(42);  % Für Reproduzierbarkeit
    while hold_counter < num_hold_samples && attempts < max_attempts
        attempts = attempts + 1;
        rand_idx = randi([lookback_size + 1, total_points - lookforward_size]);

        % Prüfe ob es KEIN Extremum ist (mit Abstand)
        min_distance = round(sequence_length / 2);
        is_far_from_extrema = all(abs(extrema_indices - rand_idx) > min_distance);

        if is_far_from_extrema
            start_idx = rand_idx - lookback_size;
            end_idx = rand_idx + lookforward_size - 1;

            sequence = features(start_idx:end_idx, :);
            sequence_norm = normalize(sequence, 'zscore');

            X_train{end+1} = sequence_norm';
            Y_train{end+1} = categorical(0);  % Label: 0 = HOLD

            hold_counter = hold_counter + 1;
        end
    end

    % Warnung wenn nicht genug HOLD-Samples gefunden wurden
    if hold_counter < num_hold_samples
        warning('Nur %d von %d HOLD-Samples erstellt (nach %d Versuchen)', ...
                hold_counter, num_hold_samples, attempts);
    end

    %% 7. Konvertiere zu Column Cell Arrays
    X_train = X_train';
    Y_train = Y_train';

    %% 8. Zusammenfassung und Info
    fprintf('\n=== Trainingsdaten erstellt ===\n');
    fprintf('Anzahl BUY-Sequenzen (Tief):  %d\n', num_buy_sequences);
    fprintf('Anzahl SELL-Sequenzen (Hoch): %d\n', num_sell_sequences);
    fprintf('Anzahl HOLD-Sequenzen:        %d\n', hold_counter);
    fprintf('Gesamt Trainingsbeispiele:    %d\n', length(X_train));
    fprintf('\nSequenzlänge: %d Zeitpunkte\n', sequence_length);
    fprintf('Features pro Zeitpunkt: %d\n', size(features, 2));

    % Training Info Struct
    training_info = struct();
    training_info.total_sequences = length(X_train);
    training_info.num_buy = num_buy_sequences;
    training_info.num_sell = num_sell_sequences;
    training_info.num_hold = hold_counter;
    training_info.sequence_length = sequence_length;
    training_info.lookback_size = lookback_size;
    training_info.lookforward_size = lookforward_size;
    training_info.num_features = size(features, 2);
    training_info.feature_names = {'Close', 'High', 'Low', 'Open', ...
                                   'PriceChange', 'PriceChangePct'};
    training_info.classes = {'HOLD', 'BUY', 'SELL'};

    fprintf('\nTrainingsdaten bereit für BILSTM Netzwerk!\n');
end
