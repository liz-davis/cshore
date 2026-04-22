clear; clc;

% =========================
% USER SETTINGS
% =========================
orig_base = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2';
new_base  = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2_rootdepth_v3';

plot_differences_only = true;   % only plot cases with nonzero differences
plot_each_case = false;         
tol_zero = 1e-12;               % tolerance for "identical"

% =========================
% FIND CASES
% =========================
orig_infiles = dir(fullfile(orig_base, '**', 'infile'));

if isempty(orig_infiles)
    error('No infile files found in original tree.');
end

orig_case_dirs = string(unique({orig_infiles.folder}));
n_cases = numel(orig_case_dirs);

fprintf('Found %d original case folders.\n', n_cases);

% =========================
% PREALLOCATE RESULTS
% =========================
case_relpath   = strings(n_cases,1);
status         = strings(n_cases,1);
max_abs_diff   = nan(n_cases,1);
rmse_diff      = nan(n_cases,1);
n_time_orig    = nan(n_cases,1);
n_time_new     = nan(n_cases,1);

% =========================
% LOOP THROUGH CASES
% =========================
for i = 1:n_cases
    orig_dir = orig_case_dirs(i);
    relpath  = erase(orig_dir, orig_base);
    if startsWith(relpath, filesep)
        relpath = extractAfter(relpath, strlength(filesep));
    end

    new_dir = fullfile(new_base, relpath);

    case_relpath(i) = relpath;

    orig_obprof = fullfile(orig_dir, 'OBPROF');
    new_obprof  = fullfile(new_dir,  'OBPROF');

    fprintf('[%d/%d] %s\n', i, n_cases, relpath);

    if ~isfile(orig_obprof)
        status(i) = "missing original OBPROF";
        continue
    end

    if ~isfile(new_obprof)
        status(i) = "missing rerun OBPROF";
        continue
    end

    try
        [times1, x1, z1] = read_obprof(orig_obprof);
        [times2, x2, z2] = read_obprof(new_obprof);

        n_time_orig(i) = numel(times1);
        n_time_new(i)  = numel(times2);

        % check x grid
        if numel(x1) ~= numel(x2) || max(abs(x1 - x2)) > 1e-8
            status(i) = "x-grid mismatch";
            continue
        end

        % check number of time blocks
        if numel(times1) ~= numel(times2)
            status(i) = "time-block mismatch";
            continue
        end

        % optional time check
        if max(abs(times1 - times2)) > 1e-8
            status(i) = "time mismatch";
            continue
        end

        % compare final profile
        z1_final = z1(end,:);
        z2_final = z2(end,:);
        dz = z2_final - z1_final;

        max_abs_diff(i) = max(abs(dz));
        rmse_diff(i)    = sqrt(mean(dz.^2));

        if max_abs_diff(i) <= tol_zero
            status(i) = "identical";
        else
            status(i) = "different";
        end

        % optional plotting
        do_plot = false;
        if plot_each_case
            do_plot = true;
        elseif plot_differences_only && max_abs_diff(i) > tol_zero
            do_plot = true;
        end

        if do_plot
            figure('Name', char(relpath), 'Color', 'w');

            subplot(2,1,1)
            plot(x1, z1_final, 'LineWidth', 2); hold on
            plot(x2, z2_final, '--', 'LineWidth', 2);
            grid on
            xlabel('Cross-shore distance (m)')
            ylabel('Elevation (m)')
            title(sprintf('Final profile: %s', relpath), 'Interpreter', 'none')
            legend('Original', 'Rerun', 'Location', 'best')

            subplot(2,1,2)
            plot(x1, dz, 'LineWidth', 2);
            hold on
            yline(0, '--k');
            grid on
            xlabel('Cross-shore distance (m)')
            ylabel('\Delta z (m)')
            title(sprintf('Difference (rerun - original), max|dz| = %.3e', max_abs_diff(i)))
        end

    catch ME
        status(i) = "read error";
        fprintf('  ERROR: %s\n', ME.message);
    end
end

% =========================
% BUILD RESULTS TABLE
% =========================
T = table(case_relpath, status, n_time_orig, n_time_new, max_abs_diff, rmse_diff);

fprintf('\n=========================\n');
fprintf('COMPARISON SUMMARY\n');
fprintf('=========================\n');
disp(groupsummary(T, "status"))

% show non-identical / problematic cases
problem_idx = T.status ~= "identical";
if any(problem_idx)
    fprintf('\nCases needing attention:\n');
    disp(T(problem_idx,:))
else
    fprintf('\nAll cases are identical within tolerance %.1e\n', tol_zero);
end

% optional: save results
out_csv = fullfile(new_base, 'comparison_summary_obprof.csv');
writetable(T, out_csv);
fprintf('\nSaved summary table to:\n%s\n', out_csv);

% =========================
% HELPER FUNCTION
% =========================
function [times, x_ref, z_mat] = read_obprof(path)
    % Reads CSHORE OBPROF with repeated blocks:
    %   header:  <profile_id> <N> <time_seconds>
    %   N lines: x  z

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
                error('Unexpected end of file while reading block in %s', path);
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

        times(end+1,1) = t; 
        z_list{end+1,1} = z; 
    end

    if isempty(x_ref) || isempty(z_list)
        error('No valid profile data found in %s', path);
    end

    z_mat = cell2mat(cellfun(@(v) reshape(v,1,[]), z_list, 'UniformOutput', false));
end