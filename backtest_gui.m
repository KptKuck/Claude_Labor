function backtest_gui(app_data, trained_model, model_info, results_folder, log_callback)
% BACKTEST_GUI GUI fuer Backtesting eines trainierten BILSTM Modells
%
%   backtest_gui(app_data, trained_model, model_info, results_folder, log_callback)
%   oeffnet ein GUI-Fenster zum Backtesten des Modells mit historischen Daten.
%
%   Input:
%       app_data - Tabelle mit OHLC-Daten (DateTime, Open, High, Low, Close)
%       trained_model - Trainiertes BILSTM Netzwerk
%       model_info - Struct mit Modell-Informationen (lookback_size, lookforward_size, etc.)
%       results_folder - Pfad zum Speichern von Ergebnissen
%       log_callback - Callback-Funktion fuer Logging (optional)
%
%   Funktionen:
%       - Schritt-fuer-Schritt Durchlauf der Daten
%       - Start/Stop Steuerung
%       - Gewinn/Verlust Berechnung ohne Gebuehren
%       - Visualisierung von Trades und Equity-Kurve

    % Log-Callback Fallback
    if nargin < 5 || isempty(log_callback)
        log_callback = @(msg, level) fprintf('[%s] %s\n', upper(level), msg);
    end

    % === VALIDIERUNG: Pruefe Kompatibilitaet von Daten und Modell ===
    [is_valid, validation_msg] = validateDataModelCompatibility(app_data, model_info, log_callback);
    if ~is_valid
        error('Backtester:ValidationFailed', validation_msg);
    end

    % Parameter aus model_info extrahieren
    lookback = model_info.lookback_size;
    lookforward = model_info.lookforward_size;
    sequence_length = lookback + lookforward;

    % Backtester-Status
    is_running = false;
    is_paused = false;
    current_index = sequence_length + 1;  % Start nach erster vollstaendiger Sequenz

    % Trading-Status
    position = 'NONE';  % 'NONE', 'LONG', 'SHORT'
    entry_price = 0;
    entry_index = 0;
    total_pnl = 0;
    trades = struct('entry_index', {}, 'exit_index', {}, 'position', {}, ...
                    'entry_price', {}, 'exit_price', {}, 'pnl', {}, 'reason', {});  % Struct-Array fuer Trade-Historie
    signals = struct('index', {}, 'signal', {}, 'price', {});  % Struct-Array fuer alle Signale

    % Startkapital und Equity
    initial_capital = 10000;  % USD
    current_equity = initial_capital;
    equity_curve = initial_capital;  % Equity-Historie
    equity_indices = current_index;  % Zugehoerige Indizes

    % GUI erstellen
    screen_size = get(0, 'ScreenSize');
    fig_width = min(1200, screen_size(3) - 100);
    fig_height = min(800, screen_size(4) - 100);
    fig_x = max(50, (screen_size(3) - fig_width) / 2);
    fig_y = max(50, (screen_size(4) - fig_height) / 2);

    fig = uifigure('Name', 'Backtester - BILSTM Trading Simulation', ...
                   'Position', [fig_x, fig_y, fig_width, fig_height], ...
                   'Color', [0.15, 0.15, 0.15], ...
                   'CloseRequestFcn', @(src, evt) closeBacktester());

    % Haupt-Grid: [Steuerung | Chart | Statistik]
    mainGrid = uigridlayout(fig, [1, 3]);
    mainGrid.ColumnWidth = {280, '1x', 280};
    mainGrid.Padding = [10 10 10 10];
    mainGrid.ColumnSpacing = 10;

    %% ============================================================
    %% LINKE SPALTE: Steuerung und Status
    %% ============================================================
    leftPanel = uipanel(mainGrid, 'Title', '', ...
                        'BackgroundColor', [0.18, 0.18, 0.18]);
    leftPanel.Layout.Column = 1;

    leftGrid = uigridlayout(leftPanel, [7, 1]);
    leftGrid.RowHeight = {30, 'fit', 'fit', 'fit', 'fit', '1x', 40};
    leftGrid.ColumnWidth = {'1x'};
    leftGrid.RowSpacing = 10;
    leftGrid.Padding = [10 10 10 10];

    % Titel
    uilabel(leftGrid, 'Text', 'Backtester Steuerung', ...
            'FontSize', 16, 'FontWeight', 'bold', ...
            'FontColor', 'white', ...
            'HorizontalAlignment', 'center');

    % --------------------------------------------------------
    % Steuerungs-Buttons
    % --------------------------------------------------------
    control_group = uipanel(leftGrid, 'Title', 'Steuerung', ...
                            'FontSize', 12, 'FontWeight', 'bold', ...
                            'ForegroundColor', [0.3, 0.7, 1], ...
                            'BackgroundColor', [0.2, 0.2, 0.2]);
    control_group.Layout.Row = 2;

    control_grid = uigridlayout(control_group, [2, 2]);
    control_grid.RowHeight = {40, 40};
    control_grid.ColumnWidth = {'1x', '1x'};
    control_grid.RowSpacing = 8;
    control_grid.Padding = [10 10 10 10];

    start_btn = uibutton(control_grid, 'Text', 'Start', ...
                         'ButtonPushedFcn', @(btn,e) startBacktest(), ...
                         'BackgroundColor', [0.2, 0.7, 0.3], ...
                         'FontColor', 'white', ...
                         'FontSize', 14, 'FontWeight', 'bold');
    start_btn.Layout.Row = 1;
    start_btn.Layout.Column = 1;

    stop_btn = uibutton(control_grid, 'Text', 'Stop', ...
                        'ButtonPushedFcn', @(btn,e) stopBacktest(), ...
                        'BackgroundColor', [0.8, 0.3, 0.2], ...
                        'FontColor', 'white', ...
                        'FontSize', 14, 'FontWeight', 'bold', ...
                        'Enable', 'off');
    stop_btn.Layout.Row = 1;
    stop_btn.Layout.Column = 2;

    step_btn = uibutton(control_grid, 'Text', 'Einzelschritt', ...
                        'ButtonPushedFcn', @(btn,e) singleStep(), ...
                        'BackgroundColor', [0.5, 0.5, 0.7], ...
                        'FontColor', 'white', ...
                        'FontSize', 12, 'FontWeight', 'bold');
    step_btn.Layout.Row = 2;
    step_btn.Layout.Column = 1;

    reset_btn = uibutton(control_grid, 'Text', 'Reset', ...
                         'ButtonPushedFcn', @(btn,e) resetBacktest(), ...
                         'BackgroundColor', [0.5, 0.5, 0.5], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');
    reset_btn.Layout.Row = 2;
    reset_btn.Layout.Column = 2;

    % --------------------------------------------------------
    % Geschwindigkeits-Einstellung
    % --------------------------------------------------------
    speed_group = uipanel(leftGrid, 'Title', 'Geschwindigkeit', ...
                          'FontSize', 12, 'FontWeight', 'bold', ...
                          'ForegroundColor', [0.9, 0.7, 0.3], ...
                          'BackgroundColor', [0.2, 0.2, 0.2]);
    speed_group.Layout.Row = 3;

    speed_grid = uigridlayout(speed_group, [1, 3]);
    speed_grid.RowHeight = {35};
    speed_grid.ColumnWidth = {80, '1x', 50};
    speed_grid.Padding = [10 10 10 10];

    uilabel(speed_grid, 'Text', 'Schritte/Sek:', 'FontSize', 11, ...
            'FontColor', 'white');

    speed_slider = uislider(speed_grid, 'Limits', [1, 100], ...
                            'Value', 10, ...
                            'ValueChangedFcn', @(s,e) updateSpeed(s.Value));
    speed_slider.Layout.Column = 2;

    speed_label = uilabel(speed_grid, 'Text', '10', 'FontSize', 11, ...
                          'FontColor', 'white', ...
                          'HorizontalAlignment', 'right');
    speed_label.Layout.Column = 3;

    % --------------------------------------------------------
    % Positions-Info
    % --------------------------------------------------------
    position_group = uipanel(leftGrid, 'Title', 'Aktuelle Position', ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'ForegroundColor', [0.5, 0.9, 0.5], ...
                             'BackgroundColor', [0.2, 0.2, 0.2]);
    position_group.Layout.Row = 4;

    pos_grid = uigridlayout(position_group, [4, 2]);
    pos_grid.RowHeight = {26, 26, 26, 26};
    pos_grid.ColumnWidth = {100, '1x'};
    pos_grid.RowSpacing = 3;
    pos_grid.Padding = [10 10 10 10];

    uilabel(pos_grid, 'Text', 'Position:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    position_label = uilabel(pos_grid, 'Text', 'NONE', 'FontSize', 12, ...
                             'FontWeight', 'bold', 'FontColor', [0.5, 0.5, 0.5]);

    uilabel(pos_grid, 'Text', 'Einstiegspreis:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    entry_price_label = uilabel(pos_grid, 'Text', '-', 'FontSize', 11, 'FontColor', 'white');

    uilabel(pos_grid, 'Text', 'Aktueller Preis:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    current_price_label = uilabel(pos_grid, 'Text', '-', 'FontSize', 11, 'FontColor', 'white');

    uilabel(pos_grid, 'Text', 'Unrealisiert:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    unrealized_pnl_label = uilabel(pos_grid, 'Text', '-', 'FontSize', 11, 'FontColor', 'white');

    % --------------------------------------------------------
    % Fortschritt
    % --------------------------------------------------------
    progress_group = uipanel(leftGrid, 'Title', 'Fortschritt', ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'ForegroundColor', [0.7, 0.7, 0.7], ...
                             'BackgroundColor', [0.2, 0.2, 0.2]);
    progress_group.Layout.Row = 5;

    progress_grid = uigridlayout(progress_group, [3, 2]);
    progress_grid.RowHeight = {26, 26, 26};
    progress_grid.ColumnWidth = {100, '1x'};
    progress_grid.RowSpacing = 3;
    progress_grid.Padding = [10 10 10 10];

    uilabel(progress_grid, 'Text', 'Datenpunkt:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    datapoint_label = uilabel(progress_grid, 'Text', sprintf('%d / %d', current_index, height(app_data)), ...
                              'FontSize', 11, 'FontColor', 'white');

    uilabel(progress_grid, 'Text', 'Datum:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    date_label = uilabel(progress_grid, 'Text', '-', 'FontSize', 11, 'FontColor', 'white');

    uilabel(progress_grid, 'Text', 'Letztes Signal:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    signal_label = uilabel(progress_grid, 'Text', '-', 'FontSize', 12, ...
                           'FontWeight', 'bold', 'FontColor', [0.5, 0.5, 0.5]);

    % --------------------------------------------------------
    % Trade-Log (scrollbare Liste)
    % --------------------------------------------------------
    tradelog_group = uipanel(leftGrid, 'Title', 'Trade-Log', ...
                             'FontSize', 12, 'FontWeight', 'bold', ...
                             'ForegroundColor', [0.9, 0.5, 0.9], ...
                             'BackgroundColor', [0.2, 0.2, 0.2]);
    tradelog_group.Layout.Row = 6;

    tradelog_list = uitextarea(tradelog_group, ...
                               'Value', {'Kein Trade'}, ...
                               'Editable', 'off', ...
                               'FontName', 'Consolas', ...
                               'FontSize', 10, ...
                               'BackgroundColor', [0.15, 0.15, 0.15], ...
                               'FontColor', [0.8, 0.8, 0.8]);
    tradelog_list.Position = [5, 5, 250, 120];

    % Schliessen-Button
    close_btn = uibutton(leftGrid, 'Text', 'Schliessen', ...
                         'ButtonPushedFcn', @(btn,e) closeBacktester(), ...
                         'BackgroundColor', [0.4, 0.4, 0.4], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');
    close_btn.Layout.Row = 7;

    %% ============================================================
    %% MITTE: Chart Panel
    %% ============================================================
    chartPanel = uipanel(mainGrid, 'Title', '', ...
                         'BackgroundColor', [0.18, 0.18, 0.18]);
    chartPanel.Layout.Column = 2;

    chartGrid = uigridlayout(chartPanel, [2, 1]);
    chartGrid.RowHeight = {'2x', '1x'};
    chartGrid.ColumnWidth = {'1x'};
    chartGrid.RowSpacing = 10;
    chartGrid.Padding = [5 5 5 5];

    % Preis-Chart
    ax_price = uiaxes(chartGrid);
    ax_price.Layout.Row = 1;
    ax_price.Color = [0.1, 0.1, 0.1];
    ax_price.XColor = 'white';
    ax_price.YColor = 'white';
    ax_price.FontSize = 9;
    grid(ax_price, 'on');
    ax_price.GridColor = [0.3, 0.3, 0.3];
    title(ax_price, 'Preis und Signale', 'Color', 'white', 'FontSize', 12);
    ylabel(ax_price, 'Preis (USD)', 'Color', 'white');
    hold(ax_price, 'on');

    % Equity-Chart
    ax_equity = uiaxes(chartGrid);
    ax_equity.Layout.Row = 2;
    ax_equity.Color = [0.1, 0.1, 0.1];
    ax_equity.XColor = 'white';
    ax_equity.YColor = 'white';
    ax_equity.FontSize = 9;
    grid(ax_equity, 'on');
    ax_equity.GridColor = [0.3, 0.3, 0.3];
    title(ax_equity, 'Equity-Kurve', 'Color', 'white', 'FontSize', 12);
    ylabel(ax_equity, 'Equity (USD)', 'Color', 'white');
    hold(ax_equity, 'on');

    %% ============================================================
    %% RECHTE SPALTE: Statistiken
    %% ============================================================
    rightPanel = uipanel(mainGrid, 'Title', '', ...
                         'BackgroundColor', [0.18, 0.18, 0.18]);
    rightPanel.Layout.Column = 3;

    rightGrid = uigridlayout(rightPanel, [4, 1]);
    rightGrid.RowHeight = {30, 'fit', 'fit', '1x'};
    rightGrid.ColumnWidth = {'1x'};
    rightGrid.RowSpacing = 10;
    rightGrid.Padding = [10 10 10 10];

    % Titel
    uilabel(rightGrid, 'Text', 'Performance', ...
            'FontSize', 16, 'FontWeight', 'bold', ...
            'FontColor', 'white', ...
            'HorizontalAlignment', 'center');

    % --------------------------------------------------------
    % Gewinn/Verlust Statistik
    % --------------------------------------------------------
    pnl_group = uipanel(rightGrid, 'Title', 'Gewinn / Verlust', ...
                        'FontSize', 12, 'FontWeight', 'bold', ...
                        'ForegroundColor', [0.3, 0.9, 0.3], ...
                        'BackgroundColor', [0.2, 0.2, 0.2]);
    pnl_group.Layout.Row = 2;

    pnl_grid = uigridlayout(pnl_group, [5, 2]);
    pnl_grid.RowHeight = {30, 30, 30, 30, 30};
    pnl_grid.ColumnWidth = {110, '1x'};
    pnl_grid.RowSpacing = 5;
    pnl_grid.Padding = [10 10 10 10];

    uilabel(pnl_grid, 'Text', 'Startkapital:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    uilabel(pnl_grid, 'Text', sprintf('$%.2f', initial_capital), ...
            'FontSize', 11, 'FontColor', 'white');

    uilabel(pnl_grid, 'Text', 'Aktuell:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    equity_label = uilabel(pnl_grid, 'Text', sprintf('$%.2f', current_equity), ...
                           'FontSize', 14, 'FontWeight', 'bold', 'FontColor', 'white');

    uilabel(pnl_grid, 'Text', 'Gesamt P/L:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    total_pnl_label = uilabel(pnl_grid, 'Text', '$0.00', ...
                              'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.5, 0.5, 0.5]);

    uilabel(pnl_grid, 'Text', 'P/L %:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    pnl_percent_label = uilabel(pnl_grid, 'Text', '0.00%', ...
                                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', [0.5, 0.5, 0.5]);

    uilabel(pnl_grid, 'Text', 'Max Drawdown:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    drawdown_label = uilabel(pnl_grid, 'Text', '0.00%', ...
                             'FontSize', 11, 'FontColor', 'white');

    % --------------------------------------------------------
    % Trade-Statistik
    % --------------------------------------------------------
    stats_group = uipanel(rightGrid, 'Title', 'Trade-Statistik', ...
                          'FontSize', 12, 'FontWeight', 'bold', ...
                          'ForegroundColor', [0.9, 0.7, 0.3], ...
                          'BackgroundColor', [0.2, 0.2, 0.2]);
    stats_group.Layout.Row = 3;

    stats_grid = uigridlayout(stats_group, [6, 2]);
    stats_grid.RowHeight = {26, 26, 26, 26, 26, 26};
    stats_grid.ColumnWidth = {110, '1x'};
    stats_grid.RowSpacing = 3;
    stats_grid.Padding = [10 10 10 10];

    uilabel(stats_grid, 'Text', 'Anzahl Trades:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    num_trades_label = uilabel(stats_grid, 'Text', '0', 'FontSize', 11, 'FontColor', 'white');

    uilabel(stats_grid, 'Text', 'Gewinner:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    winners_label = uilabel(stats_grid, 'Text', '0', 'FontSize', 11, 'FontColor', [0.3, 0.9, 0.3]);

    uilabel(stats_grid, 'Text', 'Verlierer:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    losers_label = uilabel(stats_grid, 'Text', '0', 'FontSize', 11, 'FontColor', [0.9, 0.3, 0.3]);

    uilabel(stats_grid, 'Text', 'Win-Rate:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    winrate_label = uilabel(stats_grid, 'Text', '0.00%', 'FontSize', 11, 'FontColor', 'white');

    uilabel(stats_grid, 'Text', 'Avg. Gewinn:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    avg_win_label = uilabel(stats_grid, 'Text', '$0.00', 'FontSize', 11, 'FontColor', [0.3, 0.9, 0.3]);

    uilabel(stats_grid, 'Text', 'Avg. Verlust:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    avg_loss_label = uilabel(stats_grid, 'Text', '$0.00', 'FontSize', 11, 'FontColor', [0.9, 0.3, 0.3]);

    % --------------------------------------------------------
    % Signal-Statistik
    % --------------------------------------------------------
    signal_group = uipanel(rightGrid, 'Title', 'Signal-Verteilung', ...
                           'FontSize', 12, 'FontWeight', 'bold', ...
                           'ForegroundColor', [0.7, 0.7, 0.9], ...
                           'BackgroundColor', [0.2, 0.2, 0.2]);
    signal_group.Layout.Row = 4;

    signal_grid = uigridlayout(signal_group, [3, 2]);
    signal_grid.RowHeight = {26, 26, 26};
    signal_grid.ColumnWidth = {80, '1x'};
    signal_grid.RowSpacing = 3;
    signal_grid.Padding = [10 10 10 10];

    uilabel(signal_grid, 'Text', 'BUY:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    buy_count_label = uilabel(signal_grid, 'Text', '0', 'FontSize', 11, 'FontColor', [0.3, 0.9, 0.3]);

    uilabel(signal_grid, 'Text', 'SELL:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    sell_count_label = uilabel(signal_grid, 'Text', '0', 'FontSize', 11, 'FontColor', [0.9, 0.3, 0.3]);

    uilabel(signal_grid, 'Text', 'HOLD:', 'FontSize', 11, 'FontColor', [0.7, 0.7, 0.7]);
    hold_count_label = uilabel(signal_grid, 'Text', '0', 'FontSize', 11, 'FontColor', [0.5, 0.5, 0.5]);

    %% ============================================================
    %% Variablen fuer Timer und Geschwindigkeit
    %% ============================================================
    steps_per_second = 10;
    backtest_timer = [];

    % Signal-Zaehler
    buy_count = 0;
    sell_count = 0;
    hold_count = 0;

    %% Initialisierung
    initializeChart();
    log_callback('Backtester GUI geoeffnet', 'info');
    log_callback(sprintf('Datenpunkte: %d, Sequenzlaenge: %d', height(app_data), sequence_length), 'debug');

    %% ============================================================
    %% CALLBACK-FUNKTIONEN
    %% ============================================================

    function startBacktest()
        if is_running
            return;
        end

        is_running = true;
        is_paused = false;

        start_btn.Enable = 'off';
        stop_btn.Enable = 'on';
        step_btn.Enable = 'off';
        reset_btn.Enable = 'off';

        log_callback('Backtest gestartet', 'info');

        % Timer fuer automatischen Durchlauf
        backtest_timer = timer('ExecutionMode', 'fixedRate', ...
                               'Period', 1/steps_per_second, ...
                               'TimerFcn', @(~,~) timerCallback(), ...
                               'ErrorFcn', @(~,evt) timerErrorHandler(evt));
        start(backtest_timer);
    end

    function stopBacktest()
        is_running = false;
        is_paused = true;

        if ~isempty(backtest_timer) && isvalid(backtest_timer)
            stop(backtest_timer);
            delete(backtest_timer);
            backtest_timer = [];
        end

        start_btn.Enable = 'on';
        stop_btn.Enable = 'off';
        step_btn.Enable = 'on';
        reset_btn.Enable = 'on';

        log_callback('Backtest gestoppt', 'warning');
    end

    function resetBacktest()
        % Timer stoppen falls aktiv
        if ~isempty(backtest_timer) && isvalid(backtest_timer)
            stop(backtest_timer);
            delete(backtest_timer);
            backtest_timer = [];
        end

        % Status zuruecksetzen
        is_running = false;
        is_paused = false;
        current_index = sequence_length + 1;

        position = 'NONE';
        entry_price = 0;
        entry_index = 0;
        total_pnl = 0;
        trades = struct('entry_index', {}, 'exit_index', {}, 'position', {}, ...
                        'entry_price', {}, 'exit_price', {}, 'pnl', {}, 'reason', {});
        signals = struct('index', {}, 'signal', {}, 'price', {});

        current_equity = initial_capital;
        equity_curve = initial_capital;
        equity_indices = current_index;

        buy_count = 0;
        sell_count = 0;
        hold_count = 0;

        % UI zuruecksetzen
        start_btn.Enable = 'on';
        stop_btn.Enable = 'off';
        step_btn.Enable = 'on';
        reset_btn.Enable = 'on';

        % Labels zuruecksetzen
        position_label.Text = 'NONE';
        position_label.FontColor = [0.5, 0.5, 0.5];
        entry_price_label.Text = '-';
        current_price_label.Text = '-';
        unrealized_pnl_label.Text = '-';
        signal_label.Text = '-';
        signal_label.FontColor = [0.5, 0.5, 0.5];

        datapoint_label.Text = sprintf('%d / %d', current_index, height(app_data));
        date_label.Text = '-';

        equity_label.Text = sprintf('$%.2f', initial_capital);
        total_pnl_label.Text = '$0.00';
        total_pnl_label.FontColor = [0.5, 0.5, 0.5];
        pnl_percent_label.Text = '0.00%';
        pnl_percent_label.FontColor = [0.5, 0.5, 0.5];
        drawdown_label.Text = '0.00%';

        num_trades_label.Text = '0';
        winners_label.Text = '0';
        losers_label.Text = '0';
        winrate_label.Text = '0.00%';
        avg_win_label.Text = '$0.00';
        avg_loss_label.Text = '$0.00';

        buy_count_label.Text = '0';
        sell_count_label.Text = '0';
        hold_count_label.Text = '0';

        tradelog_list.Value = {'Kein Trade'};

        % Chart neu initialisieren
        initializeChart();

        log_callback('Backtest zurueckgesetzt', 'info');
    end

    function singleStep()
        if current_index <= height(app_data)
            processStep();
            updateUI();
        else
            log_callback('Ende der Daten erreicht', 'warning');
        end
    end

    function timerCallback()
        try
            if ~is_running || current_index > height(app_data)
                stopBacktest();
                if current_index > height(app_data)
                    log_callback('Backtest abgeschlossen - Ende der Daten erreicht', 'success');
                    finalizeBacktest();
                end
                return;
            end

            processStep();
            updateUI();
        catch ME
            log_callback(sprintf('Timer-Fehler: %s', ME.message), 'error');
            stopBacktest();
        end
    end

    function timerErrorHandler(evt)
        log_callback(sprintf('Timer-Error: %s', evt.Data.messageID), 'error');
        stopBacktest();
    end

    function processStep()
        % Sequenz fuer aktuellen Index erstellen
        start_idx = current_index - sequence_length;
        end_idx = current_index - 1;

        if start_idx < 1
            current_index = current_index + 1;
            return;
        end

        % Berechnete Features generieren falls noetig
        app_data = generateComputedFeatures(app_data, model_info.feature_names);

        % Features extrahieren basierend auf model_info.feature_names
        features = [];
        for i = 1:length(model_info.feature_names)
            feature_name = model_info.feature_names{i};
            if ismember(feature_name, app_data.Properties.VariableNames)
                features = [features, app_data.(feature_name)(start_idx:end_idx)];
            else
                error('Feature "%s" nicht in den Daten vorhanden. Unterstuetzte berechnete Features: PriceChange, PriceChangePct', feature_name);
            end
        end

        % Normalisieren (zscore)
        sequence_norm = normalize(features, 'zscore')';

        % Vorhersage
        prediction = classify(trained_model, sequence_norm);

        % Signal interpretieren anhand des String-Wertes der Kategorie
        % WICHTIG: double(categorical) gibt den INDEX zurueck, nicht den Wert!
        % Daher muessen wir den String-Wert auslesen: char(string(prediction))
        pred_str = char(string(prediction));
        switch pred_str
            case '0'
                pred_value = 0;  % HOLD
            case '1'
                pred_value = 1;  % BUY
            case '2'
                pred_value = 2;  % SELL
            otherwise
                % Fallback: Versuche numerische Konvertierung
                pred_value = str2double(pred_str);
                if isnan(pred_value)
                    pred_value = 0;  % Default: HOLD
                    log_callback(sprintf('Unbekannte Vorhersage: %s -> HOLD', pred_str), 'warning');
                end
        end

        % Signal-Wert: 0=HOLD, 1=BUY, 2=SELL
        current_price = app_data.Close(current_index);

        % Signal speichern
        signal_entry.index = current_index;
        signal_entry.signal = pred_value;
        signal_entry.price = current_price;
        signals = [signals; signal_entry];

        % Signal-Zaehler aktualisieren
        switch pred_value
            case 0
                hold_count = hold_count + 1;
            case 1
                buy_count = buy_count + 1;
            case 2
                sell_count = sell_count + 1;
        end

        % Trading-Logik
        processSignal(pred_value, current_price, current_index);

        % Equity aktualisieren
        updateEquity(current_price);

        % Naechster Schritt
        current_index = current_index + 1;
    end

    function processSignal(signal, price, idx)
        % signal: 0=HOLD, 1=BUY, 2=SELL

        switch signal
            case 1  % BUY Signal
                if strcmp(position, 'SHORT')
                    % Short-Position schliessen und Long oeffnen
                    closeTrade(price, idx, 'BUY Signal');
                    openTrade('LONG', price, idx);
                elseif strcmp(position, 'NONE')
                    % Long-Position oeffnen
                    openTrade('LONG', price, idx);
                end
                % Wenn bereits LONG: nichts tun

            case 2  % SELL Signal
                if strcmp(position, 'LONG')
                    % Long-Position schliessen und Short oeffnen
                    closeTrade(price, idx, 'SELL Signal');
                    openTrade('SHORT', price, idx);
                elseif strcmp(position, 'NONE')
                    % Short-Position oeffnen
                    openTrade('SHORT', price, idx);
                end
                % Wenn bereits SHORT: nichts tun

            case 0  % HOLD Signal
                % Keine Aktion (Position halten)
        end
    end

    function openTrade(new_position, price, idx)
        position = new_position;
        entry_price = price;
        entry_index = idx;

        log_callback(sprintf('%s Position geoeffnet @ $%.2f', new_position, price), 'info');
    end

    function closeTrade(price, idx, reason)
        if strcmp(position, 'NONE')
            return;
        end

        % P/L berechnen
        if strcmp(position, 'LONG')
            pnl = price - entry_price;
        else  % SHORT
            pnl = entry_price - price;
        end

        % Trade-Eintrag erstellen
        trade.entry_index = entry_index;
        trade.exit_index = idx;
        trade.position = position;
        trade.entry_price = entry_price;
        trade.exit_price = price;
        trade.pnl = pnl;
        trade.reason = reason;
        trades = [trades; trade];

        % Gesamt-P/L aktualisieren
        total_pnl = total_pnl + pnl;
        current_equity = initial_capital + total_pnl;

        % Trade-Log aktualisieren
        updateTradeLog(trade);

        if pnl >= 0
            log_callback(sprintf('%s Position geschlossen @ $%.2f | P/L: +$%.2f', position, price, pnl), 'success');
        else
            log_callback(sprintf('%s Position geschlossen @ $%.2f | P/L: -$%.2f', position, price, abs(pnl)), 'warning');
        end

        position = 'NONE';
        entry_price = 0;
        entry_index = 0;
    end

    function updateEquity(current_price)
        % Unrealisierte P/L berechnen
        unrealized = 0;
        if strcmp(position, 'LONG')
            unrealized = current_price - entry_price;
        elseif strcmp(position, 'SHORT')
            unrealized = entry_price - current_price;
        end

        % Equity-Kurve aktualisieren
        equity_curve(end+1) = current_equity + unrealized;
        equity_indices(end+1) = current_index;
    end

    function updateUI()
        % Fortschritt
        datapoint_label.Text = sprintf('%d / %d', current_index, height(app_data));
        if current_index <= height(app_data)
            date_label.Text = datestr(app_data.DateTime(current_index), 'dd.mm.yyyy HH:MM');
            current_price_label.Text = sprintf('$%.2f', app_data.Close(current_index));
        end

        % Position
        position_label.Text = position;
        switch position
            case 'LONG'
                position_label.FontColor = [0.3, 0.9, 0.3];
            case 'SHORT'
                position_label.FontColor = [0.9, 0.3, 0.3];
            otherwise
                position_label.FontColor = [0.5, 0.5, 0.5];
        end

        if entry_price > 0
            entry_price_label.Text = sprintf('$%.2f', entry_price);
        else
            entry_price_label.Text = '-';
        end

        % Unrealisierte P/L
        if ~strcmp(position, 'NONE') && current_index <= height(app_data)
            current_price = app_data.Close(current_index);
            if strcmp(position, 'LONG')
                unrealized = current_price - entry_price;
            else
                unrealized = entry_price - current_price;
            end
            unrealized_pnl_label.Text = sprintf('$%.2f', unrealized);
            if unrealized >= 0
                unrealized_pnl_label.FontColor = [0.3, 0.9, 0.3];
            else
                unrealized_pnl_label.FontColor = [0.9, 0.3, 0.3];
            end
        else
            unrealized_pnl_label.Text = '-';
            unrealized_pnl_label.FontColor = 'white';
        end

        % Letztes Signal
        if ~isempty(signals)
            last_signal = signals(end).signal;
            switch last_signal
                case 0
                    signal_label.Text = 'HOLD';
                    signal_label.FontColor = [0.5, 0.5, 0.5];
                case 1
                    signal_label.Text = 'BUY';
                    signal_label.FontColor = [0.3, 0.9, 0.3];
                case 2
                    signal_label.Text = 'SELL';
                    signal_label.FontColor = [0.9, 0.3, 0.3];
            end
        end

        % P/L Statistik
        equity_label.Text = sprintf('$%.2f', current_equity);
        total_pnl_label.Text = sprintf('$%.2f', total_pnl);
        pnl_percent = ((current_equity - initial_capital) / initial_capital) * 100;
        pnl_percent_label.Text = sprintf('%.2f%%', pnl_percent);

        if total_pnl >= 0
            total_pnl_label.FontColor = [0.3, 0.9, 0.3];
            pnl_percent_label.FontColor = [0.3, 0.9, 0.3];
        else
            total_pnl_label.FontColor = [0.9, 0.3, 0.3];
            pnl_percent_label.FontColor = [0.9, 0.3, 0.3];
        end

        % Drawdown
        if ~isempty(equity_curve)
            peak = max(equity_curve);
            drawdown = ((peak - min(equity_curve(find(equity_curve == peak, 1):end))) / peak) * 100;
            drawdown_label.Text = sprintf('%.2f%%', drawdown);
        end

        % Trade-Statistik
        if ~isempty(trades)
            num_trades = length(trades);
            winners = sum([trades.pnl] > 0);
            losers = sum([trades.pnl] <= 0);

            num_trades_label.Text = sprintf('%d', num_trades);
            winners_label.Text = sprintf('%d', winners);
            losers_label.Text = sprintf('%d', losers);

            if num_trades > 0
                winrate_label.Text = sprintf('%.2f%%', (winners/num_trades)*100);
            end

            if winners > 0
                avg_win = mean([trades([trades.pnl] > 0).pnl]);
                avg_win_label.Text = sprintf('$%.2f', avg_win);
            end

            if losers > 0
                avg_loss = mean([trades([trades.pnl] <= 0).pnl]);
                avg_loss_label.Text = sprintf('$%.2f', avg_loss);
            end
        end

        % Signal-Zaehler
        buy_count_label.Text = sprintf('%d', buy_count);
        sell_count_label.Text = sprintf('%d', sell_count);
        hold_count_label.Text = sprintf('%d', hold_count);

        % Charts aktualisieren (alle 10 Schritte fuer Performance)
        if mod(current_index, 10) == 0 || ~is_running
            updateCharts();
        end

        drawnow limitrate;
    end

    function updateTradeLog(trade)
        if trade.pnl >= 0
            pnl_str = sprintf('+$%.2f', trade.pnl);
        else
            pnl_str = sprintf('-$%.2f', abs(trade.pnl));
        end

        log_entry = sprintf('#%d %s: %.2f -> %.2f (%s)', ...
                           length(trades), trade.position, ...
                           trade.entry_price, trade.exit_price, pnl_str);

        current_log = tradelog_list.Value;
        if strcmp(current_log{1}, 'Kein Trade')
            current_log = {log_entry};
        else
            current_log{end+1} = log_entry;
        end

        % Nur letzte 20 Eintraege anzeigen
        if length(current_log) > 20
            current_log = current_log(end-19:end);
        end

        tradelog_list.Value = current_log;
    end

    function initializeChart()
        % Preis-Chart initialisieren
        cla(ax_price);
        hold(ax_price, 'on');

        % Preis-Linie zeichnen
        plot(ax_price, app_data.DateTime, app_data.Close, ...
             'Color', [0.4, 0.6, 0.9], 'LineWidth', 1);

        title(ax_price, 'Preis und Signale', 'Color', 'white', 'FontSize', 12);
        ylabel(ax_price, 'Preis (USD)', 'Color', 'white');

        % Equity-Chart initialisieren
        cla(ax_equity);
        hold(ax_equity, 'on');

        plot(ax_equity, app_data.DateTime(equity_indices), equity_curve, ...
             'Color', [0.3, 0.9, 0.3], 'LineWidth', 1.5);

        % Startkapital-Linie
        yline(ax_equity, initial_capital, '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1);

        title(ax_equity, 'Equity-Kurve', 'Color', 'white', 'FontSize', 12);
        ylabel(ax_equity, 'Equity (USD)', 'Color', 'white');
    end

    function updateCharts()
        % Preis-Chart aktualisieren
        cla(ax_price);
        hold(ax_price, 'on');

        % Preis-Linie
        plot(ax_price, app_data.DateTime, app_data.Close, ...
             'Color', [0.4, 0.6, 0.9], 'LineWidth', 1);

        % BUY Signale
        if ~isempty(signals)
            buy_signals = signals([signals.signal] == 1);
            for i = 1:length(buy_signals)
                idx = buy_signals(i).index;
                if idx <= height(app_data)
                    plot(ax_price, app_data.DateTime(idx), app_data.Close(idx), ...
                         'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
                end
            end

            % SELL Signale
            sell_signals = signals([signals.signal] == 2);
            for i = 1:length(sell_signals)
                idx = sell_signals(i).index;
                if idx <= height(app_data)
                    plot(ax_price, app_data.DateTime(idx), app_data.Close(idx), ...
                         'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
                end
            end
        end

        % Aktuelle Position markieren
        if current_index <= height(app_data)
            xline(ax_price, app_data.DateTime(current_index), '--', ...
                  'Color', [0.9, 0.9, 0.3], 'LineWidth', 1);
        end

        title(ax_price, sprintf('Preis und Signale | BUY: %d, SELL: %d, HOLD: %d', ...
              buy_count, sell_count, hold_count), 'Color', 'white', 'FontSize', 11);

        % Equity-Chart aktualisieren
        cla(ax_equity);
        hold(ax_equity, 'on');

        if length(equity_indices) > 1
            valid_idx = equity_indices <= height(app_data);
            plot(ax_equity, app_data.DateTime(equity_indices(valid_idx)), equity_curve(valid_idx), ...
                 'Color', [0.3, 0.9, 0.3], 'LineWidth', 1.5);
        end

        yline(ax_equity, initial_capital, '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1);

        title(ax_equity, sprintf('Equity-Kurve | P/L: $%.2f (%.2f%%)', ...
              total_pnl, ((current_equity-initial_capital)/initial_capital)*100), ...
              'Color', 'white', 'FontSize', 11);
    end

    function updateSpeed(value)
        steps_per_second = round(value);
        speed_label.Text = sprintf('%d', steps_per_second);

        % Timer neu starten falls aktiv
        if is_running && ~isempty(backtest_timer) && isvalid(backtest_timer)
            stop(backtest_timer);
            backtest_timer.Period = 1/steps_per_second;
            start(backtest_timer);
        end
    end

    function finalizeBacktest()
        % Offene Position schliessen
        if ~strcmp(position, 'NONE') && current_index <= height(app_data)
            closeTrade(app_data.Close(end), height(app_data), 'Backtest Ende');
        end

        % Finale Statistik loggen
        log_callback('=== Backtest Zusammenfassung ===', 'info');
        log_callback(sprintf('Gesamt P/L: $%.2f (%.2f%%)', total_pnl, ...
                    ((current_equity-initial_capital)/initial_capital)*100), 'success');
        log_callback(sprintf('Trades: %d (Gewinner: %d, Verlierer: %d)', ...
                    length(trades), sum([trades.pnl] > 0), sum([trades.pnl] <= 0)), 'info');

        % Ergebnisse speichern
        saveResults();
    end

    function saveResults()
        try
            results = struct();
            results.initial_capital = initial_capital;
            results.final_equity = current_equity;
            results.total_pnl = total_pnl;
            results.pnl_percent = ((current_equity-initial_capital)/initial_capital)*100;
            results.num_trades = length(trades);
            results.trades = trades;
            results.signals = signals;
            results.equity_curve = equity_curve;
            results.equity_indices = equity_indices;

            if ~isempty(trades)
                results.winners = sum([trades.pnl] > 0);
                results.losers = sum([trades.pnl] <= 0);
                results.win_rate = (results.winners / results.num_trades) * 100;
            end

            % Speichern
            filename = fullfile(results_folder, sprintf('backtest_%s.mat', ...
                       datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
            save(filename, 'results');
            log_callback(sprintf('Ergebnisse gespeichert: %s', filename), 'success');
        catch ME
            log_callback(sprintf('Fehler beim Speichern: %s', ME.message), 'error');
        end
    end

    function closeBacktester()
        % Timer stoppen
        if ~isempty(backtest_timer) && isvalid(backtest_timer)
            stop(backtest_timer);
            delete(backtest_timer);
        end

        log_callback('Backtester GUI geschlossen', 'info');
        delete(fig);
    end

    function data = generateComputedFeatures(data, feature_names)
        % GENERATECOMPUTEDFEATURES Generiert berechnete Features aus Rohdaten
        %
        %   Unterstuetzte berechnete Features:
        %       - PriceChange: Differenz zum vorherigen Close-Preis
        %       - PriceChangePct: Prozentuale Aenderung zum vorherigen Close-Preis
        %
        %   Diese Funktion wird nur einmal ausgefuehrt (bei erstem Aufruf)

        % PriceChange generieren falls benoetigt
        if ismember('PriceChange', feature_names) && ~ismember('PriceChange', data.Properties.VariableNames)
            data.PriceChange = [0; diff(data.Close)];
            log_callback('Feature "PriceChange" aus Rohdaten generiert', 'debug');
        end

        % PriceChangePct generieren falls benoetigt
        if ismember('PriceChangePct', feature_names) && ~ismember('PriceChangePct', data.Properties.VariableNames)
            price_diff = [0; diff(data.Close)];
            prev_close = [data.Close(1); data.Close(1:end-1)];
            data.PriceChangePct = (price_diff ./ prev_close) * 100;
            log_callback('Feature "PriceChangePct" aus Rohdaten generiert', 'debug');
        end
    end

    function [is_valid, msg] = validateDataModelCompatibility(data, model_info, log_func)
        % VALIDATEDATAMODELCOMPATIBILITY Prueft ob Daten und Modell kompatibel sind
        %
        %   Prueft:
        %       1. Erforderliche model_info Felder vorhanden
        %       2. Alle benoetigten Features verfuegbar oder generierbar
        %       3. Genuegend Datenpunkte fuer Sequenzlaenge
        %       4. Erforderliche Basisspalten in Daten vorhanden
        %
        %   Output:
        %       is_valid - true wenn kompatibel, false sonst
        %       msg - Fehlermeldung oder Erfolgsmeldung

        is_valid = false;
        msg = '';

        log_func('=== Validierung: Daten-Modell-Kompatibilitaet ===', 'info');

        % --- 1. model_info Felder pruefen ---
        required_fields = {'lookback_size', 'lookforward_size', 'feature_names', 'sequence_length', 'num_features', 'classes'};
        missing_fields = {};

        for i = 1:length(required_fields)
            if ~isfield(model_info, required_fields{i})
                missing_fields{end+1} = required_fields{i};
            end
        end

        if ~isempty(missing_fields)
            msg = sprintf('model_info fehlen Felder: %s', strjoin(missing_fields, ', '));
            log_func(msg, 'error');
            return;
        end
        log_func('model_info Struktur: OK', 'debug');

        % --- 2. Basisspalten in Daten pruefen ---
        required_columns = {'DateTime', 'Open', 'High', 'Low', 'Close'};
        missing_columns = {};

        for i = 1:length(required_columns)
            if ~ismember(required_columns{i}, data.Properties.VariableNames)
                missing_columns{end+1} = required_columns{i};
            end
        end

        if ~isempty(missing_columns)
            msg = sprintf('Daten fehlen Spalten: %s', strjoin(missing_columns, ', '));
            log_func(msg, 'error');
            return;
        end
        log_func('Basis-Datenspalten: OK', 'debug');

        % --- 3. Features pruefen (verfuegbar oder generierbar) ---
        generierbare_features = {'PriceChange', 'PriceChangePct'};
        fehlende_features = {};
        generierbare = {};

        for i = 1:length(model_info.feature_names)
            feature = model_info.feature_names{i};
            if ismember(feature, data.Properties.VariableNames)
                % Feature direkt verfuegbar
                continue;
            elseif ismember(feature, generierbare_features)
                % Feature kann generiert werden
                generierbare{end+1} = feature;
            else
                % Feature weder verfuegbar noch generierbar
                fehlende_features{end+1} = feature;
            end
        end

        if ~isempty(fehlende_features)
            msg = sprintf('Features nicht verfuegbar und nicht generierbar: %s\nUnterstuetzte generierbare Features: %s', ...
                         strjoin(fehlende_features, ', '), strjoin(generierbare_features, ', '));
            log_func(msg, 'error');
            return;
        end

        if ~isempty(generierbare)
            log_func(sprintf('Features werden generiert: %s', strjoin(generierbare, ', ')), 'debug');
        end
        log_func(sprintf('Modell-Features (%d): %s', length(model_info.feature_names), strjoin(model_info.feature_names, ', ')), 'debug');

        % --- 4. Datenmenge pruefen ---
        sequence_length = model_info.lookback_size + model_info.lookforward_size;
        num_datapoints = height(data);
        min_required = sequence_length + 1;

        if num_datapoints < min_required
            msg = sprintf('Zu wenig Datenpunkte: %d vorhanden, mindestens %d benoetigt (Sequenzlaenge: %d)', ...
                         num_datapoints, min_required, sequence_length);
            log_func(msg, 'error');
            return;
        end
        log_func(sprintf('Datenpunkte: %d (min. %d benoetigt)', num_datapoints, min_required), 'debug');

        % --- 5. Feature-Dimension pruefen ---
        if model_info.num_features ~= length(model_info.feature_names)
            msg = sprintf('Inkonsistenz: num_features=%d, aber %d feature_names definiert', ...
                         model_info.num_features, length(model_info.feature_names));
            log_func(msg, 'error');
            return;
        end
        log_func(sprintf('Feature-Dimension: %d', model_info.num_features), 'debug');

        % --- 6. Klassen pruefen ---
        if isempty(model_info.classes)
            msg = 'Keine Klassen in model_info definiert';
            log_func(msg, 'error');
            return;
        end
        log_func(sprintf('Klassen: %s', strjoin(model_info.classes, ', ')), 'debug');

        % --- Alles OK ---
        is_valid = true;
        msg = 'Validierung erfolgreich';
        log_func('=== Validierung erfolgreich ===', 'success');

        % Zusammenfassung
        log_func(sprintf('Sequenzlaenge: %d (Lookback: %d, Lookforward: %d)', ...
                sequence_length, model_info.lookback_size, model_info.lookforward_size), 'info');
        log_func(sprintf('Backtest-Bereich: %d Schritte moeglich', num_datapoints - sequence_length), 'info');
    end

end
