clear; clc;

addpath('/Users/elizabeth/cshore/usace_distribute_bundle/mfiles')
addpath(genpath('/Users/elizabeth/cshore/usace_distribute_bundle/mfiles'))

% ---------------------------
% Base directories
% ---------------------------
base_data_dir = '/Users/elizabeth/cshore/flume_data';
outdir        = '/Users/elizabeth/cshore/flume_data/generated_infiles';

if ~exist(outdir, 'dir')
    mkdir(outdir);
end

% Map profile names to the folders where their wave files live
wave_root_map = containers.Map;
wave_root_map('cntrl') = fullfile(base_data_dir, 'Control');
wave_root_map('ab')    = fullfile(base_data_dir, 'Above and Belowground');
wave_root_map('a')     = fullfile(base_data_dir, 'Above Ground');
wave_root_map('b')     = fullfile(base_data_dir, 'Below Ground');

% ---------------------------
% Wave-condition folders
% ---------------------------
wave_groups = { ...
    'Deep Collision', ...
    'Deep Overwash', ...
    'Shallow Collision', ...
    'Shallow Collision 2', ...
    'Shallow Overwash'};

% ---------------------------
% Profile names to build
% ---------------------------
profile_names = {'cntrl','A','AB','B'};

% ---------------------------
% Map each wave group to a transect MAT file
% ---------------------------
transect_map = containers.Map;
transect_map('Deep Collision')      = fullfile(base_data_dir, 'final_transects_deepcollision.mat');
transect_map('Deep Overwash')       = fullfile(base_data_dir, 'final_transects_deepoverwash.mat');
transect_map('Shallow Collision')   = fullfile(base_data_dir, 'final_transects_shallowcollisionSC1.mat');
transect_map('Shallow Collision 2') = fullfile(base_data_dir, 'final_transects_shallowcollisionSC2.mat');
transect_map('Shallow Overwash')    = fullfile(base_data_dir, 'final_transects_shallowoverwash.mat');

% ---------------------------
% Loop over all combinations
% ---------------------------
for ig = 1:numel(wave_groups)
    wave_group = wave_groups{ig};
    transect_mat = transect_map(wave_group);

    if ~isfile(transect_mat)
        warning('Transect file not found, skipping group: %s\n%s', wave_group, transect_mat);
        continue
    end

    for ip = 1:numel(profile_names)
        profile_name = profile_names{ip};
        profile_key  = lower(profile_name);

        if ~isKey(wave_root_map, profile_key)
            warning('No wave root defined for profile: %s', profile_name);
            continue
        end

        wave_root = wave_root_map(profile_key);
        wave_group_dir = fullfile(wave_root, wave_group);

        if ~isfolder(wave_group_dir)
            warning('Wave folder not found, skipping:\n%s', wave_group_dir);
            continue
        end

        % Find all Test*.mat files that actually exist for this profile/group
        wave_files = dir(fullfile(wave_group_dir, 'Test*.mat'));

        if isempty(wave_files)
            warning('No wave files found in: %s', wave_group_dir);
            continue
        end

        for iw = 1:numel(wave_files)
            wave_filename = wave_files(iw).name;
            wave_mat = fullfile(wave_group_dir, wave_filename);

            % Extract test ID from filename like TestN1.mat
            tokens = regexp(wave_filename, '^Test(.+)\.mat$', 'tokens', 'once');
            if isempty(tokens)
                warning('Could not parse test ID from filename: %s', wave_filename);
                continue
            end
            test_id = tokens{1};

            try
                fprintf('\n============================\n');
                fprintf('Building infile for:\n');
                fprintf('  Group   : %s\n', wave_group);
                fprintf('  Profile : %s\n', profile_name);
                fprintf('  Test    : %s\n', test_id);
                fprintf('============================\n');

                build_single_flume_infile( ...
                    transect_mat, wave_mat, profile_name, outdir, wave_group, test_id);

            catch ME
                warning('FAILED: group=%s, profile=%s, test=%s\n%s', ...
                    wave_group, profile_name, test_id, ME.message);
            end
        end
    end
end

disp('All requested infile builds are complete.');