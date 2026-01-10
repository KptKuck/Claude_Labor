function btc_analyzer_gui()
% BTC_ANALYZER_GUI Hauptfenster für BTCUSD Datenanalyse
%
%   btc_analyzer_gui() öffnet ein GUI-Fenster mit folgenden Funktionen:
%   - Laden von lokalen CSV-Dateien
%   - Download von Daten über Binance API
%   - Einstellung von Datum und Intervall
%   - Datenanalyse und Visualisierung

    % Hauptfenster erstellen
    fig = uifigure('Name', 'BTCUSD Analyzer', ...
                   'Position', [100, 100, 1200, 850]);

    % Grid Layout für strukturierte Anordnung: 2 Spalten (Bedienelemente | Logger)
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.ColumnWidth = {420, '1x'};  % Linke Spalte 420px, rechte Spalte flexibel
    mainGrid.Padding = [10 10 10 10];
    mainGrid.ColumnSpacing = 10;

    % Linkes Panel: Bedienelemente
    leftPanel = uigridlayout(mainGrid);
    leftPanel.Layout.Row = 1;
    leftPanel.Layout.Column = 1;
    leftPanel.RowHeight = {50, 'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
    leftPanel.ColumnWidth = {'1x'};
    leftPanel.RowSpacing = 10;
    leftPanel.Padding = [5 5 5 5];

    % Rechtes Panel: Logger
    rightPanel = uigridlayout(mainGrid);
    rightPanel.Layout.Row = 1;
    rightPanel.Layout.Column = 2;
    rightPanel.RowHeight = {30, '1x'};  % Header + Logger
    rightPanel.ColumnWidth = {'1x'};
    rightPanel.RowSpacing = 5;
    rightPanel.Padding = [5 5 5 5];

    % === LINKES PANEL: Bedienelemente ===

    % Titel
    title_label = uilabel(leftPanel, 'Text', 'BTCUSD Analyzer', ...
                          'FontSize', 18, 'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'center');
    title_label.Layout.Row = 1;
    title_label.Layout.Column = 1;

    % ============================================================
    % GRUPPE 1: Daten Laden (mit Untergruppen)
    % ============================================================
    load_group = uipanel(leftPanel, 'Title', '');
    load_group.Layout.Row = 2;
    load_group.Layout.Column = 1;

    load_grid = uigridlayout(load_group, [3, 1]);
    load_grid.RowHeight = {25, 'fit', 'fit'};
    load_grid.ColumnWidth = {'1x'};
    load_grid.RowSpacing = 8;
    load_grid.Padding = [10 10 10 10];

    % Hauptgruppen-Titel
    load_title = uilabel(load_grid, 'Text', 'Daten Laden', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'HorizontalAlignment', 'center', ...
                         'BackgroundColor', [0.2, 0.4, 0.6], ...
                         'FontColor', 'white');
    load_title.Layout.Row = 1;
    load_title.Layout.Column = 1;

    % --------------------------------------------------------
    % Untergruppe 1.1: Lokale Datei
    % --------------------------------------------------------
    local_subgroup = uipanel(load_grid, 'Title', 'Lokale Datei', ...
                             'FontSize', 10, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.15, 0.15, 0.15]);
    local_subgroup.Layout.Row = 2;
    local_subgroup.Layout.Column = 1;

    local_grid = uigridlayout(local_subgroup, [1, 1]);
    local_grid.RowHeight = {35};
    local_grid.ColumnWidth = {'1x'};
    local_grid.Padding = [8 8 8 8];

    load_file_btn = uibutton(local_grid, 'Text', 'CSV Datei öffnen...', ...
                             'ButtonPushedFcn', @(btn,event) loadLocalFile(), ...
                             'FontSize', 11, 'FontWeight', 'bold', ...
                             'BackgroundColor', [0.4, 0.4, 0.4], ...
                             'FontColor', 'white', ...
                             'Icon', '');
    load_file_btn.Layout.Row = 1;
    load_file_btn.Layout.Column = 1;

    % --------------------------------------------------------
    % Untergruppe 1.2: Binance Download
    % --------------------------------------------------------
    binance_subgroup = uipanel(load_grid, 'Title', 'Binance API Download', ...
                               'FontSize', 10, 'FontWeight', 'bold', ...
                               'BackgroundColor', [0.15, 0.15, 0.15]);
    binance_subgroup.Layout.Row = 3;
    binance_subgroup.Layout.Column = 1;

    binance_grid = uigridlayout(binance_subgroup, [4, 1]);
    binance_grid.RowHeight = {'fit', 'fit', 30, 35};
    binance_grid.ColumnWidth = {'1x'};
    binance_grid.RowSpacing = 8;
    binance_grid.Padding = [8 8 8 8];

    % ========== Von-Datum: Datumfeld links, Buttons rechts ==========
    from_container = uigridlayout(binance_grid, [1, 2]);
    from_container.Layout.Row = 1;
    from_container.Layout.Column = 1;
    from_container.ColumnWidth = {'1x', 'fit'};
    from_container.RowHeight = {'fit'};
    from_container.Padding = [0 0 0 0];
    from_container.ColumnSpacing = 8;

    % Von: Linke Seite - Label und Datepicker
    from_left = uigridlayout(from_container, [1, 2]);
    from_left.Layout.Row = 1;
    from_left.Layout.Column = 1;
    from_left.ColumnWidth = {35, '1x'};
    from_left.RowHeight = {50};
    from_left.Padding = [0 0 0 0];
    from_left.ColumnSpacing = 5;

    uilabel(from_left, 'Text', 'Von:', 'FontSize', 10, 'FontWeight', 'bold', ...
            'VerticalAlignment', 'center');
    from_date_picker = uidatepicker(from_left, 'Value', datetime('2025-09-01'), 'FontSize', 10);
    from_date_picker.Layout.Column = 2;

    % Von: Rechte Seite - Buttons (2 Zeilen: + oben, - unten)
    from_buttons = uigridlayout(from_container, [2, 4]);
    from_buttons.Layout.Row = 1;
    from_buttons.Layout.Column = 2;
    from_buttons.ColumnWidth = {45, 45, 45, 45};
    from_buttons.RowHeight = {24, 24};
    from_buttons.Padding = [0 0 0 0];
    from_buttons.RowSpacing = 2;
    from_buttons.ColumnSpacing = 2;

    % Von: Plus-Buttons (obere Zeile)
    btn_from_plus_day = uibutton(from_buttons, 'Text', '+T', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, 1, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.55, 0.3], 'FontColor', 'white', ...
        'Tooltip', '+1 Tag');
    btn_from_plus_day.Layout.Row = 1;
    btn_from_plus_day.Layout.Column = 1;

    btn_from_plus_week = uibutton(from_buttons, 'Text', '+W', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, 7, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.5, 0.65], 'FontColor', 'white', ...
        'Tooltip', '+1 Woche');
    btn_from_plus_week.Layout.Row = 1;
    btn_from_plus_week.Layout.Column = 2;

    btn_from_plus_month = uibutton(from_buttons, 'Text', '+M', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, 1, 'month'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.5, 0.2], 'FontColor', 'white', ...
        'Tooltip', '+1 Monat');
    btn_from_plus_month.Layout.Row = 1;
    btn_from_plus_month.Layout.Column = 3;

    btn_from_plus_year = uibutton(from_buttons, 'Text', '+J', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, 1, 'year'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.3, 0.3], 'FontColor', 'white', ...
        'Tooltip', '+1 Jahr');
    btn_from_plus_year.Layout.Row = 1;
    btn_from_plus_year.Layout.Column = 4;

    % Von: Minus-Buttons (untere Zeile)
    btn_from_minus_day = uibutton(from_buttons, 'Text', '-T', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, -1, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.3, 0.3], 'FontColor', 'white', ...
        'Tooltip', '-1 Tag');
    btn_from_minus_day.Layout.Row = 2;
    btn_from_minus_day.Layout.Column = 1;

    btn_from_minus_week = uibutton(from_buttons, 'Text', '-W', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, -7, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.35, 0.3, 0.45], 'FontColor', 'white', ...
        'Tooltip', '-1 Woche');
    btn_from_minus_week.Layout.Row = 2;
    btn_from_minus_week.Layout.Column = 2;

    btn_from_minus_month = uibutton(from_buttons, 'Text', '-M', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, -1, 'month'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.35, 0.2], 'FontColor', 'white', ...
        'Tooltip', '-1 Monat');
    btn_from_minus_month.Layout.Row = 2;
    btn_from_minus_month.Layout.Column = 3;

    btn_from_minus_year = uibutton(from_buttons, 'Text', '-J', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(from_date_picker, -1, 'year'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.2, 0.2], 'FontColor', 'white', ...
        'Tooltip', '-1 Jahr');
    btn_from_minus_year.Layout.Row = 2;
    btn_from_minus_year.Layout.Column = 4;

    % ========== Bis-Datum: Datumfeld links, Buttons rechts ==========
    to_container = uigridlayout(binance_grid, [1, 2]);
    to_container.Layout.Row = 2;
    to_container.Layout.Column = 1;
    to_container.ColumnWidth = {'1x', 'fit'};
    to_container.RowHeight = {'fit'};
    to_container.Padding = [0 0 0 0];
    to_container.ColumnSpacing = 8;

    % Bis: Linke Seite - Label und Datepicker
    to_left = uigridlayout(to_container, [1, 2]);
    to_left.Layout.Row = 1;
    to_left.Layout.Column = 1;
    to_left.ColumnWidth = {35, '1x'};
    to_left.RowHeight = {50};
    to_left.Padding = [0 0 0 0];
    to_left.ColumnSpacing = 5;

    uilabel(to_left, 'Text', 'Bis:', 'FontSize', 10, 'FontWeight', 'bold', ...
            'VerticalAlignment', 'center');
    to_date_picker = uidatepicker(to_left, 'Value', datetime('today'), 'FontSize', 10);
    to_date_picker.Layout.Column = 2;

    % Bis: Rechte Seite - Buttons (2 Zeilen: + oben, - unten)
    to_buttons = uigridlayout(to_container, [2, 4]);
    to_buttons.Layout.Row = 1;
    to_buttons.Layout.Column = 2;
    to_buttons.ColumnWidth = {45, 45, 45, 45};
    to_buttons.RowHeight = {24, 24};
    to_buttons.Padding = [0 0 0 0];
    to_buttons.RowSpacing = 2;
    to_buttons.ColumnSpacing = 2;

    % Bis: Plus-Buttons (obere Zeile)
    btn_to_plus_day = uibutton(to_buttons, 'Text', '+T', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, 1, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.55, 0.3], 'FontColor', 'white', ...
        'Tooltip', '+1 Tag');
    btn_to_plus_day.Layout.Row = 1;
    btn_to_plus_day.Layout.Column = 1;

    btn_to_plus_week = uibutton(to_buttons, 'Text', '+W', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, 7, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.3, 0.5, 0.65], 'FontColor', 'white', ...
        'Tooltip', '+1 Woche');
    btn_to_plus_week.Layout.Row = 1;
    btn_to_plus_week.Layout.Column = 2;

    btn_to_plus_month = uibutton(to_buttons, 'Text', '+M', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, 1, 'month'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.5, 0.2], 'FontColor', 'white', ...
        'Tooltip', '+1 Monat');
    btn_to_plus_month.Layout.Row = 1;
    btn_to_plus_month.Layout.Column = 3;

    btn_to_plus_year = uibutton(to_buttons, 'Text', '+J', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, 1, 'year'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.65, 0.3, 0.3], 'FontColor', 'white', ...
        'Tooltip', '+1 Jahr');
    btn_to_plus_year.Layout.Row = 1;
    btn_to_plus_year.Layout.Column = 4;

    % Bis: Minus-Buttons (untere Zeile)
    btn_to_minus_day = uibutton(to_buttons, 'Text', '-T', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, -1, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.3, 0.3], 'FontColor', 'white', ...
        'Tooltip', '-1 Tag');
    btn_to_minus_day.Layout.Row = 2;
    btn_to_minus_day.Layout.Column = 1;

    btn_to_minus_week = uibutton(to_buttons, 'Text', '-W', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, -7, 'day'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.35, 0.3, 0.45], 'FontColor', 'white', ...
        'Tooltip', '-1 Woche');
    btn_to_minus_week.Layout.Row = 2;
    btn_to_minus_week.Layout.Column = 2;

    btn_to_minus_month = uibutton(to_buttons, 'Text', '-M', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, -1, 'month'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.35, 0.2], 'FontColor', 'white', ...
        'Tooltip', '-1 Monat');
    btn_to_minus_month.Layout.Row = 2;
    btn_to_minus_month.Layout.Column = 3;

    btn_to_minus_year = uibutton(to_buttons, 'Text', '-J', ...
        'ButtonPushedFcn', @(btn,event) adjustDate(to_date_picker, -1, 'year'), ...
        'FontSize', 9, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.45, 0.2, 0.2], 'FontColor', 'white', ...
        'Tooltip', '-1 Jahr');
    btn_to_minus_year.Layout.Row = 2;
    btn_to_minus_year.Layout.Column = 4;

    % Intervall Auswahl
    interval_grid = uigridlayout(binance_grid, [1, 2]);
    interval_grid.Layout.Row = 3;
    interval_grid.Layout.Column = 1;
    interval_grid.ColumnWidth = {60, '1x'};
    interval_grid.RowHeight = {'1x'};
    interval_grid.Padding = [0 0 0 0];
    interval_grid.ColumnSpacing = 5;

    uilabel(interval_grid, 'Text', 'Intervall:', 'FontSize', 10, 'FontWeight', 'bold');

    interval_dropdown = uidropdown(interval_grid, ...
                                   'Items', {'1h', '4h', '1d', '1w'}, ...
                                   'ItemsData', {'1h', '4h', '1d', '1w'}, ...
                                   'Value', '1h', ...
                                   'FontSize', 10);
    interval_dropdown.Layout.Column = 2;

    % Download Button
    download_btn = uibutton(binance_grid, 'Text', 'Von Binance herunterladen', ...
                            'ButtonPushedFcn', @(btn,event) downloadFromBinance(), ...
                            'BackgroundColor', [0.2, 0.55, 0.9], ...
                            'FontColor', 'white', ...
                            'FontSize', 11, 'FontWeight', 'bold');
    download_btn.Layout.Row = 4;
    download_btn.Layout.Column = 1;

    % ============================================================
    % GRUPPE 2: Datenanalyse
    % ============================================================
    analyze_group = uipanel(leftPanel, 'Title', '');
    analyze_group.Layout.Row = 3;
    analyze_group.Layout.Column = 1;

    analyze_grid = uigridlayout(analyze_group, [4, 1]);
    analyze_grid.RowHeight = {25, 35, 35, 30};
    analyze_grid.ColumnWidth = {'1x'};
    analyze_grid.RowSpacing = 5;
    analyze_grid.Padding = [10 10 10 10];

    analyze_title = uilabel(analyze_grid, 'Text', 'Datenanalyse', ...
                            'FontSize', 11, 'FontWeight', 'bold', ...
                            'HorizontalAlignment', 'center', ...
                            'BackgroundColor', [0.3, 0.5, 0.3], ...
                            'FontColor', 'white');
    analyze_title.Layout.Row = 1;
    analyze_title.Layout.Column = 1;

    % Analyze und Prepare nebeneinander
    analyze_btn_grid = uigridlayout(analyze_grid, [1, 2]);
    analyze_btn_grid.Layout.Row = 2;
    analyze_btn_grid.Layout.Column = 1;
    analyze_btn_grid.ColumnWidth = {'1x', '1x'};
    analyze_btn_grid.Padding = [0 0 0 0];
    analyze_btn_grid.ColumnSpacing = 5;

    analyze_btn = uibutton(analyze_btn_grid, 'Text', 'Analysieren', ...
                           'ButtonPushedFcn', @(btn,event) analyzeData(), ...
                           'BackgroundColor', [0.2, 0.8, 0.4], ...
                           'FontColor', 'white', ...
                           'FontSize', 11, 'FontWeight', 'bold', ...
                           'Enable', 'off');
    analyze_btn.Layout.Column = 1;

    prepare_data_btn = uibutton(analyze_btn_grid, 'Text', 'Training vorbereiten', ...
                                'ButtonPushedFcn', @(btn,event) prepareTrainingData(), ...
                                'BackgroundColor', [0.8, 0.4, 0.2], ...
                                'FontColor', 'white', ...
                                'FontSize', 11, 'FontWeight', 'bold', ...
                                'Enable', 'off');
    prepare_data_btn.Layout.Column = 2;

    visualize_signals_btn = uibutton(analyze_grid, 'Text', 'Signale visualisieren', ...
                                     'ButtonPushedFcn', @(btn,event) visualizeSignals(), ...
                                     'BackgroundColor', [0.2, 0.8, 0.8], ...
                                     'FontColor', 'white', ...
                                     'FontSize', 11, 'FontWeight', 'bold', ...
                                     'Enable', 'off');
    visualize_signals_btn.Layout.Row = 3;
    visualize_signals_btn.Layout.Column = 1;

    % Button zum Laden von Trainingsdaten aus Workspace
    load_training_btn = uibutton(analyze_grid, 'Text', 'Trainingsdaten aus Workspace laden', ...
                                  'ButtonPushedFcn', @(btn,event) loadTrainingDataFromWorkspace(), ...
                                  'BackgroundColor', [0.5, 0.3, 0.6], ...
                                  'FontColor', 'white', ...
                                  'FontSize', 10, 'FontWeight', 'bold');
    load_training_btn.Layout.Row = 4;
    load_training_btn.Layout.Column = 1;

    % ============================================================
    % GRUPPE 3: BILSTM Training
    % ============================================================
    train_group = uipanel(leftPanel, 'Title', '');
    train_group.Layout.Row = 4;
    train_group.Layout.Column = 1;

    train_grid = uigridlayout(train_group, [5, 1]);
    train_grid.RowHeight = {25, 30, 30, 30, 35};
    train_grid.ColumnWidth = {'1x'};
    train_grid.RowSpacing = 5;
    train_grid.Padding = [10 10 10 10];

    train_title = uilabel(train_grid, 'Text', 'BILSTM Training', ...
                          'FontSize', 11, 'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'center', ...
                          'BackgroundColor', [0.6, 0.2, 0.8], ...
                          'FontColor', 'white');
    train_title.Layout.Row = 1;
    train_title.Layout.Column = 1;

    % Parameter Grid 1: Epochen & Batch
    param_grid1 = uigridlayout(train_grid, [1, 4]);
    param_grid1.Layout.Row = 2;
    param_grid1.Layout.Column = 1;
    param_grid1.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    param_grid1.Padding = [0 0 0 0];
    param_grid1.ColumnSpacing = 5;

    uilabel(param_grid1, 'Text', 'Epochen:', 'FontSize', 10);
    epochs_field = uieditfield(param_grid1, 'numeric', 'Value', 50, ...
                               'Limits', [1, 1000], 'RoundFractionalValues', 'on');

    uilabel(param_grid1, 'Text', 'Batch:', 'FontSize', 10);
    batch_field = uieditfield(param_grid1, 'numeric', 'Value', 32, ...
                              'Limits', [1, 1024], 'RoundFractionalValues', 'on');

    % Parameter Grid 2: Hidden & LR
    param_grid2 = uigridlayout(train_grid, [1, 4]);
    param_grid2.Layout.Row = 3;
    param_grid2.Layout.Column = 1;
    param_grid2.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    param_grid2.Padding = [0 0 0 0];
    param_grid2.ColumnSpacing = 5;

    uilabel(param_grid2, 'Text', 'Hidden:', 'FontSize', 10);
    hidden_field = uieditfield(param_grid2, 'numeric', 'Value', 100, ...
                               'Limits', [10, 1000], 'RoundFractionalValues', 'on');

    uilabel(param_grid2, 'Text', 'L.Rate:', 'FontSize', 10);
    lr_field = uieditfield(param_grid2, 'numeric', 'Value', 0.001, ...
                           'Limits', [0.00001, 0.1], 'ValueDisplayFormat', '%.5f');

    % GPU Switch
    gpu_grid = uigridlayout(train_grid, [1, 3]);
    gpu_grid.Layout.Row = 4;
    gpu_grid.Layout.Column = 1;
    gpu_grid.ColumnWidth = {'1x', 'fit', '1x'};
    gpu_grid.Padding = [0 0 0 0];

    % Spacer links
    uilabel(gpu_grid, 'Text', '');

    gpu_switch = uiswitch(gpu_grid, 'slider', ...
                          'Items', {'CPU', 'GPU'}, ...
                          'Value', 'CPU', ...
                          'ValueChangedFcn', @(sw,event) updateGPUStatus(sw));
    gpu_switch.Layout.Column = 2;

    % Status-Anzeige rechts
    gpu_status_label = uilabel(gpu_grid, 'Text', '', ...
                               'FontSize', 10, 'HorizontalAlignment', 'left');
    gpu_status_label.Layout.Column = 3;

    train_bilstm_btn = uibutton(train_grid, 'Text', 'Training starten', ...
                                'ButtonPushedFcn', @(btn,event) trainBILSTM(), ...
                                'BackgroundColor', [0.6, 0.2, 0.8], ...
                                'FontColor', 'white', ...
                                'FontSize', 11, 'FontWeight', 'bold', ...
                                'Enable', 'off');
    train_bilstm_btn.Layout.Row = 5;
    train_bilstm_btn.Layout.Column = 1;

    % ============================================================
    % GRUPPE 4: Modell & Vorhersage
    % ============================================================
    model_group = uipanel(leftPanel, 'Title', '');
    model_group.Layout.Row = 5;
    model_group.Layout.Column = 1;

    model_grid = uigridlayout(model_group, [2, 1]);
    model_grid.RowHeight = {25, 35};
    model_grid.ColumnWidth = {'1x'};
    model_grid.RowSpacing = 5;
    model_grid.Padding = [10 10 10 10];

    model_title = uilabel(model_grid, 'Text', 'Modell & Vorhersage', ...
                          'FontSize', 11, 'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'center', ...
                          'BackgroundColor', [1.0, 0.6, 0.2], ...
                          'FontColor', 'white');
    model_title.Layout.Row = 1;
    model_title.Layout.Column = 1;

    model_btn_grid = uigridlayout(model_grid, [1, 2]);
    model_btn_grid.Layout.Row = 2;
    model_btn_grid.Layout.Column = 1;
    model_btn_grid.ColumnWidth = {'1x', '1x'};
    model_btn_grid.Padding = [0 0 0 0];
    model_btn_grid.ColumnSpacing = 5;

    load_model_btn = uibutton(model_btn_grid, 'Text', 'Modell laden', ...
                              'ButtonPushedFcn', @(btn,event) loadModel(), ...
                              'BackgroundColor', [0.5, 0.5, 0.5], ...
                              'FontColor', 'white', ...
                              'FontSize', 11, 'FontWeight', 'bold');
    load_model_btn.Layout.Column = 1;

    predict_btn = uibutton(model_btn_grid, 'Text', 'Vorhersage', ...
                           'ButtonPushedFcn', @(btn,event) makePrediction(), ...
                           'BackgroundColor', [1.0, 0.6, 0.2], ...
                           'FontColor', 'white', ...
                           'FontSize', 11, 'FontWeight', 'bold', ...
                           'Enable', 'off');
    predict_btn.Layout.Column = 2;

    % ============================================================
    % GRUPPE 5: Parameter Management
    % ============================================================
    param_mgmt_group = uipanel(leftPanel, 'Title', '');
    param_mgmt_group.Layout.Row = 6;
    param_mgmt_group.Layout.Column = 1;

    param_mgmt_grid = uigridlayout(param_mgmt_group, [2, 1]);
    param_mgmt_grid.RowHeight = {25, 35};
    param_mgmt_grid.ColumnWidth = {'1x'};
    param_mgmt_grid.RowSpacing = 5;
    param_mgmt_grid.Padding = [10 10 10 10];

    param_mgmt_title = uilabel(param_mgmt_grid, 'Text', 'Parameter Management', ...
                          'FontSize', 11, 'FontWeight', 'bold', ...
                          'HorizontalAlignment', 'center', ...
                          'BackgroundColor', [0.4, 0.7, 0.5], ...
                          'FontColor', 'white');
    param_mgmt_title.Layout.Row = 1;
    param_mgmt_title.Layout.Column = 1;

    param_mgmt_btn_grid = uigridlayout(param_mgmt_grid, [1, 2]);
    param_mgmt_btn_grid.Layout.Row = 2;
    param_mgmt_btn_grid.Layout.Column = 1;
    param_mgmt_btn_grid.ColumnWidth = {'1x', '1x'};
    param_mgmt_btn_grid.Padding = [0 0 0 0];
    param_mgmt_btn_grid.ColumnSpacing = 5;

    save_params_btn = uibutton(param_mgmt_btn_grid, 'Text', 'Parameter speichern', ...
                              'ButtonPushedFcn', @(btn,event) saveParameters(), ...
                              'BackgroundColor', [0.3, 0.6, 0.4], ...
                              'FontColor', 'white', ...
                              'FontSize', 11, 'FontWeight', 'bold');
    save_params_btn.Layout.Column = 1;

    load_params_btn = uibutton(param_mgmt_btn_grid, 'Text', 'Parameter laden', ...
                              'ButtonPushedFcn', @(btn,event) loadParameters(), ...
                              'BackgroundColor', [0.5, 0.8, 0.6], ...
                              'FontColor', 'white', ...
                              'FontSize', 11, 'FontWeight', 'bold');
    load_params_btn.Layout.Column = 2;

    % === RECHTES PANEL: Logger ===

    % Logger Header mit Schriftgrößen-Slider und Modus-Auswahl
    logger_header_grid = uigridlayout(rightPanel, [1, 6]);
    logger_header_grid.Layout.Row = 1;
    logger_header_grid.Layout.Column = 1;
    logger_header_grid.ColumnWidth = {80, 150, 60, '1x', 60, 120};
    logger_header_grid.RowHeight = {30};
    logger_header_grid.Padding = [0 0 0 0];
    logger_header_grid.ColumnSpacing = 5;

    logger_title = uilabel(logger_header_grid, 'Text', 'Logger', ...
                           'FontSize', 14, 'FontWeight', 'bold');
    logger_title.Layout.Row = 1;
    logger_title.Layout.Column = 1;

    % Logger-Modus Dropdown (Default: Fenster+Datei)
    logger_mode_dropdown = uidropdown(logger_header_grid, ...
                                      'Items', {'Fenster', 'Fenster+Datei', 'Nur Datei'}, ...
                                      'ItemsData', {'window', 'both', 'file'}, ...
                                      'Value', 'both', ...
                                      'FontSize', 12, ...
                                      'ValueChangedFcn', @(dd,event) updateLoggerMode(dd));
    logger_mode_dropdown.Layout.Row = 1;
    logger_mode_dropdown.Layout.Column = 2;

    % Clear Log Button
    clear_log_btn = uibutton(logger_header_grid, 'Text', 'Clear', ...
                             'ButtonPushedFcn', @(btn,event) clearLog(), ...
                             'FontSize', 10);
    clear_log_btn.Layout.Row = 1;
    clear_log_btn.Layout.Column = 3;

    % Spacer
    uilabel(logger_header_grid, 'Text', '');

    % Schriftgrößen-Label
    fontsize_label = uilabel(logger_header_grid, 'Text', 'Schrift:', ...
                             'FontSize', 10, ...
                             'HorizontalAlignment', 'right');
    fontsize_label.Layout.Row = 1;
    fontsize_label.Layout.Column = 5;

    % Schriftgrößen-Slider
    fontsize_slider = uislider(logger_header_grid, ...
                               'Limits', [8, 14], ...
                               'Value', 12, ...
                               'MajorTicks', [8, 10, 12, 14], ...
                               'ValueChangedFcn', @(sld,event) updateLoggerFontSize(sld));
    fontsize_slider.Layout.Row = 1;
    fontsize_slider.Layout.Column = 6;

    % Logger HTML-Area für farbige Ausgabe
    log_html = uihtml(rightPanel);
    log_html.Layout.Row = 2;
    log_html.Layout.Column = 1;

    % Initialisiere HTML-Logger
    log_entries = {};
    log_font_size = 12;
    updateLoggerHTML();

    % Globale Daten-Variablen
    app_data = [];
    training_data = [];
    trained_model = [];
    model_info = [];
    use_gpu = false;  % GPU/CPU Flag

    % Logger-Variablen (Default: Fenster+Datei)
    logger_mode = 'both';  % 'window', 'both', 'file'

    % Log-Ordner erstellen falls nicht vorhanden
    log_folder = fullfile(fileparts(mfilename('fullpath')), 'log');
    if ~exist(log_folder, 'dir')
        mkdir(log_folder);
    end

    % Daten-Ordner erstellen falls nicht vorhanden
    data_folder = fullfile(fileparts(mfilename('fullpath')), 'Daten_csv');
    if ~exist(data_folder, 'dir')
        mkdir(data_folder);
    end

    % Network-Ordner erstellen falls nicht vorhanden
    network_folder = fullfile(fileparts(mfilename('fullpath')), 'Network');
    if ~exist(network_folder, 'dir')
        mkdir(network_folder);
    end

    % Results-Ordner und Session-Unterordner erstellen
    results_base_folder = fullfile(fileparts(mfilename('fullpath')), 'Results');
    if ~exist(results_base_folder, 'dir')
        mkdir(results_base_folder);
    end

    % Session-Ordner mit Datum und Uhrzeit (sekundengenau)
    session_timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(results_base_folder, session_timestamp);
    mkdir(results_folder);

    % Log-Dateiname mit Datum und Uhrzeit (sekundengenau)
    log_filename = fullfile(log_folder, sprintf('btc_analyzer_%s.txt', session_timestamp));

    % Initiale Log-Nachricht
    logMessage('BTCUSD Analyzer gestartet', 'info');
    logMessage(sprintf('Log-Datei: %s', log_filename), 'info');
    logMessage(sprintf('Results-Ordner: %s', results_folder), 'info');

    % Parameter-Datei erstellen
    saveParametersToFile();

    %% Datum anpassen Funktion
    function adjustDate(date_picker, amount, unit)
        current_date = date_picker.Value;

        switch unit
            case 'day'
                new_date = current_date + days(amount);
            case 'month'
                new_date = current_date + calmonths(amount);
            case 'year'
                new_date = current_date + calyears(amount);
            otherwise
                return;
        end

        date_picker.Value = new_date;
    end

    %% HTML-Logger aktualisieren
    function updateLoggerHTML()
        % Baue HTML-Inhalt
        html_content = sprintf(['<html><head><style>' ...
            'body { font-family: Consolas, monospace; font-size: %dpx; margin: 8px; background: #1e1e1e; color: #d4d4d4; }' ...
            '.log-entry { margin: 2px 0; padding: 3px 6px; border-radius: 3px; }' ...
            '.info { background: #2d3748; color: #90cdf4; }' ...
            '.success { background: #22543d; color: #68d391; }' ...
            '.warning { background: #744210; color: #fbd38d; }' ...
            '.error { background: #742a2a; color: #fc8181; }' ...
            '.timestamp { color: #a0aec0; font-size: %dpx; }' ...
            '.icon { margin-right: 6px; }' ...
            '</style></head><body>'], log_font_size, log_font_size - 1);

        % Header
        html_content = [html_content, '<div style="color: #63b3ed; font-size: 14px; font-weight: bold; margin-bottom: 10px; border-bottom: 1px solid #4a5568; padding-bottom: 5px;">'];
        html_content = [html_content, '=== BTCUSD Analyzer Logger ===</div>'];

        % Log-Einträge
        for i = 1:length(log_entries)
            html_content = [html_content, log_entries{i}];
        end

        html_content = [html_content, '</body></html>'];

        log_html.HTMLSource = html_content;
    end

    %% Logger-Funktion mit Farben
    function logMessage(message, varargin)
        % Optionaler Type-Parameter: 'info', 'success', 'warning', 'error'
        msg_type = 'info';
        if nargin > 1
            msg_type = varargin{1};
        end

        % Icon und CSS-Klasse basierend auf Type
        switch msg_type
            case 'success'
                icon = '&#10003;';  % Checkmark
                css_class = 'success';
            case 'error'
                icon = '&#10007;';  % X
                css_class = 'error';
            case 'warning'
                icon = '&#9888;';   % Warning triangle
                css_class = 'warning';
            otherwise
                icon = '&#8505;';   % Info
                css_class = 'info';
        end

        % Timestamp
        timestamp = datestr(now, 'HH:MM:SS');
        full_timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');

        % HTML-Eintrag erstellen
        html_entry = sprintf('<div class="log-entry %s"><span class="timestamp">[%s]</span> <span class="icon">%s</span> %s</div>', ...
                             css_class, timestamp, icon, message);

        % Formatierte Nachricht für Datei
        log_line_file = sprintf('[%s] [%s] %s', full_timestamp, msg_type, message);

        % Log ins Fenster schreiben (wenn Modus 'window' oder 'both')
        if strcmp(logger_mode, 'window') || strcmp(logger_mode, 'both')
            log_entries{end+1} = html_entry;

            % Auf maximal 100 Einträge begrenzen
            if length(log_entries) > 100
                log_entries = log_entries(end-99:end);
            end

            updateLoggerHTML();
        end

        % Log in Datei schreiben (wenn Modus 'file' oder 'both')
        if strcmp(logger_mode, 'file') || strcmp(logger_mode, 'both')
            try
                % Öffne Datei im Append-Modus
                fid = fopen(log_filename, 'a', 'n', 'UTF-8');
                if fid ~= -1
                    fprintf(fid, '%s\n', log_line_file);
                    fclose(fid);
                end
            catch
                % Fehler beim Schreiben ignorieren
            end
        end
    end

    %% Callback: Logger-Modus ändern
    function updateLoggerMode(dd)
        old_mode = logger_mode;
        logger_mode = dd.Value;

        % Modus-Info
        switch logger_mode
            case 'window'
                mode_text = 'Nur Fenster';
            case 'both'
                mode_text = 'Fenster + Datei';
            case 'file'
                mode_text = 'Nur Datei';
        end

        logMessage(sprintf('Logger-Modus geändert: %s', mode_text), 'info');

        % Info über Log-Datei bei 'both' oder 'file'
        if strcmp(logger_mode, 'both') || strcmp(logger_mode, 'file')
            logMessage(sprintf('Log-Datei: %s', log_filename), 'info');
        end
    end

    %% Callback: Logger Schriftgröße ändern
    function updateLoggerFontSize(sld)
        log_font_size = round(sld.Value);
        updateLoggerHTML();
        logMessage(sprintf('Logger-Schriftgröße: %d', log_font_size), 'info');
    end

    %% Callback: Log löschen
    function clearLog()
        log_entries = {};
        updateLoggerHTML();
        logMessage('Logger bereinigt', 'info');
    end

    %% Callback: GPU/CPU Status Update
    function updateGPUStatus(sw)
        if strcmp(sw.Value, 'GPU')
            use_gpu = true;
            logMessage('GPU-Modus aktiviert, prüfe Verfügbarkeit...', 'info');

            % Prüfe GPU-Verfügbarkeit
            try
                % Versuche Forward Compatibility zu aktivieren (für neuere GPUs)
                try
                    parallel.gpu.enableCUDAForwardCompatibility(true);
                    logMessage('CUDA Forward Compatibility aktiviert', 'info');
                catch
                    % Forward Compatibility nicht verfügbar, fahre trotzdem fort
                end

                gpu_info = gpuDevice;
                gpu_status_label.Text = 'GPU ✓';
                gpu_status_label.FontColor = [0, 0.6, 0];
                logMessage(sprintf('GPU erkannt: %s (%.1f GB, CC %.1f)', ...
                           gpu_info.Name, gpu_info.AvailableMemory/1e9, gpu_info.ComputeCapability), 'success');
            catch ME
                gpu_status_label.Text = 'GPU ✗';
                gpu_status_label.FontColor = [0.8, 0, 0];
                logMessage(sprintf('GPU nicht verfügbar: %s', ME.message), 'warning');
                uialert(fig, sprintf('GPU-Fehler:\n%s\n\nTraining wird auf CPU durchgeführt.', ME.message), ...
                       'GPU Warnung', 'Icon', 'warning');
                sw.Value = 'CPU';
                use_gpu = false;
            end
        else
            use_gpu = false;
            gpu_status_label.FontColor = [0.3, 0.3, 0.3];
            gpu_status_label.Text = '';
            logMessage('CPU-Modus aktiviert', 'info');
        end
    end

    %% Callback: Lokale Datei laden
    function loadLocalFile()
        logMessage('Öffne Dateiauswahl-Dialog...', 'info');
        [file, path] = uigetfile('*.csv', 'CSV-Datei auswählen');
        if file == 0
            logMessage('Dateiauswahl abgebrochen', 'warning');
            return; % User hat abgebrochen
        end

        filepath = fullfile(path, file);
        logMessage(sprintf('Lade Datei: %s', file), 'info');

        try
            % Lade Daten
            app_data = read_btc_data(filepath);

            % Erfolgsmeldung
            msg = sprintf('Erfolgreich geladen!\n\nDatensätze: %d\nZeitraum: %s bis %s', ...
                         height(app_data), ...
                         datestr(app_data.DateTime(1)), ...
                         datestr(app_data.DateTime(end)));
            uialert(fig, msg, 'Erfolgreich', 'Icon', 'success');
            logMessage(sprintf('Daten geladen: %d Datensätze', height(app_data)), 'success');

            % Buttons aktivieren
            analyze_btn.Enable = 'on';
            prepare_data_btn.Enable = 'on';
            visualize_signals_btn.Enable = 'on';
            logMessage('Analyse-Buttons aktiviert', 'info');

        catch ME
            logMessage(sprintf('Fehler beim Laden: %s', ME.message), 'error');
            uialert(fig, sprintf('Fehler beim Laden: %s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Daten von Binance laden
    function downloadFromBinance()
        % Datum und Intervall auslesen
        start_date = from_date_picker.Value;
        end_date = to_date_picker.Value;
        interval = interval_dropdown.Value;

        logMessage(sprintf('Starte Binance Download: %s bis %s (%s)', ...
                   datestr(start_date), datestr(end_date), interval), 'info');

        % Validierung
        if start_date >= end_date
            logMessage('Fehler: Start-Datum nach End-Datum', 'error');
            uialert(fig, 'Start-Datum muss vor End-Datum liegen!', ...
                   'Fehler', 'Icon', 'error');
            return;
        end

        % Fortschritts-Dialog
        progress_dlg = uiprogressdlg(fig, 'Title', 'Download läuft...', ...
                                     'Message', 'Lade Daten von Binance API...', ...
                                     'Indeterminate', 'on');

        try
            % Download starten
            logMessage('Verbinde zu Binance API...', 'info');
            new_data = download_btc_data(start_date, end_date, interval);

            % Wenn bereits Daten vorhanden, zusammenführen
            if ~isempty(app_data)
                logMessage('Bestehende Daten gefunden, frage Benutzer...', 'info');
                % Frage ob ersetzen oder zusammenführen
                choice = uiconfirm(fig, ...
                    'Möchten Sie die neuen Daten mit den bestehenden zusammenführen?', ...
                    'Daten zusammenführen', ...
                    'Options', {'Zusammenführen', 'Ersetzen', 'Abbrechen'}, ...
                    'DefaultOption', 1);

                if strcmp(choice, 'Zusammenführen')
                    % Daten kombinieren
                    logMessage('Führe Daten zusammen...', 'info');
                    app_data = [app_data; new_data];
                    % Duplikate entfernen und sortieren
                    [~, unique_idx] = unique(app_data.DateTime, 'stable');
                    app_data = app_data(unique_idx, :);
                    app_data = sortrows(app_data, 'DateTime');
                    logMessage(sprintf('Daten zusammengeführt: %d Datensätze', height(app_data)), 'success');
                elseif strcmp(choice, 'Ersetzen')
                    app_data = new_data;
                    logMessage(sprintf('Daten ersetzt: %d neue Datensätze', height(app_data)), 'success');
                else
                    logMessage('Download abgebrochen', 'warning');
                    close(progress_dlg);
                    return;
                end
            else
                app_data = new_data;
                logMessage(sprintf('Download erfolgreich: %d Datensätze', height(app_data)), 'success');
            end

            close(progress_dlg);

            % Erfolgsmeldung
            msg = sprintf('Download erfolgreich!\n\nDatensätze: %d\nZeitraum: %s bis %s', ...
                         height(app_data), ...
                         datestr(app_data.DateTime(1)), ...
                         datestr(app_data.DateTime(end)));
            uialert(fig, msg, 'Erfolgreich', 'Icon', 'success');

            % Buttons aktivieren
            analyze_btn.Enable = 'on';
            prepare_data_btn.Enable = 'on';
            visualize_signals_btn.Enable = 'on';

            % Optional: Frage ob speichern
            save_choice = uiconfirm(fig, ...
                'Möchten Sie die Daten als CSV speichern?', ...
                'Daten speichern', ...
                'Options', {'Ja', 'Nein'}, ...
                'DefaultOption', 2);

            if strcmp(save_choice, 'Ja')
                logMessage('Starte CSV-Export...', 'info');
                saveDataAsCSV();
            end

        catch ME
            close(progress_dlg);
            logMessage(sprintf('Download fehlgeschlagen: %s', ME.message), 'error');
            uialert(fig, sprintf('Download fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Daten analysieren
    function analyzeData()
        if isempty(app_data)
            logMessage('Fehler: Keine Daten geladen', 'error');
            uialert(fig, 'Keine Daten geladen!', 'Fehler', 'Icon', 'error');
            return;
        end

        try
            logMessage('Starte Datenanalyse...', 'info');
            % Fortschritts-Dialog
            progress_dlg = uiprogressdlg(fig, 'Title', 'Analyse läuft...', ...
                                         'Message', 'Erstelle Visualisierungen...', ...
                                         'Indeterminate', 'on');

            % Führe Hauptanalyse aus (verwende bestehende main.m Logik)
            runAnalysis(app_data);

            close(progress_dlg);
            logMessage('Analyse abgeschlossen, Diagramme erstellt', 'success');

            uialert(fig, 'Analyse abgeschlossen! Diagramme wurden erstellt.', ...
                   'Erfolgreich', 'Icon', 'success');

        catch ME
            if exist('progress_dlg', 'var')
                close(progress_dlg);
            end
            logMessage(sprintf('Analyse fehlgeschlagen: %s', ME.message), 'error');
            uialert(fig, sprintf('Analyse fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Hilfsfunktion: Daten als CSV speichern
    function saveDataAsCSV()
        % Standard-Dateiname mit Zeitstempel
        default_filename = sprintf('BTCUSD_%s_%s.csv', ...
            datestr(app_data.DateTime(1), 'yyyy-mm-dd'), ...
            datestr(app_data.DateTime(end), 'yyyy-mm-dd'));
        default_path = fullfile(data_folder, default_filename);

        [file, path] = uiputfile('*.csv', 'Speichern als', default_path);
        if file == 0
            logMessage('CSV-Export abgebrochen', 'warning');
            return;
        end

        filepath = fullfile(path, file);
        logMessage(sprintf('Exportiere nach: %s', filepath), 'info');

        try
            % Erstelle Export-Format
            export_data = table();
            export_data.Date = cellstr(datestr(app_data.DateTime, 'yyyy.mm.dd'));
            export_data.Time = cellstr(datestr(app_data.DateTime, 'HH:MM:SS'));
            export_data.Open = app_data.Open;
            export_data.High = app_data.High;
            export_data.Low = app_data.Low;
            export_data.Close = app_data.Close;

            if ismember('TickVol', app_data.Properties.VariableNames)
                export_data.TickVol = app_data.TickVol;
            else
                export_data.TickVol = zeros(height(app_data), 1);
            end

            export_data.Vol = zeros(height(app_data), 1);
            export_data.Spread = zeros(height(app_data), 1);

            % Speichern
            writetable(export_data, filepath, 'Delimiter', '\t');
            logMessage(sprintf('CSV gespeichert: %d Zeilen', height(export_data)), 'success');

            uialert(fig, sprintf('Daten gespeichert:\n%s', filepath), ...
                   'Erfolgreich', 'Icon', 'success');

        catch ME
            logMessage(sprintf('Fehler beim Speichern: %s', ME.message), 'error');
            uialert(fig, sprintf('Speichern fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Hilfsfunktion: Analyse durchführen
    function runAnalysis(data)
        % Preisbewegungen berechnen
        data.PriceChange = [0; diff(data.Close)];
        data.PriceChangePercent = [0; (diff(data.Close) ./ data.Close(1:end-1)) * 100];

        % Visualisierung
        figure('Name', 'BTCUSD Analyse', 'Position', [100, 100, 1200, 600]);

        % Plot 1: Preisverlauf mit Tages-Extrema
        subplot(2, 1, 1);
        plot(data.DateTime, data.Close, 'b-', 'LineWidth', 1.5);
        hold on;
        plot(data.DateTime, data.High, 'g--', 'LineWidth', 0.5);
        plot(data.DateTime, data.Low, 'r--', 'LineWidth', 0.5);

        % Tages-Extrema finden und markieren
        [high_points, low_points] = find_daily_extrema(data);
        high_times = [high_points.DateTime];
        high_prices = [high_points.Price];
        plot(high_times, high_prices, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g');

        low_times = [low_points.DateTime];
        low_prices = [low_points.Price];
        plot(low_times, low_prices, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

        grid on;
        xlabel('Datum');
        ylabel('Preis (USD)');
        title('BTCUSD Preisverlauf mit Tages-Extrema');
        legend('Close', 'High', 'Low', 'Tages-Hoch', 'Tages-Tief', 'Location', 'best');
        hold off;

        % Plot 2: Preisänderung
        subplot(2, 1, 2);
        bar(data.DateTime, data.PriceChangePercent, 'FaceColor', [0.8, 0.4, 0.2]);
        grid on;
        xlabel('Datum');
        ylabel('Änderung (%)');
        title('Preisänderung in %');

        % Moving Averages (falls genug Daten)
        if height(data) >= 168
            data.MA_Short = movmean(data.Close, 24);
            data.MA_Long = movmean(data.Close, 168);

            figure('Name', 'Moving Averages', 'Position', [150, 150, 1000, 500]);
            plot(data.DateTime, data.Close, 'b-', 'LineWidth', 1);
            hold on;
            plot(data.DateTime, data.MA_Short, 'g-', 'LineWidth', 2);
            plot(data.DateTime, data.MA_Long, 'r-', 'LineWidth', 2);
            grid on;
            xlabel('Datum');
            ylabel('Preis (USD)');
            title('BTCUSD mit Moving Averages');
            legend('Close', 'MA 24h', 'MA 168h', 'Location', 'best');
            hold off;
        end
    end

    %% Callback: Signale visualisieren
    function visualizeSignals()
        if isempty(app_data)
            logMessage('Fehler: Keine Daten geladen', 'error');
            uialert(fig, 'Keine Daten geladen!', 'Fehler', 'Icon', 'error');
            return;
        end

        if isempty(training_data)
            logMessage('Fehler: Keine Trainingsdaten verfügbar', 'error');
            uialert(fig, 'Keine Trainingsdaten vorhanden! Bitte zuerst "Training vorbereiten" ausführen.', ...
                   'Fehler', 'Icon', 'error');
            return;
        end

        try
            logMessage('Öffne Trainingsdaten-Visualisierungs-GUI...', 'info');

            % Rufe die GUI zur Visualisierung auf
            visualize_training_data_gui(app_data, training_data.info, training_data.X, training_data.Y);

            % Zähle Signale für Log
            buy_count = sum(cellfun(@(y) double(y) == 1, training_data.Y));
            sell_count = sum(cellfun(@(y) double(y) == 2, training_data.Y));
            hold_count = sum(cellfun(@(y) double(y) == 0, training_data.Y));

            logMessage(sprintf('Visualisierungs-GUI geöffnet: %d BUY, %d SELL, %d HOLD', ...
                      buy_count, sell_count, hold_count), 'success');
        catch ME
            logMessage(sprintf('Fehler bei Visualisierung: %s', ME.message), 'error');
            uialert(fig, sprintf('Visualisierung fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Trainingsdaten vorbereiten
    function prepareTrainingData()
        if isempty(app_data)
            logMessage('Fehler: Keine Daten für Training', 'error');
            uialert(fig, 'Keine Daten geladen!', 'Fehler', 'Icon', 'error');
            return;
        end

        try
            logMessage('Öffne Trainingsdaten-Vorbereitungs-GUI...', 'info');

            % Öffne die neue GUI für Parameter-Einstellung
            prepare_training_data_gui(app_data);

            % Prüfe ob Daten im Base Workspace erstellt wurden
            % (wird von der GUI dort gespeichert wenn "Daten generieren" geklickt)
            pause(0.5);  % Kurze Pause um GUI-Erstellung abzuwarten

            % Listener für Variablen-Änderungen im Workspace
            % Nach Schließen der GUI prüfen wir auf neue Daten
            logMessage('GUI geöffnet. Nach Abschluss werden Daten übernommen.', 'info');

        catch ME
            logMessage(sprintf('Fehler beim Öffnen der Vorbereitungs-GUI: %s', ME.message), 'error');
            uialert(fig, sprintf('Fehler:\n%s', ME.message), 'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Trainingsdaten aus Workspace laden
    function loadTrainingDataFromWorkspace()
        try
            if evalin('base', 'exist(''X_train'', ''var'')') && ...
               evalin('base', 'exist(''Y_train'', ''var'')') && ...
               evalin('base', 'exist(''training_info'', ''var'')')

                X = evalin('base', 'X_train');
                Y = evalin('base', 'Y_train');
                info = evalin('base', 'training_info');

                training_data.X = X;
                training_data.Y = Y;
                training_data.info = info;

                logMessage(sprintf('Trainingsdaten geladen: %d Sequenzen (BUY:%d SELL:%d HOLD:%d)', ...
                           info.total_sequences, info.num_buy, info.num_sell, info.num_hold), 'success');

                % Train Button und Visualisierungs-Button aktivieren
                train_bilstm_btn.Enable = 'on';
                visualize_signals_btn.Enable = 'on';

                uialert(fig, sprintf('Trainingsdaten übernommen!\n\nSequenzen: %d\nBUY: %d | SELL: %d | HOLD: %d', ...
                    info.total_sequences, info.num_buy, info.num_sell, info.num_hold), ...
                    'Erfolgreich', 'Icon', 'success');
            else
                logMessage('Keine Trainingsdaten im Workspace gefunden.', 'warning');
            end
        catch ME
            logMessage(sprintf('Fehler beim Laden aus Workspace: %s', ME.message), 'error');
        end
    end

    %% Callback: BILSTM trainieren
    function trainBILSTM()
        if isempty(training_data)
            logMessage('Fehler: Keine Trainingsdaten vorhanden', 'error');
            uialert(fig, 'Keine Trainingsdaten vorbereitet!', 'Fehler', 'Icon', 'error');
            return;
        end

        % Parameter aus GUI lesen
        epochs_val = epochs_field.Value;
        batch_val = batch_field.Value;
        hidden_val = hidden_field.Value;
        lr_val = lr_field.Value;

        try
            % Training starten mit GPU/CPU Einstellung
            execution_env = 'cpu';
            if use_gpu
                try
                    % Aktiviere Forward Compatibility für neuere GPUs
                    try
                        parallel.gpu.enableCUDAForwardCompatibility(true);
                    catch
                        % Ignoriere falls nicht verfügbar
                    end

                    gpuDevice;
                    execution_env = 'gpu';
                    logMessage(sprintf('Starte BILSTM Training auf GPU (%d Epochen)...', epochs_val), 'info');
                catch ME
                    uialert(fig, sprintf('GPU nicht verfügbar: %s\nVerwende CPU', ME.message), 'Info', 'Icon', 'info');
                    execution_env = 'cpu';
                    logMessage(sprintf('GPU nicht verfügbar (%s), trainiere auf CPU...', ME.message), 'warning');
                end
            else
                logMessage(sprintf('Starte BILSTM Training auf CPU (%d Epochen)...', epochs_val), 'info');
            end

            [net, results] = train_bilstm_model(training_data.X, training_data.Y, ...
                                                training_data.info, ...
                                                'epochs', epochs_val, ...
                                                'batch_size', batch_val, ...
                                                'num_hidden_units', hidden_val, ...
                                                'learning_rate', lr_val, ...
                                                'validation_split', 0.2, ...
                                                'execution_env', execution_env);

            trained_model = net;
            model_info = training_data.info;

            logMessage(sprintf('Training abgeschlossen: Train Acc=%.2f%%, Val Acc=%.2f%%, Zeit=%.1fmin', ...
                       results.train_accuracy, results.val_accuracy, results.training_time/60), 'success');

            % Erfolgsmeldung
            msg = sprintf('Training abgeschlossen!\n\nTraining Acc: %.2f%%\nValidation Acc: %.2f%%\nZeit: %.1f Min', ...
                         results.train_accuracy, results.val_accuracy, results.training_time/60);
            uialert(fig, msg, 'Erfolgreich', 'Icon', 'success');

            % Predict Button aktivieren
            predict_btn.Enable = 'on';

            % Frage ob Modell speichern
            save_choice = uiconfirm(fig, ...
                'Möchten Sie das trainierte Modell speichern?', ...
                'Modell speichern', ...
                'Options', {'Ja', 'Nein'}, ...
                'DefaultOption', 1);

            if strcmp(save_choice, 'Ja')
                saveModel(net, training_data.info, results);
            end

        catch ME
            logMessage(sprintf('Training fehlgeschlagen: %s', ME.message), 'error');
            uialert(fig, sprintf('Training fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Modell laden
    function loadModel()
        logMessage('Öffne Modellauswahl-Dialog...', 'info');
        [file, path] = uigetfile('*.mat', 'Modell auswählen');
        if file == 0
            logMessage('Modellauswahl abgebrochen', 'warning');
            return;
        end

        filepath = fullfile(path, file);
        logMessage(sprintf('Lade Modell: %s', file), 'info');

        try
            loaded = load(filepath);

            if ~isfield(loaded, 'net') || ~isfield(loaded, 'training_info')
                error('Ungültiges Modell-Format!');
            end

            trained_model = loaded.net;
            model_info = loaded.training_info;

            logMessage(sprintf('Modell geladen: Klassen=%s', strjoin(model_info.classes, ',')), 'success');

            uialert(fig, sprintf('Modell geladen!\n\nKlassen: %s', ...
                   strjoin(model_info.classes, ', ')), ...
                   'Erfolgreich', 'Icon', 'success');

            predict_btn.Enable = 'on';

        catch ME
            logMessage(sprintf('Fehler beim Modell-Laden: %s', ME.message), 'error');
            uialert(fig, sprintf('Fehler beim Laden:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Vorhersage machen
    function makePrediction()
        if isempty(trained_model) || isempty(app_data)
            logMessage('Fehler: Modell oder Daten fehlen für Vorhersage', 'error');
            uialert(fig, 'Modell oder Daten fehlen!', 'Fehler', 'Icon', 'error');
            return;
        end

        try
            logMessage('Starte Vorhersage...', 'info');
            % Letzte Sequenz aus Daten extrahieren
            lookback = model_info.lookback_size;
            lookforward = model_info.lookforward_size;
            seq_length = lookback + lookforward;

            if height(app_data) < seq_length
                error('Nicht genug Daten für Vorhersage!');
            end

            % Features extrahieren
            features = [app_data.Close, app_data.High, app_data.Low, app_data.Open];

            % Letzte Sequenz
            last_seq = features(end-seq_length+1:end, :);
            last_seq_norm = normalize(last_seq, 'zscore')';

            % Vorhersage
            prediction = classify(trained_model, last_seq_norm);

            % Ergebnis anzeigen
            pred_class = char(prediction);
            logMessage(sprintf('Vorhersage: %s', pred_class), 'success');
            msg = sprintf('Vorhersage für aktuelle Sequenz:\n\n%s\n\nKlassen:\nHOLD=0, BUY=1, SELL=2', pred_class);
            uialert(fig, msg, 'Vorhersage', 'Icon', 'info');

        catch ME
            logMessage(sprintf('Vorhersage fehlgeschlagen: %s', ME.message), 'error');
            uialert(fig, sprintf('Vorhersage fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Hilfsfunktion: Modell speichern
    function saveModel(net, training_info, training_results)
        % Standard-Dateiname mit Zeitstempel (sekundengenau)
        timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
        default_name = sprintf('BILSTM_%s.mat', timestamp);
        default_path = fullfile(network_folder, default_name);

        logMessage('Öffne Speichern-Dialog für Modell...', 'info');
        [file, path] = uiputfile('*.mat', 'Modell speichern', default_path);
        if file == 0
            logMessage('Modell-Speichern abgebrochen', 'warning');
            return;
        end

        filepath = fullfile(path, file);
        logMessage(sprintf('Speichere Modell: %s', filepath), 'info');
        save(filepath, 'net', 'training_info', 'training_results');
        logMessage('Modell erfolgreich gespeichert', 'success');

        uialert(fig, sprintf('Modell gespeichert:\n%s', filepath), ...
               'Erfolgreich', 'Icon', 'success');
    end

    %% Hilfsfunktion: Parameter in Datei speichern
    function saveParametersToFile()
        % Erstelle strukturierte Parameter-Datei mit allen GUI-Einstellungen
        params_filename = fullfile(results_folder, 'parameters.txt');

        try
            fid = fopen(params_filename, 'w', 'n', 'UTF-8');
            if fid == -1
                logMessage(sprintf('Fehler: Kann Parameter-Datei nicht schreiben: %s', params_filename), 'error');
                return;
            end

            % Header
            fprintf(fid, '=================================================================\n');
            fprintf(fid, 'BTCUSD Analyzer - Session Parameter\n');
            fprintf(fid, '=================================================================\n\n');

            % Session Info
            fprintf(fid, '--- SESSION INFORMATION ---\n');
            fprintf(fid, 'Startzeit: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
            fprintf(fid, 'Session-Ordner: %s\n', results_folder);
            fprintf(fid, '\n');

            % Datenlade-Parameter
            fprintf(fid, '--- DATENLADE-PARAMETER ---\n');
            fprintf(fid, 'Von-Datum: %s\n', datestr(from_date_picker.Value, 'yyyy-mm-dd'));
            fprintf(fid, 'Bis-Datum: %s\n', datestr(to_date_picker.Value, 'yyyy-mm-dd'));
            fprintf(fid, 'Intervall: %s\n', interval_dropdown.Value);
            fprintf(fid, '\n');

            % Training-Parameter
            fprintf(fid, '--- TRAINING-PARAMETER (BILSTM) ---\n');
            fprintf(fid, 'Epochen: %d\n', epochs_field.Value);
            fprintf(fid, 'Batch-Size: %d\n', batch_field.Value);
            fprintf(fid, 'Hidden Units: %d\n', hidden_field.Value);
            fprintf(fid, 'Learning Rate: %.5f\n', lr_field.Value);
            fprintf(fid, 'Execution Environment: %s\n', gpu_switch.Value);
            fprintf(fid, '\n');

            % System-Info
            fprintf(fid, '--- SYSTEM INFORMATION ---\n');
            fprintf(fid, 'MATLAB-Version: %s\n', version);
            fprintf(fid, 'Betriebssystem: %s\n', computer);

            % GPU-Info wenn verfügbar
            try
                gpu_info = gpuDevice;
                fprintf(fid, 'GPU verfügbar: %s\n', gpu_info.Name);
                fprintf(fid, 'GPU Speicher: %.1f GB\n', gpu_info.AvailableMemory/1e9);
            catch
                fprintf(fid, 'GPU verfügbar: Nein\n');
            end

            fprintf(fid, '\n=================================================================\n');
            fprintf(fid, 'Ende Parameter-Datei\n');
            fprintf(fid, '=================================================================\n');

            fclose(fid);
            logMessage(sprintf('Parameter-Datei erstellt: %s', params_filename), 'success');

            % Zusätzlich .mat Datei zum Laden erstellen (strukturiert)
            params_mat_filename = fullfile(results_folder, 'parameters.mat');
            params = struct();

            % Session Information
            params.session.timestamp = session_timestamp;
            params.session.results_folder = results_folder;

            % Datenlade-Parameter
            params.data_loading.from_date = from_date_picker.Value;
            params.data_loading.to_date = to_date_picker.Value;
            params.data_loading.interval = interval_dropdown.Value;

            % Training-Parameter
            params.training.epochs = epochs_field.Value;
            params.training.batch_size = batch_field.Value;
            params.training.hidden_units = hidden_field.Value;
            params.training.learning_rate = lr_field.Value;
            params.training.execution_env = gpu_switch.Value;

            save(params_mat_filename, 'params');

        catch ME
            logMessage(sprintf('Fehler beim Schreiben der Parameter-Datei: %s', ME.message), 'error');
        end
    end

    %% Callback: Parameter manuell speichern
    function saveParameters()
        % Standard-Dateiname mit Zeitstempel
        default_name = sprintf('params_%s.mat', datestr(now, 'yyyy-mm-dd_HH-MM-SS'));
        default_path = fullfile(results_folder, default_name);

        logMessage('Öffne Speichern-Dialog für Parameter...', 'info');
        [file, path] = uiputfile('*.mat', 'Parameter speichern', default_path);
        if file == 0
            logMessage('Parameter-Speichern abgebrochen', 'warning');
            return;
        end

        filepath = fullfile(path, file);
        try
            params = struct();

            % Session Information
            params.session.timestamp = session_timestamp;
            params.session.results_folder = results_folder;

            % Datenlade-Parameter
            params.data_loading.from_date = from_date_picker.Value;
            params.data_loading.to_date = to_date_picker.Value;
            params.data_loading.interval = interval_dropdown.Value;

            % Training-Parameter
            params.training.epochs = epochs_field.Value;
            params.training.batch_size = batch_field.Value;
            params.training.hidden_units = hidden_field.Value;
            params.training.learning_rate = lr_field.Value;
            params.training.execution_env = gpu_switch.Value;

            save(filepath, 'params');
            logMessage(sprintf('Parameter gespeichert: %s', filepath), 'success');
            uialert(fig, sprintf('Parameter gespeichert:\n%s', filepath), ...
                   'Erfolgreich', 'Icon', 'success');
        catch ME
            logMessage(sprintf('Fehler beim Speichern: %s', ME.message), 'error');
            uialert(fig, sprintf('Fehler beim Speichern:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end

    %% Callback: Parameter laden
    function loadParameters()
        logMessage('Öffne Parameter-Lade-Dialog...', 'info');
        [file, path] = uigetfile('*.mat', 'Parameter laden', results_base_folder);
        if file == 0
            logMessage('Parameter-Laden abgebrochen', 'warning');
            return;
        end

        filepath = fullfile(path, file);
        try
            loaded = load(filepath);

            if ~isfield(loaded, 'params')
                error('Ungültige Parameter-Datei!');
            end

            params = loaded.params;

            % Technische Parameter in GUI setzen
            % Datenlade-Parameter
            from_date_picker.Value = params.data_loading.from_date;
            to_date_picker.Value = params.data_loading.to_date;
            interval_dropdown.Value = params.data_loading.interval;

            % Training-Parameter
            epochs_field.Value = params.training.epochs;
            batch_field.Value = params.training.batch_size;
            hidden_field.Value = params.training.hidden_units;
            lr_field.Value = params.training.learning_rate;
            gpu_switch.Value = params.training.execution_env;

            % Update GPU Status
            updateGPUStatus(gpu_switch);

            logMessage(sprintf('Parameter geladen: %s', filepath), 'success');
            uialert(fig, sprintf('Parameter erfolgreich geladen:\n%s\n\nTechnische Parameter wiederhergestellt:\n- Datenlade-Parameter\n- Training-Parameter', filepath), ...
                   'Erfolgreich', 'Icon', 'success');

        catch ME
            logMessage(sprintf('Fehler beim Laden: %s', ME.message), 'error');
            uialert(fig, sprintf('Fehler beim Laden:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end
    end
end
