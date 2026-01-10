function [high_points, low_points] = find_daily_extrema(data)
% FIND_DAILY_EXTREMA Findet Hochpunkte und Tiefpunkte pro Tag
%
%   [high_points, low_points] = FIND_DAILY_EXTREMA(data) analysiert die
%   Handelsdaten und identifiziert für jeden Tag den höchsten und
%   niedrigsten Punkt.
%
%   Input:
%       data - Table mit DateTime, High und Low Spalten
%
%   Output:
%       high_points - Struct Array mit Feldern:
%                     .DateTime - Zeitpunkt des Hochs
%                     .Price - Höchster Preis
%                     .Date - Datum
%       low_points  - Struct Array mit Feldern:
%                     .DateTime - Zeitpunkt des Tiefs
%                     .Price - Niedrigster Preis
%                     .Date - Datum

    % Extrahiere nur das Datum (ohne Uhrzeit)
    dates = dateshift(data.DateTime, 'start', 'day');
    unique_dates = unique(dates);

    % Initialisiere Arrays für Ergebnisse
    num_days = length(unique_dates);
    high_points = struct('DateTime', cell(num_days, 1), ...
                         'Price', cell(num_days, 1), ...
                         'Date', cell(num_days, 1));
    low_points = struct('DateTime', cell(num_days, 1), ...
                        'Price', cell(num_days, 1), ...
                        'Date', cell(num_days, 1));

    % Für jeden Tag die Extrema finden
    for i = 1:num_days
        % Indizes für aktuellen Tag
        day_mask = dates == unique_dates(i);
        day_data = data(day_mask, :);

        % Hochpunkt finden
        [max_price, max_idx] = max(day_data.High);
        high_points(i).DateTime = day_data.DateTime(max_idx);
        high_points(i).Price = max_price;
        high_points(i).Date = unique_dates(i);

        % Tiefpunkt finden
        [min_price, min_idx] = min(day_data.Low);
        low_points(i).DateTime = day_data.DateTime(min_idx);
        low_points(i).Price = min_price;
        low_points(i).Date = unique_dates(i);
    end

    fprintf('Gefunden: %d Tages-Hochpunkte und %d Tages-Tiefpunkte\n', ...
            num_days, num_days);
end
