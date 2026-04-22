clear; clc;

% ---------------------------
% Paths
% ---------------------------
run_root = '/Users/elizabeth/cshore/flume_data/generated_infiles_sweep_coarse';

% Path to your CSHORE executable
cshore_exe = '/Users/elizabeth/cshore/usace_distribute_bundle/example_infiles/cshore';

if ~isfile(cshore_exe)
    error('CSHORE executable not found:\n%s', cshore_exe);
end

% ---------------------------
% Find all infile files recursively
% ---------------------------
f = dir(fullfile(run_root, '**', 'infile'));

fprintf('Found %d sweep infiles\n', numel(f));

% ---------------------------
% Loop and run
% ---------------------------
for i = 1:numel(f)

    run_dir = f(i).folder;
    infile_path = fullfile(run_dir, f(i).name);

    if ~isfile(infile_path)
        warning('Skipping (no infile): %s', run_dir);
        continue
    end

    fprintf('\n============================\n');
    fprintf('Running CSHORE in:\n%s\n', run_dir);
    fprintf('(%d of %d)\n', i, numel(f));
    fprintf('============================\n');

    olddir = pwd;
    cleanupObj = onCleanup(@() cd(olddir));
    cd(run_dir);

    cmd = sprintf('"%s"', cshore_exe);
    status = system(cmd);

    if status ~= 0
        warning('CSHORE failed in: %s', run_dir);
    else
        fprintf('Completed: %s\n', run_dir);
    end
end

disp('All sweep runs complete.');