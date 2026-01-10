function [net, training_results] = train_bilstm_model(X_train, Y_train, training_info, varargin)
% TRAIN_BILSTM_MODEL Trainiert ein BILSTM Netzwerk für Trendwechsel-Erkennung
%
%   [net, training_results] = TRAIN_BILSTM_MODEL(X_train, Y_train, training_info)
%   erstellt und trainiert ein bidirektionales LSTM Netzwerk mit 100 Neuronen
%   zur Erkennung von Trendwechseln (BUY/SELL/HOLD).
%
%   Input:
%       X_train - Cell Array mit Trainingssequenzen
%       Y_train - Cell Array mit Labels (categorical)
%       training_info - Struct mit Informationen über Trainingsdaten
%       varargin - Optional: 'epochs', wert (default: 50)
%                           'validation_split', wert (default: 0.2)
%                           'save_folder', pfad (optional, für Speichern des Trainingsplots)
%
%   Output:
%       net - Trainiertes BILSTM Netzwerk
%       training_results - Struct mit Trainingsmetriken
%
%   Beispiel:
%       data = read_btc_data('BTCUSD_H1_202509250000_202512311700.csv');
%       [X, Y, info] = prepare_training_data(data);
%       [net, results] = train_bilstm_model(X, Y, info);

    % Parameter
    p = inputParser;
    addParameter(p, 'epochs', 50, @isnumeric);
    addParameter(p, 'validation_split', 0.2, @isnumeric);
    addParameter(p, 'batch_size', 32, @isnumeric);
    addParameter(p, 'execution_env', 'auto', @ischar);
    addParameter(p, 'num_hidden_units', 100, @isnumeric);
    addParameter(p, 'learning_rate', 0.001, @isnumeric);
    addParameter(p, 'save_folder', '', @ischar);
    parse(p, varargin{:});

    max_epochs = p.Results.epochs;
    validation_split = p.Results.validation_split;
    mini_batch_size = p.Results.batch_size;
    execution_env = p.Results.execution_env;
    num_hidden_units = p.Results.num_hidden_units;
    learning_rate = p.Results.learning_rate;
    save_folder = p.Results.save_folder;

    fprintf('=== BILSTM Netzwerk Training ===\n\n');

    %% 1. Konvertiere Y_train von Cell Array zu categorical Array
    fprintf('Konvertiere Labels...\n');
    Y_train_cat = categorical(zeros(length(Y_train), 1));
    for i = 1:length(Y_train)
        Y_train_cat(i) = Y_train{i};
    end

    %% 2. Daten aufteilen (Training / Validation)
    fprintf('Schritt 1: Datenaufteilung...\n');
    num_samples = length(X_train);
    num_validation = round(num_samples * validation_split);
    num_training = num_samples - num_validation;

    % Zufällige Permutation für Mischung
    rng(42);
    indices = randperm(num_samples);

    train_idx = indices(1:num_training);
    val_idx = indices(num_training+1:end);

    X_tr = X_train(train_idx);
    Y_tr = Y_train_cat(train_idx);
    X_val = X_train(val_idx);
    Y_val = Y_train_cat(val_idx);

    fprintf('  Training Samples: %d (%.1f%%)\n', num_training, (1-validation_split)*100);
    fprintf('  Validation Samples: %d (%.1f%%)\n', num_validation, validation_split*100);

    %% 2. Netzwerk-Architektur definieren
    fprintf('\nSchritt 2: Erstelle BILSTM Netzwerk-Architektur...\n');

    num_features = training_info.num_features;
    num_classes = 3;  % HOLD, BUY, SELL

    layers = [
        sequenceInputLayer(num_features, 'Name', 'input')

        % Erste BILSTM Schicht
        bilstmLayer(num_hidden_units, 'OutputMode', 'sequence', 'Name', 'bilstm1')
        dropoutLayer(0.2, 'Name', 'dropout1')

        % Zweite BILSTM Schicht
        bilstmLayer(num_hidden_units, 'OutputMode', 'last', 'Name', 'bilstm2')
        dropoutLayer(0.2, 'Name', 'dropout2')

        % Fully Connected und Klassifikation
        fullyConnectedLayer(num_classes, 'Name', 'fc')
        softmaxLayer('Name', 'softmax')
        classificationLayer('Name', 'classification')
    ];

    fprintf('  Architektur:\n');
    fprintf('    - Input: %d Features\n', num_features);
    fprintf('    - BILSTM Layer 1: %d Neuronen (sequence output)\n', num_hidden_units);
    fprintf('    - Dropout: 20%%\n');
    fprintf('    - BILSTM Layer 2: %d Neuronen (last output)\n', num_hidden_units);
    fprintf('    - Dropout: 20%%\n');
    fprintf('    - Fully Connected: %d Klassen\n', num_classes);
    fprintf('    - Softmax + Classification\n');

    %% 3. Trainingsoptionen
    fprintf('\nSchritt 3: Konfiguriere Training...\n');

    options = trainingOptions('adam', ...
        'MaxEpochs', max_epochs, ...
        'MiniBatchSize', mini_batch_size, ...
        'ValidationData', {X_val, Y_val}, ...
        'ValidationFrequency', 10, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', true, ...
        'Plots', 'training-progress', ...
        'InitialLearnRate', learning_rate, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropFactor', 0.5, ...
        'LearnRateDropPeriod', 20, ...
        'GradientThreshold', 1, ...
        'ExecutionEnvironment', execution_env);

    fprintf('  Optimizer: Adam\n');
    fprintf('  Max Epochs: %d\n', max_epochs);
    fprintf('  Mini-Batch Size: %d\n', mini_batch_size);
    fprintf('  Execution Environment: %s\n', upper(execution_env));
    fprintf('  Initial Learning Rate: %.4f\n', learning_rate);
    fprintf('  Learning Rate Drop: 0.5 alle 20 Epochen\n');

    % GPU Info anzeigen wenn GPU verwendet wird
    if strcmp(execution_env, 'gpu')
        try
            gpu_info = gpuDevice;
            fprintf('  GPU: %s (%.1f GB)\n', gpu_info.Name, gpu_info.AvailableMemory/1e9);
        catch
            warning('GPU angefordert aber nicht verfügbar, verwende CPU');
        end
    end

    %% 4. Training starten
    fprintf('\n=== Starte Training ===\n\n');

    % Variablen für Plot-Speicherung
    training_fig_saved = false;
    last_training_fig = [];

    if ~isempty(save_folder)
        % OutputFcn: Speichert Fenster-Handle bei jeder Iteration und am Ende
        options.OutputFcn = @(info) captureAndSaveTrainingPlot(info, save_folder);
    end

    tic;
    net = trainNetwork(X_tr, Y_tr, layers, options);
    training_time = toc;

    fprintf('\n=== Training abgeschlossen ===\n');
    fprintf('Trainingszeit: %.2f Sekunden (%.2f Minuten)\n', ...
            training_time, training_time/60);

    % Nested function: Speichert das Fenster bei "done" oder "stop"
    function stop = captureAndSaveTrainingPlot(info, folder)
        stop = false;

        % Bei jeder Iteration: Fenster-Handle aktualisieren
        if info.State == "iteration"
            fig = findall(0, 'Type', 'Figure', 'Name', 'Training Progress');
            if ~isempty(fig)
                last_training_fig = fig(1);
            end
        end

        % Bei "done" oder wenn Training fertig ist: Speichern
        if (info.State == "done" || info.State == "stop") && ~training_fig_saved
            try
                drawnow;  % Sicherstellen, dass alles gerendert ist

                % Fenster finden
                fig = findall(0, 'Type', 'Figure', 'Name', 'Training Progress');
                if isempty(fig) && ~isempty(last_training_fig) && isvalid(last_training_fig)
                    fig = last_training_fig;
                end

                if ~isempty(fig) && isvalid(fig(1))
                    plot_filename = fullfile(folder, 'training_plot.png');
                    exportgraphics(fig(1), plot_filename, 'Resolution', 300);
                    fprintf('Trainingsfenster gespeichert: %s\n', plot_filename);
                    training_fig_saved = true;
                else
                    fprintf('Warnung: Trainingsfenster nicht verfügbar.\n');
                end
            catch ME
                fprintf('Warnung: Fehler beim Speichern: %s\n', ME.message);
            end
        end
    end

    %% 5. Evaluierung
    fprintf('\nSchritt 4: Evaluiere Modell...\n');

    % Training Accuracy
    Y_pred_train = classify(net, X_tr);
    train_accuracy = sum(Y_pred_train == Y_tr) / numel(Y_tr) * 100;

    % Validation Accuracy
    Y_pred_val = classify(net, X_val);
    val_accuracy = sum(Y_pred_val == Y_val) / numel(Y_val) * 100;

    fprintf('\n=== Ergebnisse ===\n');
    fprintf('Training Accuracy: %.2f%%\n', train_accuracy);
    fprintf('Validation Accuracy: %.2f%%\n', val_accuracy);

    % Confusion Matrix für Validation
    fprintf('\nConfusion Matrix (Validation):\n');
    cm = confusionmat(Y_val, Y_pred_val);
    disp(cm);

    % Klassifizierungsmetriken
    fprintf('\nKlassifizierungs-Metriken (Validation):\n');
    for i = 1:num_classes
        class_name = training_info.classes{i};
        true_positives = cm(i, i);
        false_positives = sum(cm(:, i)) - true_positives;
        false_negatives = sum(cm(i, :)) - true_positives;

        precision = true_positives / (true_positives + false_positives);
        recall = true_positives / (true_positives + false_negatives);
        f1_score = 2 * (precision * recall) / (precision + recall);

        fprintf('  %s:\n', class_name);
        fprintf('    Precision: %.2f%%\n', precision * 100);
        fprintf('    Recall: %.2f%%\n', recall * 100);
        fprintf('    F1-Score: %.2f%%\n', f1_score * 100);
    end

    %% 6. Ergebnisse speichern
    training_results = struct();
    training_results.train_accuracy = train_accuracy;
    training_results.val_accuracy = val_accuracy;
    training_results.confusion_matrix = cm;
    training_results.training_time = training_time;
    training_results.max_epochs = max_epochs;
    training_results.mini_batch_size = mini_batch_size;
    training_results.num_training_samples = num_training;
    training_results.num_validation_samples = num_validation;

    fprintf('\n=== Modell bereit für Vorhersagen ===\n');
end
