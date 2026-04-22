clear; clc; close all;

% =========================================================
% USER SETTINGS
% =========================================================
orig_base  = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2';
new_base   = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2_rootdepth_v3';
flume_dir  = '/Users/elizabeth/cshore/flume_data';

cases = {
    'TestD1-B/b'
    'TestD2-B/b'
    'TestD3-B/b'
};

% must match build_single_flume_infile.m
L_WALL = 0.75;
L_TRAP = 3.00;
LANDWARD_EXTENSION = L_WALL + L_TRAP;

VOLUME_Z_THRESHOLD = 0.3;
ZOOM_LEN = 2.5;
ZOOM_LANDWARD_PAD = 0.5;

save_figs = false;
save_dir = fullfile(new_base, 'comparison_to_flume_figures');

if save_figs && ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% =========================================================
% MAIN
% =========================================================
results = struct([]);

for i = 1:numel(cases)
    relpath = cases{i};

    fprintf('\n=============================\n');
    fprintf('Processing %s\n', relpath);
    fprintf('=============================\n');

    orig_obprof = fullfile(orig_base, relpath, 'OBPROF');
    new_obprof  = fullfile(new_base,  relpath, 'OBPROF');

    if ~isfile(orig_obprof)
        warning('Missing original OBPROF: %s', orig_obprof);
        continue
    end
    if ~isfile(new_obprof)
        warning('Missing updated OBPROF: %s', new_obprof);
        continue
    end

    [wave_condition, test_id, profile_name] = parse_case_relpath(relpath);

    transect_mat = get_transect_mat_for_wave_condition(wave_condition, flume_dir);

    [times_orig, x_orig, zt_orig] = read_obprof(orig_obprof);
    [times_new,  x_new,  zt_new ] = read_obprof(new_obprof);

    if numel(x_orig) ~= numel(x_new) || max(abs(x_orig - x_new)) > 1e-8
        error('x grids do not match for %s', relpath);
    end

    x = x_orig;
    z_orig_final = zt_orig(end,:).';
    z_new_final  = zt_new(end,:).';
    z_orig_init  = zt_orig(1,:).';
    z_new_init   = zt_new(1,:).';

    [x_meas_raw, z_pre, z_post] = read_flume_transect_mat(transect_mat, profile_name, true);

    % -----------------------------------------------------
    % Vertical datum adjustment:
    % match measured PRE crest to ORIGINAL model initial crest
    % -----------------------------------------------------
    model_initial_crest = max(zt_orig(1,:));
    measured_pre_crest = max(z_pre);
    z_offset = model_initial_crest - measured_pre_crest;

    z_pre  = z_pre  + z_offset;
    z_post = z_post + z_offset;

    % -----------------------------------------------------
    % Align measured transects to end of measured section
    % -----------------------------------------------------
    x_meas_end_model = x(end) - LANDWARD_EXTENSION;

    [x_pre, dx_meas]  = align_profile_to_x_end(z_pre,  x, x_meas_end_model);
    [x_post, ~]       = align_profile_to_x_end(z_post, x, x_meas_end_model);

    % clip to model domain
    mask_pre  = (x_pre  >= x(1)) & (x_pre  <= x(end));
    mask_post = (x_post >= x(1)) & (x_post <= x(end));

    x_pre_plot  = x_pre(mask_pre);
    z_pre_plot  = z_pre(mask_pre);

    x_post_plot = x_post(mask_post);
    z_post_plot = z_post(mask_post);

    % -----------------------------------------------------
    % Metrics
    % -----------------------------------------------------
    z_orig_final = zt_orig(end,:);
    z_new_final  = zt_new(end,:);

    rmse_orig = compute_rmse_above_threshold( ...
        x, z_orig_final, z_orig_init, x_post_plot, z_post_plot, VOLUME_Z_THRESHOLD);

    rmse_new = compute_rmse_above_threshold( ...
        x, z_new_final, z_new_init, x_post_plot, z_post_plot, VOLUME_Z_THRESHOLD);

    [dV_orig, V_orig, V_meas] = compute_volume_difference_above_threshold( ...
        x, z_orig_final, x_post_plot, z_post_plot, VOLUME_Z_THRESHOLD);

    [dV_new, V_new, ~] = compute_volume_difference_above_threshold( ...
        x, z_new_final, x_post_plot, z_post_plot, VOLUME_Z_THRESHOLD);

    fprintf('Original RMSE (z > %.2f m): %.4f m\n', VOLUME_Z_THRESHOLD, rmse_orig);
    fprintf('Updated  RMSE (z > %.2f m): %.4f m\n', VOLUME_Z_THRESHOLD, rmse_new);
    fprintf('RMSE improvement (orig - new): %.4f m\n', rmse_orig - rmse_new);

    fprintf('Original ΔV (model - measured): %.4f m^3/m\n', dV_orig);
    fprintf('Updated  ΔV (model - measured): %.4f m^3/m\n', dV_new);
    fprintf('ΔV improvement toward 0: %.4f m^3/m\n', abs(dV_orig) - abs(dV_new));

    % -----------------------------------------------------
    % Zoom window
    % -----------------------------------------------------
    xmax = x_meas_end_model + ZOOM_LANDWARD_PAD;
    xmin = xmax - ZOOM_LEN;

    m_zoom = (x >= xmin) & (x <= xmax);
    x_zoom = x(m_zoom);

    z_orig_init_zoom  = zt_orig(1, m_zoom);
    z_orig_final_zoom = zt_orig(end, m_zoom);
    z_new_final_zoom  = zt_new(end, m_zoom);

    mpz = (x_pre_plot >= xmin) & (x_pre_plot <= xmax);
    x_pre_zoom = x_pre_plot(mpz);
    z_pre_zoom = z_pre_plot(mpz);

    mpostz = (x_post_plot >= xmin) & (x_post_plot <= xmax);
    x_post_zoom = x_post_plot(mpostz);
    z_post_zoom = z_post_plot(mpostz);

    % -----------------------------------------------------
    % Plot 1: zoomed profiles
    % -----------------------------------------------------
    figure('Color','w','Name', relpath, 'Position', [100 100 900 700]);

    subplot(2,1,1)
    hold on
    plot(x_zoom, z_orig_init_zoom, 'LineWidth', 1.8, 'DisplayName', 'Model initial');
    plot(x_zoom, z_orig_final_zoom, 'LineWidth', 2.0, 'DisplayName', 'Original model final');
    plot(x_zoom, z_new_final_zoom, '--', 'LineWidth', 2.0, 'DisplayName', 'Updated model final');
    plot(x_pre_zoom, z_pre_zoom, 'LineWidth', 2.0, 'DisplayName', 'Measured PRE');
    plot(x_post_zoom, z_post_zoom, 'LineWidth', 2.0, 'DisplayName', 'Measured POST');
    xline(x_meas_end_model, '--k', 'Measured transect end', 'LabelVerticalAlignment', 'bottom');

    grid on
    xlabel('Cross-shore distance (m)')
    ylabel('Elevation (m)')
    title(sprintf('%s | zoomed profile comparison', relpath), 'Interpreter', 'none')
    legend('Location', 'best')

    txt = sprintf([ ...
        'Orig RMSE: %.3f m\n' ...
        'New RMSE: %.3f m\n' ...
        'Orig \\DeltaV: %.3f m^3/m\n' ...
        'New \\DeltaV: %.3f m^3/m'], ...
        rmse_orig, rmse_new, dV_orig, dV_new);

    text(0.02, 0.98, txt, 'Units','normalized', ...
        'VerticalAlignment','top', ...
        'BackgroundColor','w', 'Margin',6);

    % -----------------------------------------------------
    % Plot 2: bed change
    % -----------------------------------------------------
    subplot(2,1,2)
    hold on
    dz_orig = zt_orig(end,:) - zt_orig(1,:);
    dz_new  = zt_new(end,:)  - zt_new(1,:);
    dz_meas = z_post_plot - z_pre_plot;

    plot(x, dz_orig, 'LineWidth', 2.0, 'DisplayName', 'Original model \Deltaz');
    plot(x, dz_new, '--', 'LineWidth', 2.0, 'DisplayName', 'Updated model \Deltaz');
    plot(x_post_plot, dz_meas, 'LineWidth', 2.0, 'DisplayName', 'Measured \Deltaz');
    xline(x_meas_end_model, '--k', 'Measured transect end', 'LabelVerticalAlignment', 'bottom');
    yline(0, '-k');

    grid on
    xlabel('Cross-shore distance (m)')
    ylabel('\Deltaz (m)')
    title('Bed change comparison')
    legend('Location', 'best')

    if save_figs
        outname = regexprep(relpath, '[\\/]', '__');
        saveas(gcf, fullfile(save_dir, [outname '_compare_to_flume.png']));
    end

    % -----------------------------------------------------
    % Store results
    % -----------------------------------------------------
    results(i).case_relpath = relpath; %#ok<SAGROW>
    results(i).rmse_orig = rmse_orig;
    results(i).rmse_new = rmse_new;
    results(i).rmse_improvement = rmse_orig - rmse_new;
    results(i).dV_orig = dV_orig;
    results(i).dV_new = dV_new;
    results(i).dV_improvement_toward_zero = abs(dV_orig) - abs(dV_new);
    results(i).max_abs_profile_change_due_to_patch = max(abs(z_new_final - z_orig_final));
    results(i).transect_mat = transect_mat;
