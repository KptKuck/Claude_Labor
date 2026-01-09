function data = download_btc_data(start_date, end_date, interval, varargin)
% DOWNLOAD_BTC_DATA Lädt BTCUSD-Daten aus dem Internet
%
%   data = DOWNLOAD_BTC_DATA(start_date, end_date, interval) lädt
%   Bitcoin-Handelsdaten von einer öffentlichen API für den angegebenen
%   Zeitraum und das Intervall.
%
%   Input:
%       start_date - Startdatum (datetime oder String 'yyyy-MM-dd')
%       end_date   - Enddatum (datetime oder String 'yyyy-MM-dd')
%       interval   - Zeitintervall: '1h', '4h', '1d', etc.
%       varargin   - Optional: 'save', filename zum Speichern der Daten
%
%   Output:
%       data - Table mit DateTime, Open, High, Low, Close, Volume
%
%   Beispiele:
%       % Daten für Oktober 2025 laden (1 Stunde Intervall)
%       data = download_btc_data('2025-10-01', '2025-10-31', '1h');
%
%       % Daten laden und als CSV speichern
%       data = download_btc_data('2025-09-01', '2025-12-31', '1h', ...
%                                'save', 'btc_data_new.csv');
%
%   Hinweis:
%       Diese Funktion verwendet die CoinGecko API (kostenlos, keine API-Key
%       erforderlich) oder Binance Public API. Bei großen Zeiträumen kann
%       es zu Ratenlimits kommen.

    % Input-Validierung
    if nargin < 3
        error('Mindestens 3 Argumente erforderlich: start_date, end_date, interval');
    end

    % Datum konvertieren falls String
    if ischar(start_date) || isstring(start_date)
        start_date = datetime(start_date, 'InputFormat', 'yyyy-MM-dd');
    end
    if ischar(end_date) || isstring(end_date)
        end_date = datetime(end_date, 'InputFormat', 'yyyy-MM-dd');
    end

    % Optional: Save-Parameter verarbeiten
    save_to_file = false;
    output_filename = '';
    for i = 1:2:length(varargin)
        if strcmpi(varargin{i}, 'save') && i < length(varargin)
            save_to_file = true;
            output_filename = varargin{i+1};
        end
    end

    fprintf('=== BTCUSD Daten Download ===\n\n');
    fprintf('Zeitraum: %s bis %s\n', datestr(start_date), datestr(end_date));
    fprintf('Intervall: %s\n\n', interval);

    % Versuche verschiedene APIs
    data = [];

    % Option 1: Binance Public API (empfohlen für Krypto-Daten)
    fprintf('Versuche Download von Binance API...\n');
    try
        data = download_from_binance(start_date, end_date, interval);
        if ~isempty(data)
            fprintf('✓ Erfolgreich von Binance geladen\n');
        end
    catch ME
        fprintf('✗ Binance fehlgeschlagen: %s\n', ME.message);
    end

    % Option 2: CoinGecko API (Fallback)
    if isempty(data)
        fprintf('\nVersuche Download von CoinGecko API...\n');
        try
            data = download_from_coingecko(start_date, end_date);
            if ~isempty(data)
                fprintf('✓ Erfolgreich von CoinGecko geladen\n');
            end
        catch ME
            fprintf('✗ CoinGecko fehlgeschlagen: %s\n', ME.message);
        end
    end

    % Wenn alle APIs fehlschlagen
    if isempty(data)
        error('Konnte keine Daten von verfügbaren APIs laden. Bitte überprüfen Sie Ihre Internetverbindung.');
    end

    % Statistiken ausgeben
    fprintf('\n=== Download abgeschlossen ===\n');
    fprintf('Datensätze: %d\n', height(data));
    fprintf('Zeitraum: %s bis %s\n', ...
            datestr(data.DateTime(1)), datestr(data.DateTime(end)));

    % Optional: Als CSV speichern
    if save_to_file
        fprintf('\nSpeichere Daten als: %s\n', output_filename);
        save_as_csv(data, output_filename);
    end
end

