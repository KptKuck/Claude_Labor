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

    % Hauptfenster erstellen
    screen_size = get(0, 'ScreenSize');
    fig_width = 500;
    fig_height = 600;
    fig_x = max(50, (screen_size(3) - fig_width) / 2);
    fig_y = max(50, (screen_size(4) - fig_height) / 2);

    fig = uifigure('Name', 'BILSTM Training', ...
                   'Position', [fig_x, fig_y, fig_width, fig_height], ...
                   'CloseRequestFcn', @closeRequest);

    % Hauptgrid
    mainGrid = uigridlayout(fig, [6, 1]);
    mainGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', '1x'};
    mainGrid.ColumnWidth = {'1x'};
    mainGrid.Padding = [15 15 15 15];
    mainGrid.RowSpacing = 10;

    % ============================================================
    % GRUPPE 1: Trainingsdaten Info
    % ============================================================
    info_group = uipanel(mainGrid, 'Title', 'Trainingsdaten', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    info_group.Layout.Row = 1;

    info_grid = uigridlayout(info_group, [3, 2]);
    info_grid.RowHeight = {25, 25, 25};
    info_grid.ColumnWidth = {'fit', '1x'};
    info_grid.Padding = [10 10 10 10];
    info_grid.ColumnSpacing = 10;

    uilabel(info_grid, 'Text', 'Sequenzen:', 'FontSize', 10, 'FontWeight', 'bold');
    seq_label = uilabel(info_grid, 'Text', sprintf('%d', training_data.info.total_sequences), ...
                        'FontSize', 10);

    uilabel(info_grid, 'Text', 'Features:', 'FontSize', 10, 'FontWeight', 'bold');
    feat_label = uilabel(info_grid, 'Text', sprintf('%d', training_data.info.num_features), ...
                         'FontSize', 10);

    uilabel(info_grid, 'Text', 'Klassen:', 'FontSize', 10, 'FontWeight', 'bold');
    class_label = uilabel(info_grid, 'Text', sprintf('BUY: %d | SELL: %d | HOLD: %d', ...
                          training_data.info.num_buy, training_data.info.num_sell, ...
                          training_data.info.num_hold), 'FontSize', 10);

    % ============================================================
    % GRUPPE 2: Netzwerk-Architektur
    % ============================================================
    arch_group = uipanel(mainGrid, 'Title', 'Netzwerk-Architektur', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    arch_group.Layout.Row = 2;

    arch_grid = uigridlayout(arch_group, [3, 4]);
    arch_grid.RowHeight = {30, 30, 30};
    arch_grid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    arch_grid.Padding = [10 10 10 10];
    arch_grid.ColumnSpacing = 10;
    arch_grid.RowSpacing = 8;

    % Hidden Units
    uilabel(arch_grid, 'Text', 'Hidden Units:', 'FontSize', 10, 'FontWeight', 'bold');
    hidden_field = uieditfield(arch_grid, 'numeric', 'Value', 100, ...
                               'Limits', [10, 1000], 'RoundFractionalValues', 'on', ...
                               'Tooltip', 'Anzahl der LSTM Neuronen pro Schicht');

    % Dropout
    uilabel(arch_grid, 'Text', 'Dropout:', 'FontSize', 10, 'FontWeight', 'bold');
    dropout_field = uieditfield(arch_grid, 'numeric', 'Value', 0.2, ...
                                'Limits', [0, 0.8], 'ValueDisplayFormat', '%.2f', ...
                                'Tooltip', 'Dropout Rate (0.0 - 0.8)');

    % BILSTM Schichten
    uilabel(arch_grid, 'Text', 'BILSTM Schichten:', 'FontSize', 10, 'FontWeight', 'bold');
    layers_dropdown = uidropdown(arch_grid, 'Items', {'1', '2', '3'}, ...
                                  'Value', '2', 'Tooltip', 'Anzahl der BILSTM Schichten');

    % Aktivierungsfunktion
    uilabel(arch_grid, 'Text', 'Aktivierung:', 'FontSize', 10, 'FontWeight', 'bold');
    activation_dropdown = uidropdown(arch_grid, 'Items', {'tanh', 'relu', 'sigmoid'}, ...
                                      'Value', 'tanh', 'Tooltip', 'Aktivierungsfunktion');

    % L2 Regularisierung
    uilabel(arch_grid, 'Text', 'L2 Regularisierung:', 'FontSize', 10, 'FontWeight', 'bold');
    l2_field = uieditfield(arch_grid, 'numeric', 'Value', 0.0001, ...
                           'Limits', [0, 0.1], 'ValueDisplayFormat', '%.6f', ...
                           'Tooltip', 'L2 Regularisierungsstärke');

    % ============================================================
    % GRUPPE 3: Training-Parameter
    % ============================================================
    train_group = uipanel(mainGrid, 'Title', 'Training-Parameter', ...
                          'FontSize', 11, 'FontWeight', 'bold', ...
                          'BackgroundColor', [0.15, 0.15, 0.15]);
    train_group.Layout.Row = 3;

    train_grid = uigridlayout(train_group, [4, 4]);
    train_grid.RowHeight = {30, 30, 30, 30};
    train_grid.ColumnWidth = {'fit', '1x', 'fit', '1x'};
    train_grid.Padding = [10 10 10 10];
    train_grid.ColumnSpacing = 10;
    train_grid.RowSpacing = 8;

    % Epochen
    uilabel(train_grid, 'Text', 'Epochen:', 'FontSize', 10, 'FontWeight', 'bold');
    epochs_field = uieditfield(train_grid, 'numeric', 'Value', 50, ...
                               'Limits', [1, 10000], 'RoundFractionalValues', 'on', ...
                               'Tooltip', 'Maximale Anzahl der Trainingsepochen');

    % Batch Size
    uilabel(train_grid, 'Text', 'Batch Size:', 'FontSize', 10, 'FontWeight', 'bold');
    batch_field = uieditfield(train_grid, 'numeric', 'Value', 32, ...
                              'Limits', [1, 1024], 'RoundFractionalValues', 'on', ...
                              'Tooltip', 'Mini-Batch Größe');

    % Learning Rate
    uilabel(train_grid, 'Text', 'Learning Rate:', 'FontSize', 10, 'FontWeight', 'bold');
    lr_field = uieditfield(train_grid, 'numeric', 'Value', 0.001, ...
                           'Limits', [0.000001, 1], 'ValueDisplayFormat', '%.6f', ...
                           'Tooltip', 'Initiale Lernrate');

    % Validation Split
    uilabel(train_grid, 'Text', 'Validation Split:', 'FontSize', 10, 'FontWeight', 'bold');
    val_split_field = uieditfield(train_grid, 'numeric', 'Value', 0.2, ...
                                   'Limits', [0.05, 0.5], 'ValueDisplayFormat', '%.2f', ...
                                   'Tooltip', 'Anteil der Validierungsdaten (5%-50%)');

    % Optimizer
    uilabel(train_grid, 'Text', 'Optimizer:', 'FontSize', 10, 'FontWeight', 'bold');
    optimizer_dropdown = uidropdown(train_grid, 'Items', {'adam', 'sgdm', 'rmsprop'}, ...
                                     'Value', 'adam', 'Tooltip', 'Optimierungsalgorithmus');

    % Gradient Threshold
    uilabel(train_grid, 'Text', 'Gradient Clip:', 'FontSize', 10, 'FontWeight', 'bold');
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

    % ============================================================
    % GRUPPE 4: Ausführung
    % ============================================================
    exec_group = uipanel(mainGrid, 'Title', 'Ausführung', ...
                         'FontSize', 11, 'FontWeight', 'bold', ...
                         'BackgroundColor', [0.15, 0.15, 0.15]);
    exec_group.Layout.Row = 4;

    exec_grid = uigridlayout(exec_group, [1, 3]);
    exec_grid.RowHeight = {40};
    exec_grid.ColumnWidth = {'1x', 'fit', '1x'};
    exec_grid.Padding = [10 10 10 10];

    % Spacer links
    uilabel(exec_grid, 'Text', '');

    % GPU Switch mit Label
    gpu_container = uigridlayout(exec_grid, [1, 3]);
    gpu_container.ColumnWidth = {'fit', 'fit', 'fit'};
    gpu_container.Padding = [0 0 0 0];
    gpu_container.ColumnSpacing = 10;

    uilabel(gpu_container, 'Text', 'CPU', 'FontSize', 10, 'FontWeight', 'bold');
    gpu_switch = uiswitch(gpu_container, 'slider', ...
                          'Items', {'CPU', 'GPU'}, ...
                          'Value', 'CPU', ...
                          'ValueChangedFcn', @(sw,event) updateGPUStatus());
    uilabel(gpu_container, 'Text', 'GPU', 'FontSize', 10, 'FontWeight', 'bold');

    % GPU Status Label
    gpu_status_label = uilabel(exec_grid, 'Text', '', ...
                               'FontSize', 10, 'HorizontalAlignment', 'left');

    % Initial GPU Status prüfen
    updateGPUStatus();

    % ============================================================
    % GRUPPE 5: Buttons
    % ============================================================
    btn_group = uipanel(mainGrid, 'Title', '', 'BorderType', 'none', ...
                        'BackgroundColor', fig.Color);
    btn_group.Layout.Row = 5;

    btn_grid = uigridlayout(btn_group, [1, 3]);
    btn_grid.RowHeight = {45};
    btn_grid.ColumnWidth = {'1x', '1x', '1x'};
    btn_grid.Padding = [0 5 0 5];
    btn_grid.ColumnSpacing = 10;

    start_btn = uibutton(btn_grid, 'Text', 'Training starten', ...
                         'ButtonPushedFcn', @(btn,event) startTraining(), ...
                         'BackgroundColor', [0.2, 0.7, 0.3], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');

    stop_btn = uibutton(btn_grid, 'Text', 'Stoppen', ...
                        'ButtonPushedFcn', @(btn,event) stopTraining(), ...
                        'BackgroundColor', [0.8, 0.3, 0.2], ...
                        'FontColor', 'white', ...
                        'FontSize', 12, 'FontWeight', 'bold', ...
                        'Enable', 'off');

    close_btn = uibutton(btn_grid, 'Text', 'Schließen', ...
                         'ButtonPushedFcn', @(btn,event) closeRequest(), ...
                         'BackgroundColor', [0.5, 0.5, 0.5], ...
                         'FontColor', 'white', ...
                         'FontSize', 12, 'FontWeight', 'bold');

    % ============================================================
    % GRUPPE 6: Status / Log
    % ============================================================
    status_group = uipanel(mainGrid, 'Title', 'Status', ...
                           'FontSize', 11, 'FontWeight', 'bold', ...
                           'BackgroundColor', [0.15, 0.15, 0.15]);
    status_group.Layout.Row = 6;

    status_grid = uigridlayout(status_group, [2, 1]);
    status_grid.RowHeight = {25, '1x'};
    status_grid.ColumnWidth = {'1x'};
    status_grid.Padding = [10 10 10 10];

    % Progress Bar (als Label simuliert)
    progress_label = uilabel(status_grid, 'Text', 'Bereit', ...
                             'FontSize', 10, 'FontWeight', 'bold', ...
                             'HorizontalAlignment', 'center', ...
                             'BackgroundColor', [0.3, 0.3, 0.3]);

    % Status Text Area
    status_area = uitextarea(status_grid, 'Value', {''}, ...
                             'Editable', 'off', 'FontSize', 9, ...
                             'BackgroundColor', [0.1, 0.1, 0.1], ...
                             'FontColor', [0.8, 0.8, 0.8]);

    % ============================================================
    % Callback Funktionen
    % ============================================================

    function updateGPUStatus()
        if strcmp(gpu_switch.Value, 'GPU')
            try
                % Prüfe GPU Verfügbarkeit
                gpu_info = gpuDevice;
                use_gpu = true;
                gpu_status_label.Text = sprintf('✓ %s (%.1f GB)', ...
                    gpu_info.Name, gpu_info.TotalMemory/1e9);
                gpu_status_label.FontColor = [0.3, 0.8, 0.3];
            catch
                use_gpu = false;
                gpu_switch.Value = 'CPU';
                gpu_status_label.Text = '✗ Keine GPU verfügbar';
                gpu_status_label.FontColor = [0.8, 0.3, 0.3];
                uialert(fig, 'Keine kompatible GPU gefunden. Training wird auf CPU ausgeführt.', ...
                       'GPU nicht verfügbar', 'Icon', 'warning');
            end
        else
            use_gpu = false;
            gpu_status_label.Text = '';
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
        progress_label.BackgroundColor = [0.2, 0.5, 0.8];

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

        addStatus('Training gestartet...');
        addStatus(sprintf('Epochen: %d, Batch: %d, LR: %.6f', ...
                  params.epochs, params.batch_size, params.learning_rate));
        addStatus(sprintf('Hidden: %d, Dropout: %.2f, Schichten: %d', ...
                  params.num_hidden_units, params.dropout, params.num_layers));

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
            addStatus('Training abgeschlossen!');
            addStatus(sprintf('Train Accuracy: %.2f%%', results.train_accuracy * 100));
            addStatus(sprintf('Validation Accuracy: %.2f%%', results.val_accuracy * 100));
            addStatus(sprintf('Trainingszeit: %.1f Minuten', results.training_time / 60));

            progress_label.Text = sprintf('Fertig! Val Acc: %.1f%%', results.val_accuracy * 100);
            progress_label.BackgroundColor = [0.2, 0.7, 0.3];

            log_callback(sprintf('Training abgeschlossen: Val Acc=%.2f%%', ...
                        results.val_accuracy * 100), 'success');

            % Modell im Workspace speichern
            assignin('base', 'trained_net', net);
            assignin('base', 'training_results', results);
            addStatus('Modell im Workspace gespeichert (trained_net, training_results)');

        catch ME
            addStatus(sprintf('FEHLER: %s', ME.message));
            progress_label.Text = 'Fehler!';
            progress_label.BackgroundColor = [0.8, 0.3, 0.2];
            log_callback(sprintf('Training Fehler: %s', ME.message), 'error');
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
        delete(fig);
    end

end