end

% =========================================================
% SUMMARY TABLE
% =========================================================
if ~isempty(results)
    T = struct2table(results);
    disp(T)
end

% =========================================================
% FUNCTIONS
% =========================================================
function [times, x_ref, z_mat] = read_obprof(path)
    times = [];
    x_ref = [];
    z_list = {};

    fid = fopen(path, 'r');
    if fid < 0
        error('Could not open %s', path);
    end
    cleanup = onCleanup(@() fclose(fid));

    while true
        header = fgetl(fid);
        if ~ischar(header)
            break
        end
        if isempty(strtrim(header))
            continue
        end

        parts = split(strtrim(header));
        if numel(parts) < 3
            continue
        end

        n = str2double(parts{2});
        t = str2double(parts{3});

        if isnan(n) || isnan(t)
            continue
        end

        block = nan(n,2);
        for k = 1:n
            line = fgetl(fid);
            if ~ischar(line)
                error('Unexpected EOF while reading %s', path);
            end
            vals = sscanf(line, '%f');
            if numel(vals) < 2
                error('Invalid profile row in %s', path);
            end
            block(k,1) = vals(1);
            block(k,2) = vals(2);
        end

        x = block(:,1);
        z = block(:,2);

        if isempty(x_ref)
            x_ref = x;
        else
            if numel(x) ~= numel(x_ref) || max(abs(x - x_ref)) > 1e-6
                error('x grid changed between OBPROF blocks in %s', path);
            end
        end

        times(end+1,1) = t; %#ok<AGROW>
        z_list{end+1,1} = z; %#ok<AGROW>
    end

    if isempty(x_ref) || isempty(z_list)
        error('No valid profile data found in %s', path);
    end

    z_mat = cell2mat(cellfun(@(v) reshape(v,1,[]), z_list, 'UniformOutput', false));
