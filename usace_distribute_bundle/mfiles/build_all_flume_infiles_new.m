clear; clc;

addpath(genpath('/Users/elizabeth/cshore/usace_distribute_bundle/mfiles'))

% ---------------------------
% Base directories
% ---------------------------
base_data_dir = '/Users/elizabeth/cshore/flume_data';
outdir        = fullfile(base_data_dir, 'generated_infiles');

if ~exist(outdir, 'dir')
    mkdir(outdir);
end

% ---------------------------
% Treatment folders that contain wave data
% ---------------------------
treatment_folders = { ...
    'Control', ...
    'Above Ground', ...
    'Above and Below Ground', ...
    'Below Ground'};

% ---------------------------
% Wave groups
% ---------------------------
wave_groups = { ...
    'Deep Collision', ...
    'Deep Overwash', ...
    'Shallow Collision', ...
    'Shallow Collision 2', ...
    'Shallow Overwash'};

% ---------------------------
% Map wave group -> transect MAT in base directory
% ---------------------------
transect_map = containers.Map;
transect_map('Deep Collision')      = fullfile(base_data_dir, 'final_transects_deepcollision.mat');
transect_map('Deep Overwash')       = fullfile(base_data_dir, 'final_transects_deepoverwash.mat');
transect_map('Shallow Collision')   = fullfile(base_data_dir, 'final_transects_shallowcollisionSC1.mat');
transect_map('Shallow Collision 2') = fullfile(base_data_dir, 'final_transects_shallowcollisionSC2.mat');
transect_map('Shallow Overwash')    = fullfile(base_data_dir, 'final_transects_shallowoverwash.mat');

for it = 1:numel(treatment_folders)
    treatment_folder = treatment_folders{it};
    treatment_dir    = fullfile(base_data_dir, treatment_folder);

    if ~isfolder(treatment_dir)
        warning('Treatment folder not found, skipping:\n%s', treatment_dir);
        continue
    end

    for ig = 1:numel(wave_groups)
        wave_group = wave_groups{ig};

        % Skip certain wave groups
        skip_groups = {'Shallow Collision', 'Shallow Collision 2'};

        if any(strcmpi(wave_group, skip_groups))
            fprintf('Skipping wave group: %s\n', wave_group);
            continue
        end

        if ~isKey(transect_map, wave_group)
            warning('No transect mapping found for wave group: %s', wave_group);
            continue
        end

        transect_mat = transect_map(wave_group);

        if ~isfile(transect_mat)
            warning('Transect MAT not found, skipping:\n%s', transect_mat);
            continue
        end

        wave_group_dir = fullfile(treatment_dir, wave_group);

        if ~isfolder(wave_group_dir)
            warning('Wave group folder not found, skipping:\n%s', wave_group_dir);
            continue
        end

        wave_files = dir(fullfile(wave_group_dir, 'Test*.mat'));

        if isempty(wave_files)
            warning('No Test*.mat files found in:\n%s', wave_group_dir);
            continue
        end

        for iw = 1:numel(wave_files)
            wave_filename = wave_files(iw).name;
            wave_mat      = fullfile(wave_group_dir, wave_filename);

            % Parse filenames like:
            %   TestN1.mat
            %   TestC1-AB.mat
            %   TestR2-A.mat
            %   TestE3-B.mat
            tokens = regexp(wave_filename, '^Test([A-Za-z0-9]+)(?:-([A-Za-z]+))?\.mat$', ...
                            'tokens', 'once');

            if isempty(tokens)
                warning('Could not parse wave filename, skipping: %s', wave_filename);
                continue
            end

            test_id = tokens{1};

            if numel(tokens) >= 2 && ~isempty(tokens{2})
                profile_name = upper(tokens{2});
            else
                switch lower(treatment_folder)
                    case 'control'
                        profile_name = 'cntrl';
                    case 'above ground'
                        profile_name = 'A';
                    case 'above and below ground'
                        profile_name = 'AB';
                    case 'below ground'
                        profile_name = 'B';
                    otherwise
                        warning('Could not infer profile from treatment folder: %s', treatment_folder);
                        continue
                end
            end

            try
                fprintf('\n============================\n');
                fprintf('Building infile for:\n');
                fprintf('  Treatment : %s\n', treatment_folder);
                fprintf('  Group     : %s\n', wave_group);
                fprintf('  Test      : %s\n', test_id);
                fprintf('  Profile   : %s\n', profile_name);
                fprintf('  Wave file : %s\n', wave_filename);
                fprintf('  Transect  : %s\n', transect_mat);
                fprintf('============================\n');

                build_single_flume_infile( ...
                    transect_mat, wave_mat, profile_name, outdir, wave_group, test_id, treatment_folder);

            catch ME
                warning('FAILED: treatment=%s, group=%s, test=%s, profile=%s\n%s', ...
                    treatment_folder, wave_group, test_id, profile_name, ME.message);
            end
        end
    end
end

disp('All requested infile builds are complete.');