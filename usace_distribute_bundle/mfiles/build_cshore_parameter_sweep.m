clear; clc;

addpath(genpath('/Users/elizabeth/cshore/usace_distribute_bundle/mfiles'))

% ---------------------------
% Base directories
% ---------------------------
base_data_dir = '/Users/elizabeth/cshore/flume_data';
outdir        = fullfile(base_data_dir, 'generated_infiles_sweep');

if ~exist(outdir, 'dir')
    mkdir(outdir);
end

% ---------------------------
% Target cases to sweep
% ---------------------------
target_cases = { ...
    struct('treatment_folder', 'Control', 'wave_group', 'Deep Collision',   'test_id', 'N1', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Deep Collision',   'test_id', 'N2', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Deep Collision',   'test_id', 'N3', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Deep Overwash',    'test_id', 'O1', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Shallow Overwash', 'test_id', 'E1', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Shallow Overwash', 'test_id', 'E2', 'profile_name', 'cntrl'), ...
    struct('treatment_folder', 'Control', 'wave_group', 'Shallow Overwash', 'test_id', 'E3', 'profile_name', 'cntrl')  ...
};

% ---------------------------
% Map wave group -> transect MAT
% ---------------------------
transect_map = containers.Map;
transect_map('Deep Collision')      = fullfile(base_data_dir, 'final_transects_deepcollision.mat');
transect_map('Deep Overwash')       = fullfile(base_data_dir, 'final_transects_deepoverwash.mat');
transect_map('Shallow Collision')   = fullfile(base_data_dir, 'final_transects_shallowcollisionSC1.mat');
transect_map('Shallow Collision 2') = fullfile(base_data_dir, 'final_transects_shallowcollisionSC2.mat');
transect_map('Shallow Overwash')    = fullfile(base_data_dir, 'final_transects_shallowoverwash.mat');

% ---------------------------
% Parameter grid -- ADJUST AS NEEDED
% ---------------------------
effb_vals  = [0.0025, 0.0050];
efff_vals  = [0.0040, 0.0100];
slp_vals   = [0.35, 0.50];
slpot_vals = [0.04, 0.10];
gamma_vals = [0.45, 0.55];

% ---------------------------
% Build all parameter combinations
% ---------------------------
combo_id = 0;
combo_table = [];

for i1 = 1:numel(effb_vals)
    for i2 = 1:numel(efff_vals)
        for i3 = 1:numel(slp_vals)
            for i4 = 1:numel(slpot_vals)
                for i5 = 1:numel(gamma_vals)

                    combo_id = combo_id + 1;

                    combo_table(combo_id).combo_id = combo_id;
                    combo_table(combo_id).effb  = effb_vals(i1);
                    combo_table(combo_id).efff  = efff_vals(i2);
                    combo_table(combo_id).slp   = slp_vals(i3);
                    combo_table(combo_id).slpot = slpot_vals(i4);
                    combo_table(combo_id).gamma = gamma_vals(i5);

                end
            end
        end
    end
end

fprintf('Built %d parameter combinations.\n', numel(combo_table));

% ---------------------------
% Loop through target cases
% ---------------------------
for icase = 1:numel(target_cases)

    treatment_folder = target_cases{icase}.treatment_folder;
    wave_group       = target_cases{icase}.wave_group;
    test_id          = target_cases{icase}.test_id;
    profile_name     = target_cases{icase}.profile_name;

    fprintf('\n=====================================\n');
    fprintf('CASE %d of %d\n', icase, numel(target_cases));
    fprintf('Treatment : %s\n', treatment_folder);
    fprintf('Wave group: %s\n', wave_group);
    fprintf('Test ID   : %s\n', test_id);
    fprintf('Profile   : %s\n', profile_name);
    fprintf('=====================================\n');

    if ~isKey(transect_map, wave_group)
        warning('No transect mapping for wave group: %s', wave_group);
        continue
    end

    transect_mat = transect_map(wave_group);

    if ~isfile(transect_mat)
        warning('Transect MAT not found:\n%s', transect_mat);
        continue
    end

    wave_mat = fullfile(base_data_dir, treatment_folder, wave_group, ['Test' test_id '.mat']);

    if ~isfile(wave_mat)
        warning('Wave MAT not found:\n%s', wave_mat);
        continue
    end

    for icombo = 1:numel(combo_table)

        param_overrides = struct();
        param_overrides.combo_id = combo_table(icombo).combo_id;
        param_overrides.effb  = combo_table(icombo).effb;
        param_overrides.efff  = combo_table(icombo).efff;
        param_overrides.slp   = combo_table(icombo).slp;
        param_overrides.slpot = combo_table(icombo).slpot;
        param_overrides.gamma = combo_table(icombo).gamma;

        try
            fprintf('\n-----------------------------\n');
            fprintf('Building combo %04d / %04d\n', icombo, numel(combo_table));
            fprintf('effb  = %.4f\n', param_overrides.effb);
            fprintf('efff  = %.4f\n', param_overrides.efff);
            fprintf('slp   = %.4f\n', param_overrides.slp);
            fprintf('slpot = %.4f\n', param_overrides.slpot);
            fprintf('gamma = %.4f\n', param_overrides.gamma);

            build_single_flume_infile( ...
                transect_mat, ...
                wave_mat, ...
                profile_name, ...
                outdir, ...
                wave_group, ...
                test_id, ...
                treatment_folder, ...
                param_overrides);

        catch ME
            warning('FAILED: case=%s | %s | Test%s | combo=%04d\n%s', ...
                treatment_folder, wave_group, test_id, combo_table(icombo).combo_id, ME.message);
        end
    end
end

disp('Parameter sweep infile generation complete.');