end

function [x_meas, z_pre, z_post] = read_flume_transect_mat(mat_path, profile_name, flip_profile)
    if nargin < 3
        flip_profile = true;
    end

    M = load(mat_path);

    profile_key = lower(profile_name);

    switch profile_key
        case 'cntrl'
            key_pre = 'zmean_pre_cntrl';
            key_post = 'zmean_post_cntrl';
        case 'a'
            key_pre = 'zmean_pre_A';
            key_post = 'zmean_post_A';
        case 'ab'
            key_pre = 'zmean_pre_AB';
            key_post = 'zmean_post_AB';
        case 'b'
            key_pre = 'zmean_pre_B';
            key_post = 'zmean_post_B';
        otherwise
            error('Unrecognized profile_name: %s', profile_name);
    end

    if ~isfield(M, key_pre) || ~isfield(M, key_post)
        error('Missing %s and/or %s in %s', key_pre, key_post, mat_path);
    end

    z_pre = squeeze(M.(key_pre));
    z_post = squeeze(M.(key_post));

    if isfield(M, 'X')
        x_meas = squeeze(M.X);
    else
        x_meas = (0:numel(z_pre)-1)' * 0.005;
    end

    if flip_profile
        z_pre = flipud(z_pre(:));
        z_post = flipud(z_post(:));
    else
        z_pre = z_pre(:);
        z_post = z_post(:);
    end

    x_meas = x_meas(:);
