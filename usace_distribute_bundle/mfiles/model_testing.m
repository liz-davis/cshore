clear; clc;

% =========================
% USER SETTINGS
% =========================
orig_base = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2';
new_base  = '/Users/elizabeth/cshore/flume_data/generated_infiles/shallow_collision_2_rootdepth_v3';
exe_path = '/Users/elizabeth/cshore/build/cshore_rootdepth_nouproot';

% CSHORE output files to delete before rerun
output_files = { ...
    'OBPROF', 'OBSUSL', 'OCROSS', 'OCRVOL', 'ODOC', 'ODICER', ...
    'OENERG', 'OLONGS', 'OLOVOL', 'OSETUP', 'OSWASP', 'OTIME', ...
    'WETFRONT', 'RUNUP', 'INFLOG', 'OTMP'};

% =========================
% 1. COPY DIRECTORY TREE
% =========================
if exist(new_base, 'dir')
    error('Target folder already exists:\n%s\nDelete it first or change new_base.', new_base);
end

fprintf('Copying folder tree...\n');
copyfile(orig_base, new_base);
fprintf('Done copying to:\n%s\n\n', new_base);

% =========================
% 2. FIND ALL CASE FOLDERS
% =========================
infiles = dir(fullfile(new_base, '**', 'infile'));

if isempty(infiles)
    error('No infile files found under:\n%s', new_base);
end

case_dirs = unique(string({infiles.folder}));
n_cases = numel(case_dirs);

fprintf('Found %d case folders with an infile.\n\n', n_cases);

% =========================
% 3. DELETE OLD OUTPUT FILES
% =========================
fprintf('Deleting old output files from copied tree...\n');

for i = 1:n_cases
    this_dir = case_dirs(i);

    for j = 1:numel(output_files)
        fpath = fullfile(this_dir, output_files{j});
        if exist(fpath, 'file')
            delete(fpath);
        end
    end
end

fprintf('Old outputs removed.\n\n');

% =========================
% 4. RUN CSHORE IN EACH CASE
% =========================
fprintf('Running CSHORE in each case folder...\n');

failed_cases = strings(0);
failed_msgs  = strings(0);

orig_pwd = pwd;

for i = 1:n_cases
    this_dir = case_dirs(i);
    fprintf('[%d/%d] %s\n', i, n_cases, this_dir);

    cd(this_dir);

    % Run executable and capture terminal output
    cmd = sprintf('"%s"', exe_path);
    [status, cmdout] = system(cmd);

    if status ~= 0
        fprintf('  FAILED\n');
        failed_cases(end+1) = this_dir; 
        failed_msgs(end+1)  = string(cmdout); 
    else
        fprintf('  done\n');
    end
end

cd(orig_pwd);

% =========================
% 5. SUMMARY
% =========================
fprintf('\n=========================\n');
fprintf('RUN SUMMARY\n');
fprintf('=========================\n');
fprintf('Total cases:   %d\n', n_cases);
fprintf('Failed cases:  %d\n', numel(failed_cases));

if ~isempty(failed_cases)
    fprintf('\nFailed case list:\n');
    for i = 1:numel(failed_cases)
        fprintf('\n%s\n', failed_cases(i));
        fprintf('%s\n', failed_msgs(i));
    end
else
    fprintf('\nAll runs completed successfully.\n');
end