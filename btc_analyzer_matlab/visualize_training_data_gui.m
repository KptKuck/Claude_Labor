function visualize_training_data_gui(data, training_data_info, X_train, Y_train, log_func)
% VISUALIZE_TRAINING_DATA_GUI GUI für Trainingsdaten-Visualisierung
%
%   visualize_training_data_gui(data, training_data_info, X_train, Y_train, log_func)
%   öffnet eine GUI zur Visualisierung der BILSTM Trainingsdaten
%   mit farbigen Bereichen für BUY und SELL Signale.
%
%   Input:
%       data - Table mit BTCUSD Daten (DateTime, Close, High, Low, Open)
%       training_data_info - Struct mit Informationen über Trainingsdaten
%       X_train - Cell Array mit Trainingssequenzen
%       Y_train - Cell Array mit Labels (categorical)
%       log_func - (Optional) Logger-Funktion aus Main-GUI (@logMessage)
%
%   Features:
%       - Gesamter Datensatz sichtbar
%       - BTCUSD Close-Preis Chart
%       - Statistik-Panel mit Signal-Zählung

    % Logger-Funktion (falls nicht übergeben, nutze fprintf)
    if nargin < 5 || isempty(log_func)
        log_func = @(msg, level) fprintf('[%s] %s\n', upper(level), msg);
    end

    log_func('Starte Training Data Visualizer GUI...', 'debug');

    % Extrahiere Informationen
    lookback = training_data_info.lookback_size;
    lookforward = training_data_info.lookforward_size;
    total_length = lookback + lookforward;

    % Finde alle Signal-Positionen
    [high_points, low_points] = find_daily_extrema(data);

    % Erstelle Signal-Arrays für schnelle Visualisierung
    num_data_points = height(data);

    % Berechne BUY/SELL Positionen
    buy_positions = [];
    sell_positions = [];

    for i = 1:length(low_points)
        idx = find(data.DateTime == low_points(i).DateTime, 1);
        if ~isempty(idx) && idx > lookback && idx + lookforward <= num_data_points
            buy_positions(end+1).idx = idx;
            buy_positions(end).time = low_points(i).DateTime;
            buy_positions(end).price = low_points(i).Price;
            buy_positions(end).start_idx = idx - lookback;
            buy_positions(end).end_idx = idx + lookforward - 1;
        end
    end

    for i = 1:length(high_points)
        idx = find(data.DateTime == high_points(i).DateTime, 1);
        if ~isempty(idx) && idx > lookback && idx + lookforward <= num_data_points
            sell_positions(end+1).idx = idx;
            sell_positions(end).time = high_points(i).DateTime;
            sell_positions(end).price = high_points(i).Price;
            sell_positions(end).start_idx = idx - lookback;
            sell_positions(end).end_idx = idx + lookforward - 1;
        end
    end

    log_func(sprintf('Signale gefunden: %d BUY, %d SELL', length(buy_positions), length(sell_positions)), 'debug');

    % Erstelle kombinierte, chronologisch sortierte Signal-Liste
    all_signals = [];
    for i = 1:length(buy_positions)
        all_signals(end+1).idx = buy_positions(i).idx;
        all_signals(end).time = buy_positions(i).time;
        all_signals(end).price = buy_positions(i).price;
        all_signals(end).start_idx = buy_positions(i).start_idx;
        all_signals(end).end_idx = buy_positions(i).end_idx;
        all_signals(end).type = 'BUY';
        all_signals(end).original_idx = i;  % Index in buy_positions
    end
    for i = 1:length(sell_positions)
        all_signals(end+1).idx = sell_positions(i).idx;
        all_signals(end).time = sell_positions(i).time;
        all_signals(end).price = sell_positions(i).price;
        all_signals(end).start_idx = sell_positions(i).start_idx;
        all_signals(end).end_idx = sell_positions(i).end_idx;
        all_signals(end).type = 'SELL';
        all_signals(end).original_idx = i;  % Index in sell_positions
    end

    % Sortiere nach Zeit (chronologisch)
    if ~isempty(all_signals)
        [~, sort_idx] = sort([all_signals.idx]);
        all_signals = all_signals(sort_idx);
    end

    log_func(sprintf('Gesamt: %d Signale (chronologisch sortiert)', length(all_signals)), 'trace');

    % GUI erstellen - dynamische Größe basierend auf Bildschirm
    screen_size = get(0, 'ScreenSize');
    fig_width = min(1600, screen_size(3) - 100);
    fig_height = min(950, screen_size(4) - 100);
    fig_x = max(50, (screen_size(3) - fig_width) / 2);
    fig_y = max(50, (screen_size(4) - fig_height) / 2);

    fig = uifigure('Name', 'Training Data Visualizer', ...
                   'Position', [fig_x, fig_y, fig_width, fig_height]);

    % Haupt-Grid Layout: [Charts | Info Panel]
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.ColumnWidth = {'1x', 280};
    mainGrid.Padding = [10 10 10 10];
    mainGrid.ColumnSpacing = 10;

    % Linkes Panel: Zwei Charts übereinander
    chartPanel = uipanel(mainGrid, 'Title', '');
    chartPanel.Layout.Row = 1;
    chartPanel.Layout.Column = 1;

    % Chart Grid Layout: 2 Charts (oben groß, unten klein)
    chartGrid = uigridlayout(chartPanel, [2, 1]);
    chartGrid.RowHeight = {'2x', '1x'};
    chartGrid.Padding = [5 5 5 5];
    chartGrid.RowSpacing = 10;

    % Oberes Panel: Haupt-Chart mit Signalen
    mainChartPanel = uipanel(chartGrid, 'Title', 'BTCUSD Chart mit Training-Signalen', ...
                             'FontSize', 10, 'FontWeight', 'bold');
    mainChartPanel.Layout.Row = 1;
    mainChartPanel.Layout.Column = 1;

    mainChartGrid = uigridlayout(mainChartPanel, [1, 1]);
    mainChartGrid.Padding = [5 5 5 5];

    % Axes für Haupt-Chart
    ax = uiaxes(mainChartGrid);
    ax.Layout.Row = 1;
    ax.Layout.Column = 1;
    grid(ax, 'on');
    xlabel(ax, 'Datum/Zeit');
    ylabel(ax, 'Preis (USD)');
    hold(ax, 'on');

    % Unteres Panel: Sequenz-Detail-Chart
    seqChartPanel = uipanel(chartGrid, 'Title', 'Aktuelle Sequenz (Trainingsdaten)', ...
                            'FontSize', 10, 'FontWeight', 'bold');
    seqChartPanel.Layout.Row = 2;
    seqChartPanel.Layout.Column = 1;

    seqChartGrid = uigridlayout(seqChartPanel, [1, 1]);
    seqChartGrid.Padding = [5 5 5 5];

    % Axes für Sequenz-Chart
    ax_seq = uiaxes(seqChartGrid);
    ax_seq.Layout.Row = 1;
    ax_seq.Layout.Column = 1;
    grid(ax_seq, 'on');
    xlabel(ax_seq, 'Zeitpunkt in Sequenz');
    ylabel(ax_seq, 'Normalisierter Wert');
    hold(ax_seq, 'on');

    % Rechtes Panel: Info und Steuerung (scrollbar für kleinere Bildschirme)
    infoScrollPanel = uipanel(mainGrid, 'Title', '', 'Scrollable', 'on');
    infoScrollPanel.Layout.Row = 1;
    infoScrollPanel.Layout.Column = 2;

    infoPanel = uigridlayout(infoScrollPanel, [14, 1]);
    % Struktur: Info-Gruppe, Schritt-Gruppe (erweitert), Zoom-Gruppe, Achsen-Gruppe
    infoPanel.RowHeight = {25, 22, 22, 22, 10, 25, 140, 10, 25, 75, 10, 25, 100, 10};
    infoPanel.ColumnWidth = {'1x'};
    infoPanel.RowSpacing = 3;
    infoPanel.Padding = [5 5 5 5];

    % Variable für aktuellen Signal-Index
    current_signal_idx = 1;

    % Variable für Zoom-Stufe
    zoom_level = 1.0;  % 1.0 = 100% (alles sichtbar)

    % Variablen für Achsen-Skalierung
    x_scale = 1.0;  % X-Achsen Skalierung
    y_scale = 1.0;  % Y-Achsen Skalierung

    % ============================================================
    % GRUPPE 1: Signal-Info
    % ============================================================
    info_title = uilabel(infoPanel, 'Text', 'Signal-Info', ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [0.2, 0.4, 0.6], ...
            'FontColor', 'white');
    info_title.Layout.Row = 1;
    info_title.Layout.Column = 1;

    % Statistik Label
    stats_label = uilabel(infoPanel, 'Text', sprintf('BUY: %d | SELL: %d', ...
                          length(buy_positions), length(sell_positions)), ...
                          'FontSize', 10, ...
                          'HorizontalAlignment', 'center');
    stats_label.Layout.Row = 2;
    stats_label.Layout.Column = 1;

    % SELL Statistik (wird für Signal-Details verwendet)
    sell_stats_label = uilabel(infoPanel, 'Text', 'Signal: -', ...
                               'FontSize', 10, ...
                               'HorizontalAlignment', 'center');
    sell_stats_label.Layout.Row = 3;
    sell_stats_label.Layout.Column = 1;

    % Total / Input Info
    total_signals_label = uilabel(infoPanel, 'Text', 'Input: -', ...
                                  'FontSize', 9, ...
                                  'HorizontalAlignment', 'center');
    total_signals_label.Layout.Row = 4;
    total_signals_label.Layout.Column = 1;

    % Spacer 1
    spacer1 = uilabel(infoPanel, 'Text', '');
    spacer1.Layout.Row = 5;
    spacer1.Layout.Column = 1;

    % ============================================================
    % GRUPPE 2: Schrittmodus (Alle / BUY / SELL)
    % ============================================================
    step_title = uilabel(infoPanel, 'Text', 'Schrittmodus', ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [0.3, 0.5, 0.3], ...
            'FontColor', 'white');
    step_title.Layout.Row = 6;
    step_title.Layout.Column = 1;

    % Step-Buttons Grid (4 Zeilen: Alle, BUY, SELL, Position)
    stepGrid = uigridlayout(infoPanel, [4, 3]);
    stepGrid.Layout.Row = 7;
    stepGrid.Layout.Column = 1;
    stepGrid.RowHeight = {'1x', '1x', '1x', 20};
    stepGrid.ColumnWidth = {50, '1x', 50};
    stepGrid.RowSpacing = 3;
    stepGrid.ColumnSpacing = 3;
    stepGrid.Padding = [0 0 0 0];

    % Zeile 1: ALLE Signale (grau)
    step_all_prev = uibutton(stepGrid, 'Text', '<', ...
                             'ButtonPushedFcn', @(btn,event) stepSignal(-1, 'ALL'), ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.5, 0.5, 0.5], ...
                             'FontColor', 'white');
    step_all_prev.Layout.Row = 1;
    step_all_prev.Layout.Column = 1;

    step_all_label = uilabel(stepGrid, 'Text', 'ALLE', ...
                             'FontSize', 10, 'FontWeight', 'bold', ...
                             'HorizontalAlignment', 'center', ...
                             'BackgroundColor', [0.7, 0.7, 0.7]);
    step_all_label.Layout.Row = 1;
    step_all_label.Layout.Column = 2;

    step_all_next = uibutton(stepGrid, 'Text', '>', ...
                             'ButtonPushedFcn', @(btn,event) stepSignal(1, 'ALL'), ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.5, 0.5, 0.5], ...
                             'FontColor', 'white');
    step_all_next.Layout.Row = 1;
    step_all_next.Layout.Column = 3;

    % Zeile 2: Nur BUY Signale (grün)
    step_buy_prev = uibutton(stepGrid, 'Text', '<', ...
                             'ButtonPushedFcn', @(btn,event) stepSignal(-1, 'BUY'), ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.2, 0.6, 0.2], ...
                             'FontColor', 'white');
    step_buy_prev.Layout.Row = 2;
    step_buy_prev.Layout.Column = 1;

    step_buy_label = uilabel(stepGrid, 'Text', 'BUY', ...
                             'FontSize', 10, 'FontWeight', 'bold', ...
                             'HorizontalAlignment', 'center', ...
                             'BackgroundColor', [0.5, 0.9, 0.5]);
    step_buy_label.Layout.Row = 2;
    step_buy_label.Layout.Column = 2;

    step_buy_next = uibutton(stepGrid, 'Text', '>', ...
                             'ButtonPushedFcn', @(btn,event) stepSignal(1, 'BUY'), ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.2, 0.6, 0.2], ...
                             'FontColor', 'white');
    step_buy_next.Layout.Row = 2;
    step_buy_next.Layout.Column = 3;

    % Zeile 3: Nur SELL Signale (rot)
    step_sell_prev = uibutton(stepGrid, 'Text', '<', ...
                              'ButtonPushedFcn', @(btn,event) stepSignal(-1, 'SELL'), ...
                              'FontSize', 12, 'FontWeight', 'bold', ...
                              'BackgroundColor', [0.7, 0.2, 0.2], ...
                              'FontColor', 'white');
    step_sell_prev.Layout.Row = 3;
    step_sell_prev.Layout.Column = 1;

    step_sell_label = uilabel(stepGrid, 'Text', 'SELL', ...
                              'FontSize', 10, 'FontWeight', 'bold', ...
                              'HorizontalAlignment', 'center', ...
                              'BackgroundColor', [0.9, 0.5, 0.5]);
    step_sell_label.Layout.Row = 3;
    step_sell_label.Layout.Column = 2;

    step_sell_next = uibutton(stepGrid, 'Text', '>', ...
                              'ButtonPushedFcn', @(btn,event) stepSignal(1, 'SELL'), ...
                              'FontSize', 12, 'FontWeight', 'bold', ...
                              'BackgroundColor', [0.7, 0.2, 0.2], ...
                              'FontColor', 'white');
    step_sell_next.Layout.Row = 3;
    step_sell_next.Layout.Column = 3;

    % Zeile 4: Position-Anzeige
    position_label = uilabel(stepGrid, 'Text', '1 / 0', ...
                             'FontSize', 9, ...
                             'HorizontalAlignment', 'center');
    position_label.Layout.Row = 4;
    position_label.Layout.Column = [1, 3];

    % Spacer 2
    spacer2 = uilabel(infoPanel, 'Text', '');
    spacer2.Layout.Row = 8;
    spacer2.Layout.Column = 1;

    % ============================================================
    % GRUPPE 3: Chart Zoom (1x3 Grid)
    % ============================================================
    zoom_title = uilabel(infoPanel, 'Text', 'Chart Zoom', ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [0.4, 0.4, 0.6], ...
            'FontColor', 'white');
    zoom_title.Layout.Row = 9;
    zoom_title.Layout.Column = 1;

    % Zoom-Buttons Grid (1 Zeile, 3 Spalten)
    zoomGrid = uigridlayout(infoPanel, [2, 3]);
    zoomGrid.Layout.Row = 10;
    zoomGrid.Layout.Column = 1;
    zoomGrid.RowHeight = {'1x', '1x'};
    zoomGrid.ColumnWidth = {'1x', '1x', '1x'};
    zoomGrid.RowSpacing = 3;
    zoomGrid.ColumnSpacing = 3;
    zoomGrid.Padding = [0 0 0 0];

    zoom_in_btn = uibutton(zoomGrid, 'Text', 'In', ...
                           'ButtonPushedFcn', @(btn,event) changeZoom(0.5), ...
                           'FontSize', 11, 'FontWeight', 'bold', ...
                           'BackgroundColor', [0.2, 0.6, 0.2], ...
                           'FontColor', 'white');
    zoom_in_btn.Layout.Row = 1;
    zoom_in_btn.Layout.Column = 1;

    zoom_out_btn = uibutton(zoomGrid, 'Text', 'Out', ...
                            'ButtonPushedFcn', @(btn,event) changeZoom(2.0), ...
                            'FontSize', 11, 'FontWeight', 'bold', ...
                            'BackgroundColor', [0.2, 0.5, 0.7], ...
                            'FontColor', 'white');
    zoom_out_btn.Layout.Row = 1;
    zoom_out_btn.Layout.Column = 2;

    reset_zoom_btn = uibutton(zoomGrid, 'Text', 'Reset', ...
                              'ButtonPushedFcn', @(btn,event) changeZoom(1.0), ...
                              'FontSize', 10, 'FontWeight', 'bold', ...
                              'BackgroundColor', [0.5, 0.5, 0.5], ...
                              'FontColor', 'white');
    reset_zoom_btn.Layout.Row = 1;
    reset_zoom_btn.Layout.Column = 3;

    % Zoom Level Anzeige
    zoom_label = uilabel(zoomGrid, 'Text', 'Zoom: 100%', ...
                         'FontSize', 10, ...
                         'HorizontalAlignment', 'center');
    zoom_label.Layout.Row = 2;
    zoom_label.Layout.Column = [1, 3];

    % Spacer 3
    spacer3 = uilabel(infoPanel, 'Text', '');
    spacer3.Layout.Row = 11;
    spacer3.Layout.Column = 1;

    % ============================================================
    % GRUPPE 4: Achsen-Skalierung (2x2 + Reset)
    % ============================================================
    scale_title = uilabel(infoPanel, 'Text', 'Achsen-Skalierung', ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [0.5, 0.4, 0.3], ...
            'FontColor', 'white');
    scale_title.Layout.Row = 12;
    scale_title.Layout.Column = 1;

    % Achsen-Buttons Grid (3 Zeilen, 2 Spalten)
    scaleGrid = uigridlayout(infoPanel, [3, 2]);
    scaleGrid.Layout.Row = 13;
    scaleGrid.Layout.Column = 1;
    scaleGrid.RowHeight = {'1x', '1x', '1x'};
    scaleGrid.ColumnWidth = {'1x', '1x'};
    scaleGrid.RowSpacing = 3;
    scaleGrid.ColumnSpacing = 3;
    scaleGrid.Padding = [0 0 0 0];

    % X-Achsen Buttons
    x_zoom_in_btn = uibutton(scaleGrid, 'Text', 'X+', ...
                             'ButtonPushedFcn', @(btn,event) changeXScale(0.7), ...
                             'FontSize', 11, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.6, 0.4, 0.2]);
    x_zoom_in_btn.Layout.Row = 1;
    x_zoom_in_btn.Layout.Column = 1;

    x_zoom_out_btn = uibutton(scaleGrid, 'Text', 'X-', ...
                              'ButtonPushedFcn', @(btn,event) changeXScale(1.4), ...
                              'FontSize', 11, 'FontWeight', 'bold', ...
                              'BackgroundColor', [0.8, 0.6, 0.4]);
    x_zoom_out_btn.Layout.Row = 1;
    x_zoom_out_btn.Layout.Column = 2;

    % Y-Achsen Buttons
    y_zoom_in_btn = uibutton(scaleGrid, 'Text', 'Y+', ...
                             'ButtonPushedFcn', @(btn,event) changeYScale(0.7), ...
                             'FontSize', 11, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.4, 0.5, 0.6]);
    y_zoom_in_btn.Layout.Row = 2;
    y_zoom_in_btn.Layout.Column = 1;

    y_zoom_out_btn = uibutton(scaleGrid, 'Text', 'Y-', ...
                              'ButtonPushedFcn', @(btn,event) changeYScale(1.4), ...
                              'FontSize', 11, 'FontWeight', 'bold', ...
                              'BackgroundColor', [0.6, 0.7, 0.8]);
    y_zoom_out_btn.Layout.Row = 2;
    y_zoom_out_btn.Layout.Column = 2;

    % Reset Button (über beide Spalten)
    reset_scale_btn = uibutton(scaleGrid, 'Text', 'Reset', ...
                               'ButtonPushedFcn', @(btn,event) resetScale(), ...
                               'FontSize', 10, 'FontWeight', 'bold', ...
                               'BackgroundColor', [0.5, 0.5, 0.5], ...
                               'FontColor', 'white');
    reset_scale_btn.Layout.Row = 3;
    reset_scale_btn.Layout.Column = [1, 2];

    % Sequenz-Info Labels (im Spacer-Bereich)
    lookback_label = uilabel(infoPanel, 'Text', sprintf('Seq: %d-%d', lookback, lookforward), ...
                             'FontSize', 9, ...
                             'HorizontalAlignment', 'center');
    lookback_label.Layout.Row = 14;
    lookback_label.Layout.Column = 1;

    % Hidden Labels für Kompatibilität
    lookforward_label = uilabel(infoPanel, 'Text', '', 'Visible', 'off');
    lookforward_label.Layout.Row = 14;
    lookforward_label.Layout.Column = 1;

    total_length_label = uilabel(infoPanel, 'Text', '', 'Visible', 'off');
    total_length_label.Layout.Row = 14;
    total_length_label.Layout.Column = 1;

    % Initial Plot - zeige alle Daten
    updatePlot();

    log_func('Visualisierungs-GUI bereit', 'success');

    %% Callback: Schrittmodus Navigation
    function stepSignal(step, filter_type)
        % step: Richtung (+1 = vorwärts, -1 = rückwärts)
        % filter_type: 'ALL', 'BUY', oder 'SELL'

        total_signals = length(all_signals);
        if total_signals == 0
            return;
        end

        if strcmp(filter_type, 'ALL')
            % Einfaches Steppen durch alle Signale
            new_idx = current_signal_idx + step;
            new_idx = max(1, min(new_idx, total_signals));
        else
            % Finde nächstes/vorheriges Signal des gewünschten Typs
            new_idx = current_signal_idx;

            if step > 0
                % Vorwärts suchen
                for i = (current_signal_idx + 1):total_signals
                    if strcmp(all_signals(i).type, filter_type)
                        new_idx = i;
                        break;
                    end
                end
            else
                % Rückwärts suchen
                for i = (current_signal_idx - 1):-1:1
                    if strcmp(all_signals(i).type, filter_type)
                        new_idx = i;
                        break;
                    end
                end
            end
        end

        if new_idx ~= current_signal_idx
            current_signal_idx = new_idx;
            updatePlot();
        end
    end

    %% Callback: Chart Zoom ändern
    function changeZoom(zoom_factor)
        % Wenn zoom_factor == 1.0, reset zu 100%
        if zoom_factor == 1.0
            zoom_level = 1.0;
        else
            % Multipliziere zoom_level mit zoom_factor
            zoom_level = zoom_level * zoom_factor;
            % Grenze zwischen 0.1x und 10x
            zoom_level = max(0.1, min(10.0, zoom_level));
        end
        % Update Zoom-Anzeige
        zoom_label.Text = sprintf('Zoom: %.0f%%', zoom_level * 100);
        updatePlot();
    end

    %% Callback: X-Achsen Skalierung ändern
    function changeXScale(scale_factor)
        x_scale = x_scale * scale_factor;
        % Grenze zwischen 0.2x und 5x
        x_scale = max(0.2, min(5.0, x_scale));
        updatePlot();
    end

    %% Callback: Y-Achsen Skalierung ändern
    function changeYScale(scale_factor)
        y_scale = y_scale * scale_factor;
        % Grenze zwischen 0.2x und 5x
        y_scale = max(0.2, min(5.0, y_scale));
        updatePlot();
    end

    %% Callback: Achsen Reset
    function resetScale()
        x_scale = 1.0;
        y_scale = 1.0;
        updatePlot();
    end

    %% Haupt-Plot-Funktion

    function updatePlot()
        % Berechne sichtbaren Bereich basierend auf Zoom
        start_idx = 1;
        end_idx = num_data_points;

        total_signals = length(all_signals);

        % Wende Zoom an: Bei Zoom=0.5, zeige nur 50% der Daten (zentriert um den Signal)
        if zoom_level < 1.0 && total_signals > 0 && current_signal_idx <= total_signals
            % Hole aktuelles Signal aus chronologischer Liste
            signal_data_idx = all_signals(current_signal_idx).idx;

            % Berechne sichtbaren Bereich zentriert um Signal
            visible_range = round(num_data_points * zoom_level);
            half_range = round(visible_range / 2);

            start_idx = max(1, signal_data_idx - half_range);
            end_idx = min(num_data_points, signal_data_idx + half_range);

            % Korrigiere wenn zu nah an Grenzen
            if end_idx - start_idx + 1 < visible_range
                if start_idx == 1
                    end_idx = min(num_data_points, start_idx + visible_range - 1);
                else
                    start_idx = max(1, end_idx - visible_range + 1);
                end
            end
        end

        % Lösche vorherigen Plot
        cla(ax);
        hold(ax, 'on');

        % Extrahiere sichtbare Daten
        visible_times = data.DateTime(start_idx:end_idx);
        visible_prices = data.Close(start_idx:end_idx);

        % Zeichne Close-Preis
        plot(ax, visible_times, visible_prices, 'b-', 'LineWidth', 1.5, 'DisplayName', 'BTCUSD Close');

        % Zeichne alle Signale (Dreiecke) im sichtbaren Bereich
        for i = 1:total_signals
            sig = all_signals(i);
            % Prüfe ob Signal im sichtbaren Bereich liegt
            if sig.idx >= start_idx && sig.idx <= end_idx
                if strcmp(sig.type, 'BUY')
                    plot(ax, sig.time, sig.price, 'g^', 'MarkerSize', 8, ...
                         'MarkerFaceColor', 'g', 'HandleVisibility', 'off');
                else
                    plot(ax, sig.time, sig.price, 'rv', 'MarkerSize', 8, ...
                         'MarkerFaceColor', 'r', 'HandleVisibility', 'off');
                end
            end
        end

        % Markiere aktuellen Signal mit Cursor (größerer Kreis)
        if total_signals > 0 && current_signal_idx <= total_signals
            signal = all_signals(current_signal_idx);
            if strcmp(signal.type, 'BUY')
                plot(ax, signal.time, signal.price, 'go', 'MarkerSize', 16, 'LineWidth', 3, ...
                     'MarkerFaceColor', 'none', 'DisplayName', 'Cursor');
            else
                plot(ax, signal.time, signal.price, 'ro', 'MarkerSize', 16, 'LineWidth', 3, ...
                     'MarkerFaceColor', 'none', 'DisplayName', 'Cursor');
            end
        end

        % Legende-Einträge für Dreiecke
        plot(ax, NaN, NaN, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', 'BUY (Tief)');
        plot(ax, NaN, NaN, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', 'SELL (Hoch)');

        hold(ax, 'off');

        % Layout
        grid(ax, 'on');
        xlabel(ax, 'Datum/Zeit');
        ylabel(ax, 'Preis (USD)');
        title(ax, sprintf('BTCUSD Preisverlauf (Zoom: %.0f%%)', zoom_level * 100));
        legend(ax, 'Location', 'best');

        % Y-Achsen-Grenzen mit Skalierung
        % Nur Skalierung anwenden wenn y_scale != 1.0
        y_min = min(visible_prices) * 0.98;
        y_max = max(visible_prices) * 1.02;

        if y_scale ~= 1.0
            y_center = (y_min + y_max) / 2;
            y_range = (y_max - y_min) / 2;
            y_scaled_min = y_center - (y_range / y_scale);
            y_scaled_max = y_center + (y_range / y_scale);
            ylim(ax, [y_scaled_min, y_scaled_max]);
        else
            ylim(ax, [y_min, y_max]);
        end

        % X-Achsen-Grenzen mit Skalierung
        % Nur Skalierung anwenden wenn x_scale != 1.0 (sonst vergößert Skalierung falsch)
        if x_scale ~= 1.0
            x_min_time = visible_times(1);
            x_max_time = visible_times(end);
            x_duration = x_max_time - x_min_time;
            x_center = x_min_time + x_duration / 2;
            x_range = x_duration / 2;
            x_scaled_min = x_center - (x_range / x_scale);
            x_scaled_max = x_center + (x_range / x_scale);
            xlim(ax, [x_scaled_min, x_scaled_max]);
        else
            xlim(ax, [visible_times(1), visible_times(end)]);
        end

        % Update Sequenz-Detail-Chart
        updateSequenceChart();

        % Update Info-Panel mit aktuellen Signal-Daten
        updateSignalInfo();
    end

    %% Funktion: Update Sequenz-Detail-Chart
    function updateSequenceChart()
        total_signals = length(all_signals);

        % Lösche vorherigen Plot
        cla(ax_seq);
        hold(ax_seq, 'on');

        if total_signals == 0 || current_signal_idx > total_signals
            title(ax_seq, 'Keine Sequenz ausgewählt');
            hold(ax_seq, 'off');
            return;
        end

        % Hole aktuelles Signal
        signal = all_signals(current_signal_idx);
        signal_type = signal.type;
        seq_start = signal.start_idx;
        seq_end = signal.end_idx;

        % Finde den original X_train Index
        if strcmp(signal_type, 'BUY')
            x_train_idx = signal.original_idx;
        else
            x_train_idx = length(buy_positions) + signal.original_idx;
        end

        % Extrahiere Sequenz-Daten aus Originaldaten (für Linien-Chart)
        if seq_start >= 1 && seq_end <= num_data_points
            seq_times = data.DateTime(seq_start:seq_end);
            seq_close = data.Close(seq_start:seq_end);
            seq_high = data.High(seq_start:seq_end);
            seq_low = data.Low(seq_start:seq_end);
            seq_open = data.Open(seq_start:seq_end);

            % X-Achse: Zeitpunkte in der Sequenz (1 bis N)
            seq_x = 1:length(seq_close);

            % Zeichne OHLC-Linien
            plot(ax_seq, seq_x, seq_close, 'b-', 'LineWidth', 2, 'DisplayName', 'Close');
            plot(ax_seq, seq_x, seq_high, 'g--', 'LineWidth', 1, 'DisplayName', 'High');
            plot(ax_seq, seq_x, seq_low, 'r--', 'LineWidth', 1, 'DisplayName', 'Low');
            plot(ax_seq, seq_x, seq_open, 'm:', 'LineWidth', 1, 'DisplayName', 'Open');

            % Markiere Signalpunkt (Mitte der Sequenz = lookback)
            signal_pos = lookback;
            if signal_pos >= 1 && signal_pos <= length(seq_close)
                if strcmp(signal_type, 'BUY')
                    plot(ax_seq, signal_pos, seq_close(signal_pos), 'g^', 'MarkerSize', 14, ...
                         'MarkerFaceColor', 'g', 'LineWidth', 2, 'DisplayName', 'Signal');
                else
                    plot(ax_seq, signal_pos, seq_close(signal_pos), 'rv', 'MarkerSize', 14, ...
                         'MarkerFaceColor', 'r', 'LineWidth', 2, 'DisplayName', 'Signal');
                end
            end

            % Vertikale Linie bei Signal-Position (Lookback-Grenze)
            y_min_seq = min([min(seq_low), min(seq_close)]);
            y_max_seq = max([max(seq_high), max(seq_close)]);
            plot(ax_seq, [signal_pos, signal_pos], [y_min_seq, y_max_seq], 'k--', ...
                 'LineWidth', 1.5, 'HandleVisibility', 'off');

            % Bereich markieren: Lookback (links) und Lookforward (rechts)
            % Hellgrüner Hintergrund für Lookback
            fill(ax_seq, [1, signal_pos, signal_pos, 1], ...
                 [y_min_seq, y_min_seq, y_max_seq, y_max_seq], ...
                 'g', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            % Hellorange für Lookforward
            fill(ax_seq, [signal_pos, length(seq_x), length(seq_x), signal_pos], ...
                 [y_min_seq, y_min_seq, y_max_seq, y_max_seq], ...
                 'y', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'HandleVisibility', 'off');

            % Achsen-Beschriftung
            grid(ax_seq, 'on');
            xlabel(ax_seq, sprintf('Sequenz-Index (Lookback: %d | Lookforward: %d)', lookback, lookforward));
            ylabel(ax_seq, 'Preis (USD)');

            % Titel mit Signal-Info
            if strcmp(signal_type, 'BUY')
                title_color = [0, 0.6, 0];
            else
                title_color = [0.8, 0, 0];
            end
            title(ax_seq, sprintf('%s Signal - Sequenz %d bis %d (%s)', ...
                  signal_type, seq_start, seq_end, datestr(signal.time, 'dd.mm.yy HH:MM')), ...
                  'Color', title_color);

            legend(ax_seq, 'Location', 'best');

            % Y-Achsen Grenzen mit etwas Puffer
            ylim(ax_seq, [y_min_seq * 0.999, y_max_seq * 1.001]);
            xlim(ax_seq, [0.5, length(seq_x) + 0.5]);
        else
            title(ax_seq, 'Sequenz außerhalb des Datenbereichs');
        end

        hold(ax_seq, 'off');
    end

    %% Funktion: Update Signal-Informationen
    function updateSignalInfo()
        total_signals = length(all_signals);

        if total_signals == 0
            return;
        end

        % Bestimme aktuellen Signal aus chronologischer Liste
        current_idx_bounded = max(1, min(current_signal_idx, total_signals));
        signal = all_signals(current_idx_bounded);
        signal_type = signal.type;
        seq_start = signal.start_idx;
        seq_end = signal.end_idx;

        % Update Position-Anzeige
        position_label.Text = sprintf('%d / %d', current_idx_bounded, total_signals);

        % Update Signal Details
        stats_label.Text = sprintf('%s @ %s', signal_type, datestr(signal.time, 'dd.mm HH:MM'));
        sell_stats_label.Text = sprintf('Preis: %.2f USD', signal.price);

        % Finde den original X_train Index
        % X_train ist in der Reihenfolge: erst alle BUY, dann alle SELL
        if strcmp(signal_type, 'BUY')
            x_train_idx = signal.original_idx;
        else
            x_train_idx = length(buy_positions) + signal.original_idx;
        end

        % Zeige Trainingsdaten (X_train) für diesen Signal
        if x_train_idx <= length(X_train)
            X_data = X_train{x_train_idx};

            % Extrahiere Statistik aus X_data
            if ~isempty(X_data)
                % Berechne Min/Max über alle Features
                X_flat = X_data(:);
                X_min = min(X_flat);
                X_max = max(X_flat);

                feature_str = sprintf('Input: [%.3f, %.3f]', X_min, X_max);
            else
                feature_str = 'Input: -';
            end

            total_signals_label.Text = feature_str;
        else
            total_signals_label.Text = 'Input: -';
        end

        % Sequenz Info aktualisieren
        lookback_label.Text = sprintf('Idx: %d | Seq: %d-%d', signal.idx, seq_start, seq_end);
    end
end
