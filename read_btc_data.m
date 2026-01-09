function data = read_btc_data(filename)
% READ_BTC_DATA Liest BTCUSD CSV-Datei ein
%
%   data = READ_BTC_DATA(filename) liest die angegebene CSV-Datei mit
%   Bitcoin-Handelsdaten ein und gibt eine strukturierte Table zurück.
%
%   Input:
%       filename - Pfad zur CSV-Datei (String)
%
%   Output:
%       data - Table mit folgenden Spalten:
%              Date, Time, Open, High, Low, Close, TickVol, Vol, Spread
%
%   Beispiel:
%       data = read_btc_data('BTCUSD_H1_202509250000_202512311700.csv');
%       disp(data(1:5,:));

    % Überprüfen ob Datei existiert
    if ~isfile(filename)
        error('Datei nicht gefunden: %s', filename);
    end

    % CSV-Datei einlesen mit Tab als Delimiter
    opts = delimitedTextImportOptions('NumVariables', 9, ...
        'Delimiter', '\t', ...
        'DataLines', 2, ...  % Starte ab Zeile 2 (überspringe Header)
        'VariableNamesLine', 1);

    % Variablennamen und -typen definieren
    opts.VariableNames = {'Date', 'Time', 'Open', 'High', 'Low', ...
                          'Close', 'TickVol', 'Vol', 'Spread'};

    % Variablentypen festlegen
    opts.VariableTypes = {'datetime', 'string', 'double', 'double', ...
                          'double', 'double', 'double', 'double', 'double'};

    % Datetime-Format für Date-Spalte
    opts = setvaropts(opts, 'Date', 'InputFormat', 'yyyy.MM.dd');

    % Daten einlesen
    data = readtable(filename, opts);

    % Time-String zu Duration konvertieren
    data.Time = duration(data.Time, 'InputFormat', 'hh:mm:ss');

    % DateTime und Time zu einer Spalte kombinieren
    data.DateTime = data.Date + data.Time;

    % Spalten neu anordnen (DateTime an erste Stelle)
    data = movevars(data, 'DateTime', 'Before', 1);

    fprintf('Erfolgreich %d Datensätze eingelesen.\n', height(data));
end