%% Binance API Download
function data = download_from_binance(start_date, end_date, interval)
    % Binance API Endpoint
    base_url = 'https://api.binance.com/api/v3/klines';

    % Intervall-Mapping
    interval_map = containers.Map(...
        {'1h', '4h', '1d', '1w'}, ...
        {'1h', '4h', '1d', '1w'});

    if ~isKey(interval_map, interval)
        warning('Intervall %s nicht unterstützt, verwende 1h', interval);
        interval = '1h';
    end

    % Zeitstempel in Millisekunden konvertieren
    start_time = posixtime(start_date) * 1000;
    end_time = posixtime(end_date) * 1000;

    % API-Anfrage (max. 1000 Datenpunkte pro Request)
    all_data = [];
    current_start = start_time;

    while current_start < end_time
        % URL konstruieren
        url = sprintf('%s?symbol=BTCUSDT&interval=%s&startTime=%d&endTime=%d&limit=1000', ...
                     base_url, interval, floor(current_start), floor(end_time));

        % Daten abrufen
        options = weboptions('Timeout', 30, 'ContentType', 'json');
        response = webread(url, options);

        if isempty(response)
            break;
        end

        % Daten speichern
        all_data = [all_data; response];

        % Nächster Zeitbereich
        last_time = response{end}{1};
        current_start = last_time + 1;

        % Rate Limiting (Binance: 1200 requests/min)
        pause(0.1);

        fprintf('.');
    end
    fprintf('\n');

    % Daten in Table konvertieren
    if isempty(all_data)
        data = [];
        return;
    end

    num_rows = length(all_data);
    timestamps = zeros(num_rows, 1);
    opens = zeros(num_rows, 1);
    highs = zeros(num_rows, 1);
    lows = zeros(num_rows, 1);
    closes = zeros(num_rows, 1);
    volumes = zeros(num_rows, 1);

    for i = 1:num_rows
        row = all_data{i};
        timestamps(i) = row{1} / 1000; % Millisekunden zu Sekunden
        opens(i) = str2double(row{2});
        highs(i) = str2double(row{3});
        lows(i) = str2double(row{4});
        closes(i) = str2double(row{5});
        volumes(i) = str2double(row{6});
    end

    % Table erstellen
    data = table();
    data.DateTime = datetime(timestamps, 'ConvertFrom', 'posixtime');
    data.Open = opens;
    data.High = highs;
    data.Low = lows;
    data.Close = closes;
    data.Volume = volumes;
end

%% CoinGecko API Download
function data = download_from_coingecko(start_date, end_date)
    % CoinGecko API (nur Tages-Daten verfügbar in Free API)
    base_url = 'https://api.coingecko.com/api/v3/coins/bitcoin/market_chart/range';

    % Zeitstempel konvertieren
    from_timestamp = posixtime(start_date);
    to_timestamp = posixtime(end_date);

    % API-Anfrage
    url = sprintf('%s?vs_currency=usd&from=%d&to=%d', ...
                 base_url, floor(from_timestamp), floor(to_timestamp));

    options = weboptions('Timeout', 30, 'ContentType', 'json');
    response = webread(url, options);

    % Daten extrahieren (CoinGecko liefert prices, market_caps, total_volumes)
    if ~isfield(response, 'prices') || isempty(response.prices)
        data = [];
        return;
    end

    prices_data = response.prices;
    num_rows = size(prices_data, 1);

    timestamps = zeros(num_rows, 1);
    closes = zeros(num_rows, 1);

    for i = 1:num_rows
        timestamps(i) = prices_data{i}(1) / 1000;
        closes(i) = prices_data{i}(2);
    end

    % Table erstellen (CoinGecko hat nur Close-Preise)
    data = table();
    data.DateTime = datetime(timestamps, 'ConvertFrom', 'posixtime');
    data.Close = closes;
    data.Open = closes; % Approximation
    data.High = closes; % Approximation
    data.Low = closes;  % Approximation
    data.Volume = zeros(num_rows, 1);

    warning('CoinGecko API liefert nur Close-Preise. OHLC sind approximiert.');
end

%% CSV Export-Funktion
function save_as_csv(data, filename)
    % Erstelle Format kompatibel mit read_btc_data
    export_data = table();

    % Datum und Zeit trennen
    export_data.Date = datestr(data.DateTime, 'yyyy.mm.dd');
    export_data.Time = datestr(data.DateTime, 'HH:MM:SS');
    export_data.Open = data.Open;
    export_data.High = data.High;
    export_data.Low = data.Low;
    export_data.Close = data.Close;

    if ismember('Volume', data.Properties.VariableNames)
        export_data.TickVol = data.Volume;
    else
        export_data.TickVol = zeros(height(data), 1);
    end

    export_data.Vol = zeros(height(data), 1);
    export_data.Spread = zeros(height(data), 1);

    % Als CSV mit Tab-Trennzeichen speichern
    writetable(export_data, filename, 'Delimiter', '\t');
    fprintf('Daten gespeichert: %s\n', filename);
end