end

function [x_profile, dx] = align_profile_to_x_end(z_profile, x_model, x_end)
    if numel(x_model) < 2
        error('Model x array too short.')
    end
    dx = median(diff(x_model));
    n = numel(z_profile);
    x_profile = x_end - (n - 1) * dx + (0:n-1)' * dx;
end

function [wave_condition, test_id, profile_name] = parse_case_relpath(relpath)
    parts = split(relpath, filesep);
    if numel(parts) ~= 2
        error('Expected relpath like TestD1-B/b, got: %s', relpath);
    end

    test_part = parts{1};
    profile_name = char(parts{2});

    dash_idx = strfind(test_part, '-');
    if isempty(dash_idx)
        error('Could not parse test/wave from %s', relpath);
    end

    test_id = char(extractBefore(test_part, dash_idx(end)));
    wave_suffix = char(extractAfter(test_part, dash_idx(end)));

    % for these cases, D -> shallow_collision_2
    if strcmpi(wave_suffix, 'B') || strcmpi(wave_suffix, 'A')
        wave_condition = 'shallow_collision_2';
    else
        wave_condition = 'shallow_collision_2';
    end
end

function mat_path = get_transect_mat_for_wave_condition(wave_condition, flume_data_dir)
    wc = lower(regexprep(wave_condition, '[^a-zA-Z0-9]', ''));

    switch wc
        case {'shallowcollision2','shallowcollisionsc2'}
            fname = 'final_transects_shallowcollisionSC2.mat';
        case {'shallowcollision','shallowcollision1','shallowcollisionsc1'}
            fname = 'final_transects_shallowcollisionSC1.mat';
        case 'shallowoverwash'
            fname = 'final_transects_shallowoverwash.mat';
        case 'deepcollision'
            fname = 'final_transects_deepcollision.mat';
        case 'deepoverwash'
            fname = 'final_transects_deepoverwash.mat';
        otherwise
            error('Unrecognized wave condition: %s', wave_condition);
    end

    mat_path = fullfile(flume_data_dir, fname);
end

function rmse = compute_rmse_above_threshold(x, z_model, z_ref_for_mask, x_meas, z_meas, z_threshold)

    % force column vectors
    x = x(:);
    z_model = z_model(:);
    z_ref_for_mask = z_ref_for_mask(:);
    x_meas = x_meas(:);
    z_meas = z_meas(:);

    overlap_mask = (x >= min(x_meas)) & (x <= max(x_meas));
    dune_mask = z_ref_for_mask > z_threshold;
    mask = overlap_mask & dune_mask;

    if sum(mask) == 0
        error('No valid overlap points above threshold.')
    end

    z_meas_interp = interp1(x_meas, z_meas, x(mask), 'linear');
    diffv = z_model(mask) - z_meas_interp;
    rmse = sqrt(mean(diffv.^2, 'omitnan'));
end


function [dV, V_model, V_measured] = compute_volume_difference_above_threshold(x, z_model, x_meas, z_meas, z_threshold)

    % force column vectors
    x = x(:);
    z_model = z_model(:);
    x_meas = x_meas(:);
    z_meas = z_meas(:);

    overlap_mask = (x >= min(x_meas)) & (x <= max(x_meas));

    if sum(overlap_mask) < 2
        error('Not enough overlap points for volume difference.')
    end

    x_overlap = x(overlap_mask);
    z_model_overlap = z_model(overlap_mask);
    z_meas_interp = interp1(x_meas, z_meas, x_overlap, 'linear');

    h_model = max(z_model_overlap - z_threshold, 0);
    h_meas  = max(z_meas_interp - z_threshold, 0);

    V_model = trapz(x_overlap, h_model);
    V_measured = trapz(x_overlap, h_meas);
    dV = V_model - V_measured;
end