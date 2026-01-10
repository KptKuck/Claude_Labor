function prepare_training_data_gui(data, log_func)
% PREPARE_TRAINING_DATA_GUI GUI zum Einstellen und Vorschau der Trainingsdaten-Vorbereitung
%
%   PREPARE_TRAINING_DATA_GUI(data, log_func) öffnet eine GUI zum Konfigurieren der
%   Parameter für die Trainingsdaten-Vorbereitung und zeigt eine Vorschau.
%
%   Input:
%       data - Table mit DateTime, Open, High, Low, Close Spalten
%       log_func - (Optional) Logger-Funktion aus Main-GUI (@logMessage)
%
%   Features:
%       - Linke Seite: Alle einstellbaren Parameter
%       - Rechte Seite: Vorschau der Ergebnisse und Statistiken
%       - Live-Update bei Parameter-Änderungen

    %% Validierung
    if nargin < 1 || isempty(data)
        error('Daten müssen übergeben werden.');
    end

    % Logger-Funktion (falls nicht übergeben, nutze fprintf)
    if nargin < 2 || isempty(log_func)
        log_func = @(msg, level) fprintf('[%s] %s\n', upper(level), msg);
    end

    % Prüfe erforderliche Spalten
    required_cols = {'DateTime', 'Open', 'High', 'Low', 'Close'};
    for i = 1:length(required_cols)
        if ~any(strcmp(data.Properties.VariableNames, required_cols{i}))
            error('Spalte "%s" fehlt in den Daten.', required_cols{i});
        end
    end

    %% Berechne initiale Werte
    total_points = height(data);

    % Default Parameter
    params = struct();
    params.lookback = 50;  % Absolute Werte statt Prozent
    params.lookforward = 100;
    params.include_hold = true;
    params.hold_ratio = 1.0;  % Verhältnis HOLD zu (BUY+SELL)
    params.min_distance_factor = 0.3;  % Mindestabstand zu naechstem Extremum (als Faktor der Sequenzlaenge)
    params.random_seed = 42;
    params.normalize_method = 'zscore';  % 'zscore', 'minmax', 'none'

    % Feature-Auswahl
    params.use_close = true;
    params.use_high = true;
    params.use_low = true;
    params.use_open = true;
    params.use_price_change = true;
    params.use_price_change_pct = true;

    % Ergebnis-Variablen
    result_X = {};
    result_Y = {};
    result_info = struct();
    preview_computed = false;

    % Timing-Variablen (immer aktiv in dieser GUI, Ausgabe in Command Window)
    enable_timing = true;

    %% GUI erstellen - dynamische Größe basierend auf Bildschirm
    screen_size = get(0, 'ScreenSize');
    fig_width = min(1500, screen_size(3) - 100);
    fig_height = min(950, screen_size(4) - 100);
    fig_x = max(50, (screen_size(3) - fig_width) / 2);
    fig_y = max(50, (screen_size(4) - fig_height) / 2);

    fig = uifigure('Name', 'Trainingsdaten Vorbereitung', ...
                   'Position', [fig_x, fig_y, fig_width, fig_height], ...
                   'Color', [0.15, 0.15, 0.15]);

    % Haupt-Grid Layout: [Parameter Panel | Chart Panel | Statistik Panel]
    mainGrid = uigridlayout(fig, [1, 3]);
    mainGrid.ColumnWidth = {380, '1x', 320};
    mainGrid.Padding = [10 10 10 10];
    mainGrid.ColumnSpacing = 10;

    %% ============================================================
    %% LINKE SEITE: Parameter Panel (scrollbar für kleinere Bildschirme)
    %% ============================================================
    paramPanel = uipanel(mainGrid, 'Title', '', ...
                         'BackgroundColor', [0.18, 0.18, 0.18], ...
                         'Scrollable', 'on');
    paramPanel.Layout.Row = 1;
    paramPanel.Layout.Column = 1;

    paramGrid = uigridlayout(paramPanel, [9, 1]);
    paramGrid.RowHeight = {30, 'fit', 'fit', 'fit', 'fit', 'fit', 15, 45, 45};
    paramGrid.ColumnWidth = {'1x'};
    paramGrid.RowSpacing = 10;
    paramGrid.Padding = [10 10 10 10];

    % Titel
    param_title = uilabel(paramGrid, 'Text', 'Parameter Einstellungen', ...
                          'FontSize', 16, 'FontWeight', 'bold', ...
                          'FontColor', 'white', ...
                          'HorizontalAlignment', 'center');
    param_title.Layout.Row = 1;
    param_title.Layout.Column = 1;

    % --------------------------------------------------------
    % Gruppe 1: Sequenz-Parameter
    % --------------------------------------------------------
    seq_group = uipanel(paramGrid, 'Title', 'Sequenz-Parameter', ...
                        'FontSize', 13, 'FontWeight', 'bold', ...
                        'ForegroundColor', [0.3, 0.7, 1], ...
                        'BackgroundColor', [0.2, 0.2, 0.2]);
    seq_group.Layout.Row = 2;
    seq_group.Layout.Column = 1;

    seq_grid = uigridlayout(seq_group, [3, 1]);
    seq_grid.RowHeight = {'fit', 'fit', 28};
    seq_grid.ColumnWidth = {'1x'};
    seq_grid.RowSpacing = 8;
    seq_grid.Padding = [8 8 8 8];

    % ========== Lookback: Label links, Wert Mitte, Buttons rechts ==========
    lookback_container = uigridlayout(seq_grid, [1, 3]);
    lookback_container.Layout.Row = 1;
    lookback_container.ColumnWidth = {100, 80, 'fit'};
    lookback_container.RowHeight = {'fit'};
    lookback_container.Padding = [0 0 0 0];
    lookback_container.ColumnSpacing = 10;

    uilabel(lookback_container, 'Text', 'Lookback:', 'FontSize', 12, ...
            'FontColor', 'white', 'FontWeight', 'bold', ...
            'VerticalAlignment', 'center');

    lookback_value_label = uilabel(lookback_container, 'Text', sprintf('%d', params.lookback), ...
                                   'FontSize', 14, 'FontColor', [0.5, 0.9, 0.5], ...
                                   'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                                   'VerticalAlignment', 'center');

    % Lookback Buttons (2 Zeilen: + oben, - unten)
    lookback_buttons = uigridlayout(lookback_container, [2, 4]);
    lookback_buttons.ColumnWidth = {40, 40, 40, 40};
    lookback_buttons.RowHeight = {26, 26};
    lookback_buttons.Padding = [0 0 0 0];
    lookback_buttons.RowSpacing = 2;
    lookback_buttons.ColumnSpacing = 2;

    % Plus-Buttons (obere Zeile)
    uibutton(lookback_buttons, 'Text', '+1', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(1), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.55, 0.3], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '+5', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(5), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.5, 0.65], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '+10', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(10), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.5, 0.2], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '+50', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(50), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.3, 0.3], 'FontColor', 'white');

    % Minus-Buttons (untere Zeile)
    uibutton(lookback_buttons, 'Text', '-1', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(-1), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.3, 0.3], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '-5', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(-5), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.35, 0.3, 0.45], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '-10', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(-10), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.35, 0.2], 'FontColor', 'white');
    uibutton(lookback_buttons, 'Text', '-50', ...
        'ButtonPushedFcn', @(btn,e) adjustLookback(-50), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.2, 0.2], 'FontColor', 'white');

    % ========== Lookforward: Label links, Wert Mitte, Buttons rechts ==========
    lookforward_container = uigridlayout(seq_grid, [1, 3]);
    lookforward_container.Layout.Row = 2;
    lookforward_container.ColumnWidth = {100, 80, 'fit'};
    lookforward_container.RowHeight = {'fit'};
    lookforward_container.Padding = [0 0 0 0];
    lookforward_container.ColumnSpacing = 10;

    uilabel(lookforward_container, 'Text', 'Lookforward:', 'FontSize', 12, ...
            'FontColor', 'white', 'FontWeight', 'bold', ...
            'VerticalAlignment', 'center');

    lookforward_value_label = uilabel(lookforward_container, 'Text', sprintf('%d', params.lookforward), ...
                                      'FontSize', 14, 'FontColor', [0.5, 0.9, 0.5], ...
                                      'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                                      'VerticalAlignment', 'center');

    % Lookforward Buttons (2 Zeilen: + oben, - unten)
    lookforward_buttons = uigridlayout(lookforward_container, [2, 4]);
    lookforward_buttons.ColumnWidth = {40, 40, 40, 40};
    lookforward_buttons.RowHeight = {26, 26};
    lookforward_buttons.Padding = [0 0 0 0];
    lookforward_buttons.RowSpacing = 2;
    lookforward_buttons.ColumnSpacing = 2;

    % Plus-Buttons (obere Zeile)
    uibutton(lookforward_buttons, 'Text', '+1', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(1), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.55, 0.3], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '+5', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(5), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.5, 0.65], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '+10', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(10), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.5, 0.2], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '+50', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(50), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.3, 0.3], 'FontColor', 'white');

    % Minus-Buttons (untere Zeile)
    uibutton(lookforward_buttons, 'Text', '-1', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(-1), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.3, 0.3], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '-5', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(-5), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.35, 0.3, 0.45], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '-10', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(-10), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.35, 0.2], 'FontColor', 'white');
    uibutton(lookforward_buttons, 'Text', '-50', ...
        'ButtonPushedFcn', @(btn,e) adjustLookforward(-50), ...
        'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.2, 0.2], 'FontColor', 'white');

    % Sequenzlänge Info
    seq_info_label = uilabel(seq_grid, 'Text', '', 'FontSize', 12, ...
                             'FontColor', [0.7, 0.7, 0.7], ...
                             'HorizontalAlignment', 'center');
    seq_info_label.Layout.Row = 3;

    % --------------------------------------------------------
    % Gruppe 2: Feature-Auswahl
    % --------------------------------------------------------
    feature_group = uipanel(paramGrid, 'Title', 'Feature-Auswahl', ...
                            'FontSize', 13, 'FontWeight', 'bold', ...
                            'ForegroundColor', [1, 0.7, 0.3], ...
                            'BackgroundColor', [0.2, 0.2, 0.2]);
    feature_group.Layout.Row = 3;

    feature_grid = uigridlayout(feature_group, [3, 2]);
    feature_grid.RowHeight = {28, 28, 28};
    feature_grid.ColumnWidth = {'1x', '1x'};
    feature_grid.RowSpacing = 3;
    feature_grid.Padding = [8 8 8 8];

    cb_close = uicheckbox(feature_grid, 'Text', 'Close', 'Value', true, ...
                          'FontSize', 12, 'FontColor', 'white', ...
                          'ValueChangedFcn', @(cb,e) updateFeature('close', cb.Value));
    cb_high = uicheckbox(feature_grid, 'Text', 'High', 'Value', true, ...
                         'FontSize', 12, 'FontColor', 'white', ...
                         'ValueChangedFcn', @(cb,e) updateFeature('high', cb.Value));
    cb_low = uicheckbox(feature_grid, 'Text', 'Low', 'Value', true, ...
                        'FontSize', 12, 'FontColor', 'white', ...
                        'ValueChangedFcn', @(cb,e) updateFeature('low', cb.Value));
    cb_open = uicheckbox(feature_grid, 'Text', 'Open', 'Value', true, ...
                         'FontSize', 12, 'FontColor', 'white', ...
                         'ValueChangedFcn', @(cb,e) updateFeature('open', cb.Value));
    cb_change = uicheckbox(feature_grid, 'Text', 'Preisänderung', 'Value', true, ...
                           'FontSize', 12, 'FontColor', 'white', ...
                           'ValueChangedFcn', @(cb,e) updateFeature('price_change', cb.Value));
    cb_change_pct = uicheckbox(feature_grid, 'Text', 'Änderung (%)', 'Value', true, ...
                               'FontSize', 12, 'FontColor', 'white', ...
                               'ValueChangedFcn', @(cb,e) updateFeature('price_change_pct', cb.Value));

    % --------------------------------------------------------
    % Gruppe 3: HOLD-Samples
    % --------------------------------------------------------
    hold_group = uipanel(paramGrid, 'Title', 'HOLD-Samples (Negativ-Beispiele)', ...
                         'FontSize', 13, 'FontWeight', 'bold', ...
                         'ForegroundColor', [0.9, 0.5, 0.9], ...
                         'BackgroundColor', [0.2, 0.2, 0.2]);
    hold_group.Layout.Row = 4;

    hold_grid = uigridlayout(hold_group, [3, 3]);
    hold_grid.RowHeight = {28, 32, 32};
    hold_grid.ColumnWidth = {160, '1x', 55};
    hold_grid.RowSpacing = 5;
    hold_grid.Padding = [8 8 8 8];

    cb_include_hold = uicheckbox(hold_grid, 'Text', 'HOLD-Samples erstellen', ...
                                 'Value', true, 'FontSize', 12, 'FontColor', 'white', ...
                                 'ValueChangedFcn', @(cb,e) updateHoldEnabled(cb.Value));
    cb_include_hold.Layout.Column = [1, 3];

    uilabel(hold_grid, 'Text', 'Verhältnis zu Signalen:', 'FontSize', 12, ...
            'FontColor', 'white');
    hold_ratio_slider = uislider(hold_grid, 'Limits', [0.1, 3.0], ...
                                 'Value', params.hold_ratio, ...
                                 'ValueChangedFcn', @(s,e) updateHoldRatio(s.Value));
    hold_ratio_slider.Layout.Column = 2;
    hold_ratio_label = uilabel(hold_grid, 'Text', sprintf('%.1fx', params.hold_ratio), ...
                               'FontSize', 12, 'FontColor', 'white', ...
                               'HorizontalAlignment', 'right');
    hold_ratio_label.Layout.Column = 3;

    uilabel(hold_grid, 'Text', 'Min. Abstand Faktor:', 'FontSize', 12, ...
            'FontColor', 'white');
    distance_slider = uislider(hold_grid, 'Limits', [0.1, 0.5], ...
                               'Value', params.min_distance_factor, ...
                               'ValueChangedFcn', @(s,e) updateDistanceFactor(s.Value));
    distance_slider.Layout.Column = 2;
    distance_label = uilabel(hold_grid, 'Text', sprintf('%.1f', params.min_distance_factor), ...
                             'FontSize', 12, 'FontColor', 'white', ...
                             'HorizontalAlignment', 'right');
    distance_label.Layout.Column = 3;

    % --------------------------------------------------------
    % Gruppe 4: Normalisierung
    % --------------------------------------------------------
    norm_group = uipanel(paramGrid, 'Title', 'Normalisierung', ...
                         'FontSize', 13, 'FontWeight', 'bold', ...
                         'ForegroundColor', [0.5, 0.9, 0.7], ...
                         'BackgroundColor', [0.2, 0.2, 0.2]);
    norm_group.Layout.Row = 5;

    norm_grid = uigridlayout(norm_group, [2, 2]);
    norm_grid.RowHeight = {32, 32};
    norm_grid.ColumnWidth = {110, '1x'};
    norm_grid.RowSpacing = 5;
    norm_grid.Padding = [8 8 8 8];

    uilabel(norm_grid, 'Text', 'Methode:', 'FontSize', 12, 'FontColor', 'white');
    norm_dropdown = uidropdown(norm_grid, ...
                               'Items', {'Z-Score (Standard)', 'Min-Max [0,1]', 'Keine'}, ...
                               'ItemsData', {'zscore', 'minmax', 'none'}, ...
                               'Value', 'zscore', 'FontSize', 12, ...
                               'ValueChangedFcn', @(dd,e) updateNormMethod(dd.Value));

    uilabel(norm_grid, 'Text', 'Random Seed:', 'FontSize', 12, 'FontColor', 'white');
    seed_field = uieditfield(norm_grid, 'numeric', 'Value', 42, ...
                             'Limits', [0, 99999], 'FontSize', 12, ...
                             'ValueChangedFcn', @(f,e) updateSeed(f.Value));

    % --------------------------------------------------------
    % Gruppe 5: Daten-Info
    % --------------------------------------------------------
    data_group = uipanel(paramGrid, 'Title', 'Geladene Daten', ...
                         'FontSize', 13, 'FontWeight', 'bold', ...
                         'ForegroundColor', [0.7, 0.7, 0.7], ...
                         'BackgroundColor', [0.2, 0.2, 0.2]);
    data_group.Layout.Row = 6;

    data_grid = uigridlayout(data_group, [4, 2]);
    data_grid.RowHeight = {26, 26, 26, 26};
    data_grid.ColumnWidth = {120, '1x'};
    data_grid.RowSpacing = 2;
    data_grid.Padding = [8 8 8 8];

    uilabel(data_grid, 'Text', 'Datenpunkte:', 'FontSize', 12, 'FontColor', [0.7, 0.7, 0.7]);
    uilabel(data_grid, 'Text', sprintf('%d', total_points), 'FontSize', 12, ...
            'FontColor', 'white', 'FontWeight', 'bold');

    uilabel(data_grid, 'Text', 'Zeitraum:', 'FontSize', 12, 'FontColor', [0.7, 0.7, 0.7]);
    date_range_label = uilabel(data_grid, 'Text', sprintf('%s - %s', ...
            datestr(data.DateTime(1), 'dd.mm.yy'), ...
            datestr(data.DateTime(end), 'dd.mm.yy')), ...
            'FontSize', 11, 'FontColor', 'white');

    uilabel(data_grid, 'Text', 'Preisbereich:', 'FontSize', 12, 'FontColor', [0.7, 0.7, 0.7]);
    uilabel(data_grid, 'Text', sprintf('%.0f - %.0f USD', min(data.Close), max(data.Close)), ...
            'FontSize', 12, 'FontColor', 'white');

    uilabel(data_grid, 'Text', 'Tages-Extrema:', 'FontSize', 12, 'FontColor', [0.7, 0.7, 0.7]);
    extrema_count_label = uilabel(data_grid, 'Text', 'Berechne...', 'FontSize', 12, ...
                                   'FontColor', [0.5, 0.9, 0.5]);

    % Spacer (Row 7 ist leer für Abstand)

    % Status-Label
    status_label = uilabel(paramGrid, 'Text', 'Bitte Parameter einstellen und Vorschau berechnen.', ...
                           'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7], ...
                           'HorizontalAlignment', 'center', ...
                           'WordWrap', 'on');
    status_label.Layout.Row = 7;

    % Buttons
    preview_btn = uibutton(paramGrid, 'Text', 'Vorschau berechnen', ...
                           'ButtonPushedFcn', @(btn,e) computePreview(), ...
                           'BackgroundColor', [0.3, 0.6, 0.9], ...
                           'FontColor', 'white', ...
                           'FontSize', 14, 'FontWeight', 'bold');
    preview_btn.Layout.Row = 8;

    apply_btn = uibutton(paramGrid, 'Text', 'Daten generieren & Schließen', ...
                         'ButtonPushedFcn', @(btn,e) applyAndClose(), ...
                         'BackgroundColor', [0.3, 0.7, 0.3], ...
                         'FontColor', 'white', ...
                         'FontSize', 14, 'FontWeight', 'bold', ...
                         'Enable', 'off');
    apply_btn.Layout.Row = 9;

    %% ============================================================
    %% MITTE: Chart Panel
    %% ============================================================
    chartPanel = uipanel(mainGrid, 'Title', 'Preischart mit Signalen', ...
                         'FontSize', 13, 'FontWeight', 'bold', ...
                         'ForegroundColor', [0.3, 0.7, 1], ...
                         'BackgroundColor', [0.18, 0.18, 0.18]);
    chartPanel.Layout.Row = 1;
    chartPanel.Layout.Column = 2;

    chartGrid = uigridlayout(chartPanel, [1, 1]);
    chartGrid.Padding = [5 5 5 5];

    ax_preview = uiaxes(chartGrid);
    ax_preview.Color = [0.1, 0.1, 0.1];
    ax_preview.XColor = 'white';
    ax_preview.YColor = 'white';
    ax_preview.FontSize = 10;
    grid(ax_preview, 'on');
    ax_preview.GridColor = [0.3, 0.3, 0.3];
    xlabel(ax_preview, 'Zeit', 'Color', 'white', 'FontSize', 11);
    ylabel(ax_preview, 'Preis (USD)', 'Color', 'white', 'FontSize', 11);
    hold(ax_preview, 'on');

    %% ============================================================
    %% RECHTE SEITE: Statistik Panel mit Tabelle
    %% ============================================================
    statsPanel = uipanel(mainGrid, 'Title', 'Ergebnis-Statistiken', ...
                         'FontSize', 13, 'FontWeight', 'bold', ...
                         'ForegroundColor', [1, 0.7, 0.3], ...
                         'BackgroundColor', [0.18, 0.18, 0.18]);
    statsPanel.Layout.Row = 1;
    statsPanel.Layout.Column = 3;

    statsGrid = uigridlayout(statsPanel, [2, 1]);
    statsGrid.RowHeight = {'1x', 'fit'};
    statsGrid.ColumnWidth = {'1x'};
    statsGrid.RowSpacing = 10;
    statsGrid.Padding = [10 10 10 10];

    % Statistik-Tabelle
    stats_table = uitable(statsGrid, ...
                          'ColumnName', {'Parameter', 'Wert'}, ...
                          'ColumnWidth', {140, 120}, ...
                          'RowName', {}, ...
                          'FontSize', 11, ...
                          'BackgroundColor', [0.2, 0.2, 0.2; 0.25, 0.25, 0.25], ...
                          'ForegroundColor', 'white');
    stats_table.Layout.Row = 1;

    % Initiale Tabellendaten
    stats_table.Data = {
        'BUY Signale', '0';
        'SELL Signale', '0';
        'HOLD Samples', '0';
        'Gesamt', '0';
        '---', '---';
        'Sequenzlänge', '0';
        'Features', '0';
        'Input Shape', '-';
        'Balance', '-';
        '---', '---';
        'Lookback', sprintf('%d', params.lookback);
        'Lookforward', sprintf('%d', params.lookforward);
        'Normalisierung', params.normalize_method
    };

    % Legende unter der Tabelle
    legend_panel = uipanel(statsGrid, 'Title', 'Legende', ...
                           'FontSize', 11, 'FontWeight', 'bold', ...
                           'ForegroundColor', [0.7, 0.7, 0.7], ...
                           'BackgroundColor', [0.2, 0.2, 0.2]);
    legend_panel.Layout.Row = 2;

    legend_grid = uigridlayout(legend_panel, [3, 2]);
    legend_grid.RowHeight = {20, 20, 20};
    legend_grid.ColumnWidth = {25, '1x'};
    legend_grid.Padding = [8 5 8 5];
    legend_grid.RowSpacing = 2;
    legend_grid.ColumnSpacing = 5;

    % BUY Legende (grün)
    buy_marker = uilabel(legend_grid, 'Text', '^', ...
                         'FontSize', 16, 'FontWeight', 'bold', ...
                         'FontColor', [0.2, 0.8, 0.2], ...
                         'HorizontalAlignment', 'center');
    uilabel(legend_grid, 'Text', 'BUY (Tief)', ...
            'FontSize', 11, 'FontColor', 'white');

    % SELL Legende (rot)
    sell_marker = uilabel(legend_grid, 'Text', 'v', ...
                          'FontSize', 16, 'FontWeight', 'bold', ...
                          'FontColor', [0.9, 0.2, 0.2], ...
                          'HorizontalAlignment', 'center');
    uilabel(legend_grid, 'Text', 'SELL (Hoch)', ...
            'FontSize', 11, 'FontColor', 'white');

    % Ungültig Legende (leer)
    invalid_marker = uilabel(legend_grid, 'Text', 'o', ...
                             'FontSize', 14, ...
                             'FontColor', [0.5, 0.5, 0.5], ...
                             'HorizontalAlignment', 'center');
    uilabel(legend_grid, 'Text', 'Ungültig (Randbereich)', ...
            'FontSize', 11, 'FontColor', [0.6, 0.6, 0.6]);

    %% Initialisierung
    updateSeqInfo();
    findExtrema();

    %% ============================================================
    %% CALLBACK-FUNKTIONEN
    %% ============================================================

    function adjustLookback(amount)
        new_value = params.lookback + amount;
        if new_value >= 1 && new_value <= total_points - params.lookforward - 1
            params.lookback = new_value;
            lookback_value_label.Text = sprintf('%d', params.lookback);
            updateSeqInfo();
            preview_computed = false;
            apply_btn.Enable = 'off';
        end
    end

    function adjustLookforward(amount)
        new_value = params.lookforward + amount;
        if new_value >= 1 && new_value <= total_points - params.lookback - 1
            params.lookforward = new_value;
            lookforward_value_label.Text = sprintf('%d', params.lookforward);
            updateSeqInfo();
            preview_computed = false;
            apply_btn.Enable = 'off';
        end
    end

    function updateSeqInfo()
        total_seq = params.lookback + params.lookforward;
        seq_info_label.Text = sprintf('Sequenzlänge: %d Datenpunkte', total_seq);
    end

    function updateFeature(feature, value)
        switch feature
            case 'close'
                params.use_close = value;
            case 'high'
                params.use_high = value;
            case 'low'
                params.use_low = value;
            case 'open'
                params.use_open = value;
            case 'price_change'
                params.use_price_change = value;
            case 'price_change_pct'
                params.use_price_change_pct = value;
        end
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function updateHoldEnabled(value)
        params.include_hold = value;
        hold_ratio_slider.Enable = value;
        distance_slider.Enable = value;
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function updateHoldRatio(value)
        params.hold_ratio = value;
        hold_ratio_label.Text = sprintf('%.1fx', value);
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function updateDistanceFactor(value)
        params.min_distance_factor = value;
        distance_label.Text = sprintf('%.1f', value);
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function updateNormMethod(value)
        params.normalize_method = value;
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function updateSeed(value)
        params.random_seed = round(value);
        preview_computed = false;
        apply_btn.Enable = 'off';
    end

    function findExtrema()
        try
            [high_points, low_points] = find_daily_extrema(data);
            extrema_count_label.Text = sprintf('%d Hochs, %d Tiefs', ...
                                               length(high_points), length(low_points));

            % Zeichne initialen Chart
            cla(ax_preview);
            hold(ax_preview, 'on');

            plot(ax_preview, data.DateTime, data.Close, 'w-', 'LineWidth', 1);

            % Markiere Hochs
            for i = 1:length(high_points)
                plot(ax_preview, high_points(i).DateTime, high_points(i).Price, ...
                     'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
            end

            % Markiere Tiefs
            for i = 1:length(low_points)
                plot(ax_preview, low_points(i).DateTime, low_points(i).Price, ...
                     'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
            end

            hold(ax_preview, 'off');

        catch ME
            extrema_count_label.Text = 'Fehler';
            warning('Extrema-Berechnung fehlgeschlagen: %s', ME.message);
        end
    end

    function computePreview()
        t_func = tic_if_enabled();
        logMsg('Berechne Vorschau...', 'debug');
        status_label.Text = 'Berechne Vorschau...';
        status_label.FontColor = [1, 1, 0.5];
        drawnow;

        try
            % Trainingsdaten mit aktuellen Parametern berechnen
            t_prepare = tic_if_enabled();
            [result_X, result_Y, result_info] = prepareDataWithParams();
            toc_log(t_prepare, 'prepareDataWithParams');

            % Input Shape und Balance berechnen
            input_shape_str = '-';
            balance_str = '-';
            if ~isempty(result_X)
                input_shape = size(result_X{1});
                input_shape_str = sprintf('%dx%d', input_shape(1), input_shape(2));
            end
            total_signals = result_info.num_buy + result_info.num_sell;
            if total_signals > 0
                balance_ratio = result_info.num_hold / total_signals;
                balance_str = sprintf('%.2f:1', balance_ratio);
            end

            % Statistik-Tabelle aktualisieren
            stats_table.Data = {
                'BUY Signale', sprintf('%d', result_info.num_buy);
                'SELL Signale', sprintf('%d', result_info.num_sell);
                'HOLD Samples', sprintf('%d', result_info.num_hold);
                'Gesamt', sprintf('%d', result_info.total_sequences);
                '---', '---';
                'Sequenzlänge', sprintf('%d', result_info.sequence_length);
                'Features', sprintf('%d', result_info.num_features);
                'Input Shape', input_shape_str;
                'Balance', balance_str;
                '---', '---';
                'Lookback', sprintf('%d', params.lookback);
                'Lookforward', sprintf('%d', params.lookforward);
                'Normalisierung', params.normalize_method
            };

            % Chart aktualisieren
            t_chart = tic_if_enabled();
            updatePreviewChart();
            toc_log(t_chart, 'updatePreviewChart');

            preview_computed = true;
            apply_btn.Enable = 'on';

            status_label.Text = sprintf('Vorschau: %d Sequenzen', result_info.total_sequences);
            status_label.FontColor = [0.5, 1, 0.5];
            logMsg(sprintf('Vorschau: %d Sequenzen (BUY:%d SELL:%d HOLD:%d)', ...
                   result_info.total_sequences, result_info.num_buy, result_info.num_sell, result_info.num_hold), 'success');

        catch ME
            status_label.Text = sprintf('Fehler: %s', ME.message);
            status_label.FontColor = [1, 0.5, 0.5];
            preview_computed = false;
            apply_btn.Enable = 'off';
            logMsg(sprintf('Fehler bei Vorschau: %s', ME.message), 'error');
        end
        toc_log(t_func, 'computePreview');
    end

    function [X, Y, info] = prepareDataWithParams()
        % Verwende absolute Werte für Sequenzlängen
        lookback_size = params.lookback;
        lookforward_size = params.lookforward;
        sequence_length = lookback_size + lookforward_size;

        % Features zusammenstellen
        features = [];
        feature_names = {};

        if params.use_close
            features = [features, data.Close];
            feature_names{end+1} = 'Close';
        end
        if params.use_high
            features = [features, data.High];
            feature_names{end+1} = 'High';
        end
        if params.use_low
            features = [features, data.Low];
            feature_names{end+1} = 'Low';
        end
        if params.use_open
            features = [features, data.Open];
            feature_names{end+1} = 'Open';
        end
        if params.use_price_change
            price_change = [0; diff(data.Close)];
            features = [features, price_change];
            feature_names{end+1} = 'PriceChange';
        end
        if params.use_price_change_pct
            price_change_pct = [0; (diff(data.Close) ./ data.Close(1:end-1)) * 100];
            features = [features, price_change_pct];
            feature_names{end+1} = 'PriceChangePct';
        end

        if isempty(features)
            error('Mindestens ein Feature muss ausgewählt werden.');
        end

        % Extrema finden
        t_extrema = tic_if_enabled();
        [high_points, low_points] = find_daily_extrema(data);
        toc_log(t_extrema, 'find_daily_extrema');

        % Debug-Info: Anzahl gefundener Extrema
        fprintf('Debug: high_points=%d, low_points=%d\n', length(high_points), length(low_points));

        % Index-Mapping
        datetime_to_idx = containers.Map();
        for i = 1:height(data)
            datetime_to_idx(char(data.DateTime(i))) = i;
        end

        X = {};
        Y = {};

        % SELL-Signale (Hochs)
        num_sell = 0;
        for i = 1:length(high_points)
            key = char(high_points(i).DateTime);
            if isKey(datetime_to_idx, key)
                idx = datetime_to_idx(key);
                if idx > lookback_size && idx + lookforward_size <= total_points
                    start_idx = idx - lookback_size;
                    end_idx = idx + lookforward_size - 1;

                    sequence = features(start_idx:end_idx, :);
                    sequence_norm = normalizeSequence(sequence);

                    X{end+1} = sequence_norm';
                    Y{end+1} = categorical(2);
                    num_sell = num_sell + 1;
                end
            end
        end

        % BUY-Signale (Tiefs)
        num_buy = 0;
        for i = 1:length(low_points)
            key = char(low_points(i).DateTime);
            if isKey(datetime_to_idx, key)
                idx = datetime_to_idx(key);
                if idx > lookback_size && idx + lookforward_size <= total_points
                    start_idx = idx - lookback_size;
                    end_idx = idx + lookforward_size - 1;

                    sequence = features(start_idx:end_idx, :);
                    sequence_norm = normalizeSequence(sequence);

                    X{end+1} = sequence_norm';
                    Y{end+1} = categorical(1);
                    num_buy = num_buy + 1;
                end
            end
        end

        % Debug: BUY/SELL Samples erstellt
        fprintf('Debug: num_sell=%d, num_buy=%d\n', num_sell, num_buy);

        % HOLD-Samples
        num_hold = 0;
        if params.include_hold
            t_hold = tic_if_enabled();
            num_hold_target = round((num_buy + num_sell) * params.hold_ratio);

            % Sammle Extrema-Indizes
            extrema_indices = [];
            for i = 1:length(high_points)
                key = char(high_points(i).DateTime);
                if isKey(datetime_to_idx, key)
                    extrema_indices(end+1) = datetime_to_idx(key);
                end
            end
            for i = 1:length(low_points)
                key = char(low_points(i).DateTime);
                if isKey(datetime_to_idx, key)
                    extrema_indices(end+1) = datetime_to_idx(key);
                end
            end

            rng(params.random_seed);
            min_distance_original = round(sequence_length * params.min_distance_factor);
            min_distance = min_distance_original;
            max_attempts_per_round = num_hold_target * 50;
            attempts = 0;
            total_attempts = 0;

            % Debug-Info
            fprintf('HOLD-Debug: num_hold_target=%d, num_extrema=%d, min_distance=%d\n', ...
                    num_hold_target, length(extrema_indices), min_distance);
            fprintf('HOLD-Debug: total_points=%d, valid_range=[%d, %d]\n', ...
                    total_points, lookback_size + 1, total_points - lookforward_size);

            % Mehrere Versuche mit abnehmender Distanz
            while num_hold < num_hold_target && min_distance >= 1
                attempts = 0;
                while num_hold < num_hold_target && attempts < max_attempts_per_round
                    attempts = attempts + 1;
                    total_attempts = total_attempts + 1;
                    rand_idx = randi([lookback_size + 1, total_points - lookforward_size]);

                    % Pruefe Abstand zum NAECHSTEN Extremum (nicht zu allen)
                    if isempty(extrema_indices)
                        is_far = true;
                    else
                        nearest_distance = min(abs(extrema_indices - rand_idx));
                        is_far = nearest_distance > min_distance;
                    end

                    if is_far
                        start_idx = rand_idx - lookback_size;
                        end_idx = rand_idx + lookforward_size - 1;

                        sequence = features(start_idx:end_idx, :);
                        sequence_norm = normalizeSequence(sequence);

                        X{end+1} = sequence_norm';
                        Y{end+1} = categorical(0);
                        num_hold = num_hold + 1;
                    end
                end

                % Falls nicht genug gefunden, reduziere min_distance
                if num_hold < num_hold_target
                    min_distance = round(min_distance * 0.5);
                    fprintf('HOLD-Debug: Reduziere min_distance auf %d (num_hold=%d)\n', min_distance, num_hold);
                end
            end

            % Debug: Anzahl gefundene HOLD samples
            fprintf('HOLD-Debug: total_attempts=%d, num_hold=%d, final_min_distance=%d\n', ...
                    total_attempts, num_hold, min_distance);
            toc_log(t_hold, 'HOLD-Sample generation');
        end

        X = X';
        Y = Y';

        % Info-Struct
        info = struct();
        info.total_sequences = length(X);
        info.num_buy = num_buy;
        info.num_sell = num_sell;
        info.num_hold = num_hold;
        info.sequence_length = sequence_length;
        info.lookback_size = lookback_size;
        info.lookforward_size = lookforward_size;
        info.num_features = size(features, 2);
        info.feature_names = feature_names;
        info.classes = {'HOLD', 'BUY', 'SELL'};
        info.params = params;
    end

    function seq_norm = normalizeSequence(sequence)
        switch params.normalize_method
            case 'zscore'
                seq_norm = normalize(sequence, 'zscore');
            case 'minmax'
                seq_norm = normalize(sequence, 'range');
            case 'none'
                seq_norm = sequence;
            otherwise
                seq_norm = normalize(sequence, 'zscore');
        end
    end

    function updatePreviewChart()
        cla(ax_preview);
        hold(ax_preview, 'on');

        % Preis-Linie
        plot(ax_preview, data.DateTime, data.Close, 'w-', 'LineWidth', 1);

        % Extrema finden und markieren
        [high_points, low_points] = find_daily_extrema(data);

        lookback_size = params.lookback;
        lookforward_size = params.lookforward;

        % Gültige Hochs markieren (rot)
        datetime_to_idx = containers.Map();
        for i = 1:height(data)
            datetime_to_idx(char(data.DateTime(i))) = i;
        end

        for i = 1:length(high_points)
            key = char(high_points(i).DateTime);
            if isKey(datetime_to_idx, key)
                idx = datetime_to_idx(key);
                if idx > lookback_size && idx + lookforward_size <= total_points
                    plot(ax_preview, high_points(i).DateTime, high_points(i).Price, ...
                         'rv', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
                else
                    plot(ax_preview, high_points(i).DateTime, high_points(i).Price, ...
                         'rv', 'MarkerSize', 6, 'MarkerFaceColor', 'none', 'LineWidth', 1);
                end
            end
        end

        % Gültige Tiefs markieren (grün)
        for i = 1:length(low_points)
            key = char(low_points(i).DateTime);
            if isKey(datetime_to_idx, key)
                idx = datetime_to_idx(key);
                if idx > lookback_size && idx + lookforward_size <= total_points
                    plot(ax_preview, low_points(i).DateTime, low_points(i).Price, ...
                         'g^', 'MarkerSize', 10, 'MarkerFaceColor', 'g', 'LineWidth', 2);
                else
                    plot(ax_preview, low_points(i).DateTime, low_points(i).Price, ...
                         'g^', 'MarkerSize', 6, 'MarkerFaceColor', 'none', 'LineWidth', 1);
                end
            end
        end

        title(ax_preview, sprintf('Signale: %d BUY, %d SELL | Gefüllt = gültig', ...
              result_info.num_buy, result_info.num_sell), 'Color', 'white', 'FontSize', 11);

        hold(ax_preview, 'off');
    end

    function applyAndClose()
        t_func = tic_if_enabled();
        if preview_computed && ~isempty(result_X)
            % Speichere Ergebnisse im Base Workspace
            logMsg('Speichere Trainingsdaten in Workspace...', 'debug');
            t_assign = tic_if_enabled();
            assignin('base', 'X_train', result_X);
            assignin('base', 'Y_train', result_Y);
            assignin('base', 'training_info', result_info);
            toc_log(t_assign, 'assignin (Workspace)');

            logMsg(sprintf('Trainingsdaten generiert: %d Sequenzen, %d Features, Seq-Länge: %d', ...
                   length(result_X), result_info.num_features, result_info.sequence_length), 'success');

            toc_log(t_func, 'applyAndClose');

            % GUI schließen
            close(fig);
        end
    end

    %% Hilfsfunktion: Zeitmessung starten
    function t = tic_if_enabled()
        if enable_timing
            t = tic;
        else
            t = [];
        end
    end

    %% Hilfsfunktion: Zeitmessung stoppen und ausgeben
    function toc_log(t, func_name)
        if ~isempty(t) && enable_timing
            elapsed = toc(t);
            if elapsed < 1
                time_str = sprintf('%.1f ms', elapsed * 1000);
            elseif elapsed < 60
                time_str = sprintf('%.2f s', elapsed);
            else
                time_str = sprintf('%.1f min', elapsed / 60);
            end
            log_func(sprintf('[TIMING] %s: %s', func_name, time_str), 'trace');
        end
    end

    %% Hilfsfunktion: Log-Nachricht senden
    function logMsg(msg, level)
        log_func(msg, level);
    end

end
