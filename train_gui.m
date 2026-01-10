function train_gui(training_data, results_folder, log_callback)
% TRAIN_GUI GUI für BILSTM Training Parameter und Start
%
%   train_gui(training_data, results_folder, log_callback)
%   Öffnet eine GUI zum Einstellen aller Training-Parameter und
%   zum Starten des BILSTM Trainings.
%
%   Input:
%       training_data - Struct mit X, Y und info
%       results_folder - Pfad zum Speichern der Ergebnisse
%       log_callback - Callback-Funktion für Logging (optional)

    % Validiere Eingaben
    if nargin < 2
        results_folder = pwd;
    end
    if nargin < 3
        log_callback = @(msg, type) fprintf('[%s] %s\n', upper(type), msg);
    end

    % Status-Variablen
    trained_model = [];
    training_results = [];
    use_gpu = false;
    is_training = false;
    stop_requested = false;
    gpu_monitor_timer = [];

    % Berechne Trainingsdaten-Größe
    data_info = calculateDataInfo(training_data);

    % Hauptfenster erstellen
    screen_size = get(0, 'ScreenSize');
    fig_width = 900;
    fig_height = 700;
    fig_x = max(50, (screen_size(3) - fig_width) / 2);
    fig_y = max(50, (screen_size(4) - fig_height) / 2);

    fig = uifigure('Name', 'BILSTM Training', ...
                   'Position', [fig_x, fig_y, fig_width, fig_height], ...
                   'CloseRequestFcn', @closeRequest);

    % Hauptgrid: 2 Spalten (links Einstellungen, rechts Log)
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.RowHeight = {'1x'};
    mainGrid.ColumnWidth = {480, '1x'};
    mainGrid.Padding = [10 10 10 10];
    mainGrid.ColumnSpacing = 10;

    % ============================================================
    % LINKE SPALTE: Einstellungen (scrollbar)
    % ============================================================
    leftPanel = uipanel(mainGrid, 'Title', '', 'Scrollable', 'on', ...
                        'BackgroundColor', fig.Color);
    leftPanel.Layout.Row = 1;
    leftPanel.Layout.Column = 1;

    leftGrid = uigridlayout(leftPanel, [4, 1]);
    leftGrid.RowHeight = {'fit', 'fit', 'fit', 'fit'};
    leftGrid.ColumnWidth = {'1x'};
    leftGrid.Padding = [5 5 5 5];
    leftGrid.RowSpacing = 8;

    % ============================================================
    % RECHTE SPALTE: Log und Status
    % ============================================================
    rightPanel = uipanel(mainGrid, 'Title', 'Training Log', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    rightPanel.Layout.Row = 1;
    rightPanel.Layout.Column = 2;

    rightGrid = uigridlayout(rightPanel, [3, 1]);
    rightGrid.RowHeight = {30, '1x', 45};
    rightGrid.ColumnWidth = {'1x'};
    rightGrid.Padding = [10 10 10 10];
    rightGrid.RowSpacing = 8;

    % Status Header
    status_header = uigridlayout(rightGrid, [1, 2]);
    status_header.RowHeight = {'1x'};
    status_header.ColumnWidth = {'1x', 'fit'};
    status_header.Padding = [0 0 0 0];

    progress_label = uilabel(status_header, 'Text', 'Bereit', ...
                             'FontSize', 11, 'FontWeight', 'bold', ...
                             'HorizontalAlignment', 'left');

    epoch_label = uilabel(status_header, 'Text', '', ...
                          'FontSize', 10, 'HorizontalAlignment', 'right');

    % Log Text Area
    status_area = uitextarea(rightGrid, 'Value', {''}, ...
                             'Editable', 'off', 'FontSize', 9, ...
                             'BackgroundColor', [0.1, 0.1, 0.1], ...
                             'FontColor', [0.8, 0.8, 0.8]);
    status_area.Layout.Row = 2;

    % Buttons in rechter Spalte
    right_btn_grid = uigridlayout(rightGrid, [1, 3]);
    right_btn_grid.RowHeight = {'1x'};
    right_btn_grid.ColumnWidth = {'1x', '1x', '1x'};
    right_btn_grid.Padding = [0 0 0 0];
    right_btn_grid.ColumnSpacing = 10;

    start_btn = uibutton(right_btn_grid, 'Text', 'Training starten', ...
                         'ButtonPushedFcn', @(btn,event) startTraining(), ...
                         'BackgroundColor', [0.2, 0.7, 0.3], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');

    stop_btn = uibutton(right_btn_grid, 'Text', 'Stoppen', ...
                        'ButtonPushedFcn', @(btn,event) stopTraining(), ...
                        'BackgroundColor', [0.8, 0.3, 0.2], ...
                        'FontColor', 'white', ...
                        'FontSize', 12, 'FontWeight', 'bold', ...
                        'Enable', 'off');

    close_btn = uibutton(right_btn_grid, 'Text', 'Schließen', ...
                         'ButtonPushedFcn', @(btn,event) closeRequest(), ...
                         'BackgroundColor', [0.5, 0.5, 0.5], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');

    % ============================================================
    % GRUPPE 1: Trainingsdaten Info (erweitert)
    % ============================================================
    info_group = uipanel(leftGrid, 'Title', 'Trainingsdaten Details', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    info_group.Layout.Row = 1;

    info_grid = uigridlayout(info_group, [5, 4]);
    info_grid.RowHeight = {22, 22, 22, 22, 22};
    info_grid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    info_grid.Padding = [10 8 10 8];
    info_grid.ColumnSpacing = 15;
    info_grid.RowSpacing = 3;

    % Zeile 1: Sequenzen & Sequenzlänge
    uilabel(info_grid, 'Text', 'Sequenzen:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', sprintf('%d', training_data.info.total_sequences), 'FontSize', 10);
    uilabel(info_grid, 'Text', 'Seq.-Länge:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', sprintf('%d Schritte', data_info.seq_length), 'FontSize', 10);

    % Zeile 2: Features & Klassen
    uilabel(info_grid, 'Text', 'Features:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', sprintf('%d', training_data.info.num_features), 'FontSize', 10);
    uilabel(info_grid, 'Text', 'Klassen:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', '3 (BUY/SELL/HOLD)', 'FontSize', 10);

    % Zeile 3: Klassenverteilung
    uilabel(info_grid, 'Text', 'Verteilung:', 'FontSize', 10, 'FontWeight', 'bold');
    class_dist_label = uilabel(info_grid, 'Text', sprintf('BUY:%d | SELL:%d | HOLD:%d', ...
                          training_data.info.num_buy, training_data.info.num_sell, ...
                          training_data.info.num_hold), 'FontSize', 10);
    class_dist_label.Layout.Column = [2, 4];

    % Zeile 4: Datengröße RAM
    uilabel(info_grid, 'Text', 'Daten RAM:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', sprintf('%.2f MB', data_info.total_size_mb), 'FontSize', 10);
    uilabel(info_grid, 'Text', 'Elemente:', 'FontSize', 10, 'FontWeight', 'bold');
    uilabel(info_grid, 'Text', sprintf('%.2f Mio.', data_info.total_elements/1e6), 'FontSize', 10);

    % Zeile 5: Datentyp
    uilabel(info_grid, 'Text', 'Datentyp:', 'FontSize', 10, 'FontWeight', 'bold');
    dtype_label = uilabel(info_grid, 'Text', data_info.data_type, 'FontSize', 10);
    dtype_label.Layout.Column = [2, 4];

    % ============================================================
    % GRUPPE 2: GPU Monitor
    % ============================================================
    gpu_group = uipanel(leftGrid, 'Title', 'GPU Status & Speicher', ...
                        'FontSize', 11, 'FontWeight', 'bold', ...
                        'BackgroundColor', [0.15, 0.15, 0.15]);
    gpu_group.Layout.Row = 2;

    gpu_grid = uigridlayout(gpu_group, [4, 1]);
    gpu_grid.RowHeight = {38, 30, 32, 32};
    gpu_grid.ColumnWidth = {'1x'};
    gpu_grid.Padding = [10 8 10 8];
    gpu_grid.RowSpacing = 6;

    % GPU Switch
    gpu_switch_container = uigridlayout(gpu_grid, [1, 5]);
    gpu_switch_container.ColumnWidth = {'fit', 'fit', 'fit', 20, '1x'};
    gpu_switch_container.Padding = [0 0 0 0];
    gpu_switch_container.ColumnSpacing = 8;

    uilabel(gpu_switch_container, 'Text', 'CPU', 'FontSize', 11, 'FontWeight', 'bold');
    gpu_switch = uiswitch(gpu_switch_container, 'slider', ...
                          'Items', {'CPU', 'GPU'}, ...
                          'Value', 'CPU', ...
                          'ValueChangedFcn', @(sw,event) updateGPUStatus());
    uilabel(gpu_switch_container, 'Text', 'GPU', 'FontSize', 11, 'FontWeight', 'bold');
    uilabel(gpu_switch_container, 'Text', ''); % Spacer
    gpu_name_label = uilabel(gpu_switch_container, 'Text', '', ...
                             'FontSize', 11, 'HorizontalAlignment', 'left');

    % GPU Speicher Bar
    mem_bar_container = uigridlayout(gpu_grid, [1, 2]);
    mem_bar_container.ColumnWidth = {'fit', '1x'};
    mem_bar_container.Padding = [0 0 0 0];
    mem_bar_container.ColumnSpacing = 10;

    uilabel(mem_bar_container, 'Text', 'GPU Speicher:', 'FontSize', 11, 'FontWeight', 'bold');
    gpu_mem_bar = uigauge(mem_bar_container, 'linear', ...
                          'Limits', [0 100], 'Value', 0, ...
                          'MajorTicks', 0:5:100, ...
                          'MajorTickLabels', {'0','','10','','20','','30','','40','','50','','60','','70','','80','','90','','100'}, ...
                          'ScaleColors', {[0.2 0.7 0.2], [0.9 0.7 0.1], [0.8 0.2 0.2]}, ...
                          'ScaleColorLimits', [0 60; 60 85; 85 100]);

    % GPU Speicher Details
    gpu_mem_detail = uigridlayout(gpu_grid, [1, 4]);
    gpu_mem_detail.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    gpu_mem_detail.Padding = [0 0 0 0];
    gpu_mem_detail.ColumnSpacing = 10;

    uilabel(gpu_mem_detail, 'Text', 'Belegt:', 'FontSize', 10);
    gpu_used_label = uilabel(gpu_mem_detail, 'Text', '-- GB', 'FontSize', 10);
    uilabel(gpu_mem_detail, 'Text', 'Frei:', 'FontSize', 10);
    gpu_free_label = uilabel(gpu_mem_detail, 'Text', '-- GB', 'FontSize', 10, ...
                             'FontColor', [0.3, 0.8, 0.3]);

    % Geschätzter Speicherbedarf
    est_mem_container = uigridlayout(gpu_grid, [1, 4]);
    est_mem_container.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    est_mem_container.Padding = [0 0 0 0];
    est_mem_container.ColumnSpacing = 10;

    uilabel(est_mem_container, 'Text', 'Geschätzt:', 'FontSize', 10, 'FontWeight', 'bold');
    est_mem_label = uilabel(est_mem_container, 'Text', '-- GB', 'FontSize', 10, ...
                            'FontColor', [0.9, 0.7, 0.2]);
    uilabel(est_mem_container, 'Text', 'Status:', 'FontSize', 10, 'FontWeight', 'bold');
    mem_status_label = uilabel(est_mem_container, 'Text', '--', 'FontSize', 10);

    % ============================================================
    % GRUPPE 3: Netzwerk-Architektur
    % ============================================================
    arch_group = uipanel(leftGrid, 'Title', 'Netzwerk-Architektur', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    arch_group.Layout.Row = 3;

    arch_grid = uigridlayout(arch_group, [3, 4]);
    arch_grid.RowHeight = {28, 28, 28};
    arch_grid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    arch_grid.Padding = [10 8 10 8];
    arch_grid.ColumnSpacing = 10;
    arch_grid.RowSpacing = 5;

    % Hidden Units
    uilabel(arch_grid, 'Text', 'Hidden Units:', 'FontSize', 10, 'FontWeight', 'bold');
    hidden_field = uieditfield(arch_grid, 'numeric', 'Value', 100, ...
                               'Limits', [10, 1000], 'RoundFractionalValues', 'on', ...
                               'Tooltip', 'Anzahl der LSTM Neuronen pro Schicht', ...
                               'ValueChangedFcn', @(~,~) updateMemoryEstimate());

    % Dropout
    uilabel(arch_grid, 'Text', 'Dropout:', 'FontSize', 10, 'FontWeight', 'bold');
    dropout_field = uieditfield(arch_grid, 'numeric', 'Value', 0.2, ...
                                'Limits', [0, 0.8], 'ValueDisplayFormat', '%.2f', ...
                                'Tooltip', 'Dropout Rate (0.0 - 0.8)');

    % BILSTM Schichten
    uilabel(arch_grid, 'Text', 'BILSTM Schichten:', 'FontSize', 10, 'FontWeight', 'bold');
    layers_dropdown = uidropdown(arch_grid, 'Items', {'1', '2', '3'}, ...
                                  'Value', '2', 'Tooltip', 'Anzahl der BILSTM Schichten', ...
                                  'ValueChangedFcn', @(~,~) updateMemoryEstimate());

    % L2 Regularisierung
    uilabel(arch_grid, 'Text', 'L2 Reg.:', 'FontSize', 10, 'FontWeight', 'bold');
    l2_field = uieditfield(arch_grid, 'numeric', 'Value', 0.0001, ...
                           'Limits', [0, 0.1], 'ValueDisplayFormat', '%.6f', ...
                           'Tooltip', 'L2 Regularisierungsstärke');

    % Aktivierungsfunktion
    uilabel(arch_grid, 'Text', 'Aktivierung:', 'FontSize', 10, 'FontWeight', 'bold');
    activation_dropdown = uidropdown(arch_grid, 'Items', {'tanh', 'relu', 'sigmoid'}, ...
                                      'Value', 'tanh', 'Tooltip', 'Aktivierungsfunktion');

    % ============================================================
    % GRUPPE 4: Training-Parameter
    % ============================================================
    train_group = uipanel(leftGrid, 'Title', 'Training-Parameter', ...
                          'FontSize', 11, 'FontWeight', 'bold', ...
                          'BackgroundColor', [0.15, 0.15, 0.15]);
    train_group.Layout.Row = 4;

    train_grid = uigridlayout(train_group, [4, 4]);
    train_grid.RowHeight = {28, 28, 28, 28};
    train_grid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    train_grid.Padding = [10 8 10 8];
    train_grid.ColumnSpacing = 10;
    train_grid.RowSpacing = 5;

    % Epochen
    uilabel(train_grid, 'Text', 'Epochen:', 'FontSize', 10, 'FontWeight', 'bold');
    epochs_field = uieditfield(train_grid, 'numeric', 'Value', 50, ...
                               'Limits', [1, 10000], 'RoundFractionalValues', 'on', ...
                               'Tooltip', 'Maximale Anzahl der Trainingsepochen');

    % Batch Size
    uilabel(train_grid, 'Text', 'Batch Size:', 'FontSize', 10, 'FontWeight', 'bold');
    batch_field = uieditfield(train_grid, 'numeric', 'Value', 32, ...
                              'Limits', [1, 1024], 'RoundFractionalValues', 'on', ...
                              'Tooltip', 'Mini-Batch Größe', ...
                              'ValueChangedFcn', @(~,~) updateMemoryEstimate());

    % Learning Rate
    uilabel(train_grid, 'Text', 'Learning Rate:', 'FontSize', 10, 'FontWeight', 'bold');
    lr_field = uieditfield(train_grid, 'numeric', 'Value', 0.001, ...
                           'Limits', [0.000001, 1], 'ValueDisplayFormat', '%.6f', ...
                           'Tooltip', 'Initiale Lernrate');

    % Validation Split
    uilabel(train_grid, 'Text', 'Val. Split:', 'FontSize', 10, 'FontWeight', 'bold');
    val_split_field = uieditfield(train_grid, 'numeric', 'Value', 0.2, ...
                                   'Limits', [0.05, 0.5], 'ValueDisplayFormat', '%.2f', ...
                                   'Tooltip', 'Anteil der Validierungsdaten (5%-50%)');

    % Optimizer
    uilabel(train_grid, 'Text', 'Optimizer:', 'FontSize', 10, 'FontWeight', 'bold');
    optimizer_dropdown = uidropdown(train_grid, 'Items', {'adam', 'sgdm', 'rmsprop'}, ...
                                     'Value', 'adam', 'Tooltip', 'Optimierungsalgorithmus');

    % Gradient Threshold
    uilabel(train_grid, 'Text', 'Grad. Clip:', 'FontSize', 10, 'FontWeight', 'bold');
    grad_thresh_field = uieditfield(train_grid, 'numeric', 'Value', 1.0, ...
                                     'Limits', [0.1, 10], 'ValueDisplayFormat', '%.1f', ...
                                     'Tooltip', 'Gradient Clipping Schwellwert');

    % Patience (Early Stopping)
    uilabel(train_grid, 'Text', 'Patience:', 'FontSize', 10, 'FontWeight', 'bold');
    patience_field = uieditfield(train_grid, 'numeric', 'Value', 10, ...
                                  'Limits', [1, 100], 'RoundFractionalValues', 'on', ...
                                  'Tooltip', 'Epochen ohne Verbesserung vor Early Stopping');

    % Shuffle
    uilabel(train_grid, 'Text', 'Shuffle:', 'FontSize', 10, 'FontWeight', 'bold');
    shuffle_dropdown = uidropdown(train_grid, 'Items', {'every-epoch', 'once', 'never'}, ...
                                   'Value', 'every-epoch', 'Tooltip', 'Daten mischen');

    % Initial Updates
    updateGPUStatus();
    updateMemoryEstimate();

    % ============================================================
    % Hilfsfunktionen
    % ============================================================

    function info = calculateDataInfo(td)
        % Berechne detaillierte Informationen über Trainingsdaten
        info = struct();

        % Sequenzlänge aus erster Sequenz
        if ~isempty(td.X) && iscell(td.X)
            first_seq = td.X{1};
            info.seq_length = size(first_seq, 2);
        else
            info.seq_length = 0;
        end

        % Gesamtgröße berechnen
        total_bytes = 0;
        total_elements = 0;
        data_type = 'unknown';

        for i = 1:length(td.X)
            seq = td.X{i};
            total_bytes = total_bytes + numel(seq) * 8; % Annahme: double
            total_elements = total_elements + numel(seq);
            if i == 1
                data_type = class(seq);
            end
        end

        info.total_size_mb = total_bytes / (1024^2);
        info.total_elements = total_elements;
        info.data_type = data_type;
        info.num_sequences = length(td.X);
        info.num_features = td.info.num_features;
    end

    function updateGPUStatus()
        if strcmp(gpu_switch.Value, 'GPU')
            try
                % Prüfe GPU Verfügbarkeit
                gpu_info = gpuDevice;
                use_gpu = true;
                gpu_name_label.Text = gpu_info.Name;
                gpu_name_label.FontColor = [0.3, 0.8, 0.3];

                % Starte GPU Monitor Timer
                startGPUMonitor();

                addStatus(sprintf('GPU aktiviert: %s', gpu_info.Name));
            catch ME
                use_gpu = false;
                gpu_switch.Value = 'CPU';
                gpu_name_label.Text = 'Keine GPU verfügbar';
                gpu_name_label.FontColor = [0.8, 0.3, 0.3];
                stopGPUMonitor();
                resetGPUDisplay();
                uialert(fig, sprintf('GPU nicht verfügbar:\n%s', ME.message), ...
                       'GPU Fehler', 'Icon', 'warning');
            end
        else
            use_gpu = false;
            gpu_name_label.Text = '';
            stopGPUMonitor();
            resetGPUDisplay();
        end
        updateMemoryEstimate();
    end

    function resetGPUDisplay()
        gpu_mem_bar.Value = 0;
        gpu_used_label.Text = '-- GB';
        gpu_free_label.Text = '-- GB';
    end

    function startGPUMonitor()
        stopGPUMonitor(); % Stop existing timer
        gpu_monitor_timer = timer('ExecutionMode', 'fixedRate', ...
                                  'Period', 1.0, ...
                                  'TimerFcn', @(~,~) updateGPUMemoryDisplay());
        start(gpu_monitor_timer);
        updateGPUMemoryDisplay(); % Initial update
    end

    function stopGPUMonitor()
        if ~isempty(gpu_monitor_timer) && isvalid(gpu_monitor_timer)
            stop(gpu_monitor_timer);
            delete(gpu_monitor_timer);
        end
        gpu_monitor_timer = [];
    end

    function updateGPUMemoryDisplay()
        try
            if use_gpu && isvalid(fig)
                gpu_info = gpuDevice;
                total_mem = gpu_info.TotalMemory;
                avail_mem = gpu_info.AvailableMemory;
                used_mem = total_mem - avail_mem;

                % Update Bar
                usage_pct = (used_mem / total_mem) * 100;
                gpu_mem_bar.Value = usage_pct;

                % Update Labels
                gpu_used_label.Text = sprintf('%.2f GB', used_mem / 1e9);
                gpu_free_label.Text = sprintf('%.2f GB', avail_mem / 1e9);

                % Farbe basierend auf Auslastung
                if usage_pct > 85
                    gpu_free_label.FontColor = [0.8, 0.3, 0.3];
                elseif usage_pct > 60
                    gpu_free_label.FontColor = [0.9, 0.7, 0.2];
                else
                    gpu_free_label.FontColor = [0.3, 0.8, 0.3];
                end
            end
        catch
            % GPU nicht mehr verfügbar
        end
    end

    function updateMemoryEstimate()
        % Schätze GPU-Speicherbedarf basierend auf Parametern
        try
            num_sequences = data_info.num_sequences;
            seq_length = data_info.seq_length;
            num_features = data_info.num_features;
            hidden_units = hidden_field.Value;
            num_layers = str2double(layers_dropdown.Value);
            batch_size = batch_field.Value;

            % BILSTM Parameter Schätzung (grob)
            % Jede BILSTM Schicht: 8 * hidden * (input + hidden + 1) Parameter
            % Bidirektional: x2

            input_size = num_features;
            lstm_params = 0;

            for layer = 1:num_layers
                if layer == 1
                    layer_input = input_size;
                else
                    layer_input = hidden_units * 2; % Bidirektional
                end
                % LSTM: 4 gates, jeder mit input und recurrent weights
                layer_params = 4 * hidden_units * (layer_input + hidden_units + 1);
                lstm_params = lstm_params + layer_params * 2; % Bidirektional
            end

            % FC Layer
            fc_params = (hidden_units * 2) * 3 + 3; % 3 Klassen

            total_params = lstm_params + fc_params;

            % Speicher Schätzung:
            % - Parameter: params * 4 bytes (float32)
            % - Gradienten: params * 4 bytes
            % - Optimizer states (Adam): params * 8 bytes (m und v)
            % - Aktivierungen: batch * seq_len * hidden * layers * 4 bytes
            % - Input Daten: batch * seq_len * features * 4 bytes

            param_mem = total_params * 4 / 1e9; % GB
            grad_mem = total_params * 4 / 1e9;
            optimizer_mem = total_params * 8 / 1e9;
            activation_mem = batch_size * seq_length * hidden_units * 2 * num_layers * 4 / 1e9;
            input_mem = batch_size * seq_length * num_features * 4 / 1e9;

            % Overhead Faktor (MATLAB, cuDNN, etc.)
            overhead_factor = 1.5;

            total_estimated = (param_mem + grad_mem + optimizer_mem + activation_mem + input_mem) * overhead_factor;

            est_mem_label.Text = sprintf('%.2f GB', total_estimated);

            % Status basierend auf verfügbarem Speicher
            if use_gpu
                try
                    gpu_info = gpuDevice;
                    avail_gb = gpu_info.AvailableMemory / 1e9;

                    if total_estimated > avail_gb * 0.9
                        mem_status_label.Text = 'KRITISCH';
                        mem_status_label.FontColor = [0.9, 0.2, 0.2];
                        est_mem_label.FontColor = [0.9, 0.2, 0.2];
                    elseif total_estimated > avail_gb * 0.7
                        mem_status_label.Text = 'Knapp';
                        mem_status_label.FontColor = [0.9, 0.7, 0.2];
                        est_mem_label.FontColor = [0.9, 0.7, 0.2];
                    else
                        mem_status_label.Text = 'OK';
                        mem_status_label.FontColor = [0.3, 0.8, 0.3];
                        est_mem_label.FontColor = [0.3, 0.8, 0.3];
                    end
                catch
                    mem_status_label.Text = '--';
                    mem_status_label.FontColor = [0.6, 0.6, 0.6];
                end
            else
                mem_status_label.Text = 'CPU Modus';
                mem_status_label.FontColor = [0.6, 0.6, 0.6];
                est_mem_label.FontColor = [0.6, 0.6, 0.6];
            end

            % Zeige auch Parameteranzahl
            addStatus(sprintf('Netzwerk: ~%.2f Mio. Parameter, geschätzt %.2f GB GPU-RAM', ...
                     total_params/1e6, total_estimated));

        catch ME
            est_mem_label.Text = 'Fehler';
            mem_status_label.Text = '--';
        end
    end

    function addStatus(msg)
        current = status_area.Value;
        timestamp = datestr(now, 'HH:MM:SS');
        new_msg = sprintf('[%s] %s', timestamp, msg);
        status_area.Value = [current; {new_msg}];
        scroll(status_area, 'bottom');
        drawnow;
    end

    function startTraining()
        if is_training
            return;
        end

        is_training = true;
        stop_requested = false;

        % UI Update
        start_btn.Enable = 'off';
        stop_btn.Enable = 'on';
        close_btn.Enable = 'off';
        progress_label.Text = 'Training läuft...';

        % Parameter sammeln
        params = struct();
        params.epochs = epochs_field.Value;
        params.batch_size = batch_field.Value;
        params.learning_rate = lr_field.Value;
        params.validation_split = val_split_field.Value;
        params.num_hidden_units = hidden_field.Value;
        params.dropout = dropout_field.Value;
        params.num_layers = str2double(layers_dropdown.Value);
        params.l2_reg = l2_field.Value;
        params.gradient_threshold = grad_thresh_field.Value;
        params.patience = patience_field.Value;
        params.optimizer = optimizer_dropdown.Value;
        params.shuffle = shuffle_dropdown.Value;

        addStatus('=== Training gestartet ===');
        addStatus(sprintf('Epochen: %d, Batch: %d, LR: %.6f', ...
                  params.epochs, params.batch_size, params.learning_rate));
        addStatus(sprintf('Hidden: %d, Schichten: %d, Dropout: %.2f', ...
                  params.num_hidden_units, params.num_layers, params.dropout));

        log_callback('Training GUI gestartet', 'info');

        try
            % Execution Environment
            if use_gpu
                execution_env = 'gpu';
                addStatus('Verwende GPU für Training');
            else
                execution_env = 'cpu';
                addStatus('Verwende CPU für Training');
            end

            % Training starten
            [net, results] = train_bilstm_model(training_data.X, training_data.Y, ...
                                                training_data.info, ...
                                                'epochs', params.epochs, ...
                                                'batch_size', params.batch_size, ...
                                                'num_hidden_units', params.num_hidden_units, ...
                                                'learning_rate', params.learning_rate, ...
                                                'validation_split', params.validation_split, ...
                                                'execution_env', execution_env, ...
                                                'save_folder', results_folder);

            trained_model = net;
            training_results = results;

            % Erfolg
            addStatus('=== Training abgeschlossen ===');
            addStatus(sprintf('Train Accuracy: %.2f%%', results.train_accuracy * 100));
            addStatus(sprintf('Validation Accuracy: %.2f%%', results.val_accuracy * 100));
            addStatus(sprintf('Trainingszeit: %.1f Minuten', results.training_time / 60));

            progress_label.Text = sprintf('Fertig! Val Acc: %.1f%%', results.val_accuracy * 100);
            epoch_label.Text = sprintf('%d Epochen', params.epochs);

            log_callback(sprintf('Training abgeschlossen: Val Acc=%.2f%%', ...
                        results.val_accuracy * 100), 'success');

            % Modell im Workspace speichern
            assignin('base', 'trained_net', net);
            assignin('base', 'training_results', results);
            addStatus('Modell im Workspace gespeichert (trained_net, training_results)');

            uialert(fig, sprintf('Training erfolgreich!\n\nTrain Acc: %.2f%%\nVal Acc: %.2f%%\nZeit: %.1f Min', ...
                    results.train_accuracy * 100, results.val_accuracy * 100, results.training_time / 60), ...
                    'Erfolg', 'Icon', 'success');

        catch ME
            addStatus(sprintf('FEHLER: %s', ME.message));
            progress_label.Text = 'Fehler!';
            log_callback(sprintf('Training Fehler: %s', ME.message), 'error');
            uialert(fig, sprintf('Training fehlgeschlagen:\n%s', ME.message), ...
                   'Fehler', 'Icon', 'error');
        end

        % UI zurücksetzen
        is_training = false;
        start_btn.Enable = 'on';
        stop_btn.Enable = 'off';
        close_btn.Enable = 'on';
    end

    function stopTraining()
        stop_requested = true;
        addStatus('Stopp angefordert...');
        % Hinweis: Das tatsächliche Stoppen muss in train_bilstm_model implementiert werden
    end

    function closeRequest(~, ~)
        if is_training
            answer = uiconfirm(fig, 'Training läuft noch. Wirklich schließen?', ...
                              'Bestätigung', 'Options', {'Ja', 'Nein'}, ...
                              'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(answer, 'Nein')
                return;
            end
        end

        % Timer stoppen
        stopGPUMonitor();

        delete(fig);
    end

end
