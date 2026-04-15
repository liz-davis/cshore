function build_single_flume_infile(transect_mat, wave_mat, profile_name, outdir, wave_group, test_id, treatment_folder, param_overrides)
%BUILD_SINGLE_FLUME_INFILE
% Build one CSHORE infile for a specified transect MAT, wave MAT, and profile.
    
    if nargin < 8 || isempty(param_overrides)
        param_overrides = struct();
    end
   
    % flume sediment / grid
    dx  = 0.005;   % m
    d50 = 0.15;    % mm

    % vegetation properties from Bryant et al. (2019)
    veg_n_full   = 158;      % stems/m^2
    veg_ht_full  = 0.1525;   % m
    veg_rod_full = 0.1525;   % m
    veg_dia_full = 0.003175; % m

    switch lower(profile_name)
        case 'cntrl'
            use_vegetation = false;
            veg_n   = 0;
            veg_ht  = 0;
            veg_rod = 0;
            veg_dia = 0;

        case 'ab'
            use_vegetation = true;
            veg_n   = veg_n_full;
            veg_ht  = veg_ht_full;
            veg_rod = veg_rod_full;
            veg_dia = veg_dia_full;

        case 'a'
            use_vegetation = true;
            veg_n   = veg_n_full;
            veg_ht  = veg_ht_full;
            veg_rod = 0;
            veg_dia = veg_dia_full;

        case 'b'
            use_vegetation = true;
            veg_n   = 0;
            veg_ht  = 0;
            veg_rod = veg_rod_full;
            veg_dia = 0;

        otherwise
            error('Unknown profile_name: %s', profile_name);
    end

    % forcing duration
    dt_bc   = 10;     
    t_final = 1200;   

    % ---------------------------
    % Load defaults
    % ---------------------------
    in = set_defaults();

    in.dx = dx;
    in.d50 = d50;
    in.wf = vfall(in.d50,20,0);

    in.iroll = 1;
    in.iover = 1;
    in.ilab  = 0;

    % ---------------------------
    % Apply parameter overrides for sweep
    % ---------------------------
    override_fields = fieldnames(param_overrides);
    for k = 1:numel(override_fields)
        fname = override_fields{k};
        in.(fname) = param_overrides.(fname);
    end

    % ---------------------------
    % Load transect data
    % ---------------------------
    T = load(transect_mat);

    switch lower(profile_name)
        case 'a'
            fieldname = 'zmean_pre_A';
        case 'ab'
            fieldname = 'zmean_pre_AB';
        case 'b'
            fieldname = 'zmean_pre_B';
        case 'cntrl'
            fieldname = 'zmean_pre_cntrl';
        otherwise
            error('Unknown profile_name: %s', profile_name);
    end

    if ~isfield(T, fieldname)
        error('Field %s not found in %s', fieldname, transect_mat);
    end

    zb_raw = T.(fieldname)(:);

    % Measured transect is flipped so it runs offshore -> onshore
    zb_meas = flipud(zb_raw);

    % ---------------------------
    % Known flume geometry
    % ---------------------------
    L_deep   = 5.4;
    L_slope  = 19.5;
    L_flat   = 19.0;
    L_beach_total = 7.8;
    L_measured = 2.0;
    L_beach_missing = L_beach_total - L_measured;

    slope_foreshore = 1/44;

    z_join = zb_meas(1);

    dz_slope = L_slope * slope_foreshore;
    z_flat_inner = z_join - slope_foreshore * L_beach_missing;
    z_deep = z_flat_inner - dz_slope;

    x1 = (0:dx:L_deep)';
    z1 = z_deep * ones(size(x1));

    x2 = (dx:dx:L_slope)';
    z2 = z_deep + slope_foreshore * x2;

    x3 = (dx:dx:L_flat)';
    z3 = z_flat_inner * ones(size(x3));

    x4 = (dx:dx:L_beach_missing)';
    z4 = linspace(z_flat_inner, z_join, numel(x4)+1)';
    z4 = z4(2:end);

    zb_ext = [z1; z2; z3; z4];
    % zb = [zb_ext; zb_meas]; old
    % x = (0:numel(zb)-1)' * dx; old
    
    % ---------------------------
    % Landward extension: wall + sand trap
    % ---------------------------
    L_wall = 0.75;   % m, short sloping wall length (estimated..)
    L_trap = 3.0;   % m, flat sand-trap length (~11.0 m in the flume)

    z_wall_top = zb_meas(end);     % last measured point = top of wall / back edge
    wall_drop  = 0.371;            % m, wall height above flume floor from manuscript
    z_trap     = z_wall_top - wall_drop;

    % sloping wall down into trap
    x5 = (dx:dx:L_wall)';
    z5 = linspace(z_wall_top, z_trap, numel(x5)+1)';
    z5 = z5(2:end);

    % flat trap floor
    x6 = (dx:dx:L_trap)';
    z6 = z_trap * ones(size(x6));

    % full profile
    zb = [zb_ext; zb_meas; z5; z6];
    x  = (0:numel(zb)-1)' * dx;

    % index for where measured transect ends
    idx_meas_end = numel(zb_ext) + numel(zb_meas);
    x_meas_end_model = x(idx_meas_end);

    % ---------------------------
    % Vertical datum adjustment
    % ---------------------------
    z_target_crest = 0.498;
    z_current_crest = max(zb);
    z_offset = z_target_crest - z_current_crest;
    zb = zb + z_offset;

    in.x  = x;
    in.zb = zb;
    in.fw = in.fric_fac * ones(size(zb));

    assert(numel(x) == numel(zb), 'Extended x and zb must have same length');
    

    % ---------------------------
    % Wave BC
    % ---------------------------
    bc = get_flume_wave_bc_from_mat(wave_mat);

    tvec = 0:dt_bc:t_final;

    in.timebc_wave = tvec;
    in.timebc_surg = tvec;

    in.nwave = numel(tvec) - 1;
    in.nsurg = numel(tvec) - 1;

    in.Tp     = bc.Tp   * ones(size(tvec));
    in.Hrms   = bc.Hrms * ones(size(tvec));
    in.angle  = zeros(size(tvec));
    in.swlbc  = 0.35 * ones(size(tvec));
    in.Wsetup = zeros(size(tvec));

    % ---------------------------
    % Vegetation
    % ---------------------------
    if use_vegetation
        in.iveg   = 1;
        in.veg_Cd = 1.0;

        in.veg_n   = zeros(size(in.x));
        in.veg_dia = zeros(size(in.x));
        in.veg_ht  = zeros(size(in.x));
        in.veg_rod = zeros(size(in.x));

        % veg_mask = in.x >= (max(in.x) - 1.0);

        % tie vegetation to the measured dune, not estimated sand trap
        % extension
        veg_mask = in.x >= (x_meas_end_model - 1.0) & in.x <= x_meas_end_model;

        in.veg_n(veg_mask)   = veg_n;
        in.veg_dia(veg_mask) = veg_dia;
        in.veg_ht(veg_mask)  = veg_ht;
        in.veg_rod(veg_mask) = veg_rod;
    else
        in.iveg = 0;
    end

    % ---------------------------
    % Output naming
    % ---------------------------
    safe_group   = lower(strrep(wave_group, ' ', '_'));
    safe_profile = lower(profile_name);

    %run_dir = fullfile(outdir, safe_group, ['Test' test_id], safe_profile);
    safe_group   = lower(strrep(wave_group, ' ', '_'));
    safe_profile = lower(profile_name);
    
    if isfield(param_overrides, 'combo_id')
        combo_label = sprintf('combo_%04d', param_overrides.combo_id);
        run_dir = fullfile(outdir, safe_group, ['Test' test_id], safe_profile, combo_label);
    else
        run_dir = fullfile(outdir, safe_group, ['Test' test_id], safe_profile);
    end

    if ~exist(run_dir, 'dir')
        mkdir(run_dir);
    end

    outfile_path = fullfile(run_dir, 'infile');

    % Copy source files into run folder for reproducibility
    wave_copy = fullfile(run_dir, 'wave.mat');
    transect_copy = fullfile(run_dir, 'transect.mat');

    if ~exist(wave_copy, 'file')
        copyfile(wave_mat, wave_copy);
    end

    if ~exist(transect_copy, 'file')
        copyfile(transect_mat, transect_copy);
    end

    info_file = fullfile(run_dir, 'run_info.txt');

    fid = fopen(info_file, 'w');

    fprintf(fid, '--- CSHORE RUN METADATA ---\n\n');
    fprintf(fid, 'Timestamp: %s\n\n', datestr(now));

    fprintf(fid, 'Treatment folder: %s\n', treatment_folder);
    fprintf(fid, 'Wave group: %s\n', wave_group);
    fprintf(fid, 'Test ID: %s\n', test_id);
    fprintf(fid, 'Profile: %s\n\n', profile_name);

    fprintf(fid, 'Wave file (original):\n%s\n\n', wave_mat);
    fprintf(fid, 'Transect file (original):\n%s\n\n', transect_mat);

    fprintf(fid, 'Copied wave file:\n%s\n', wave_copy);
    fprintf(fid, 'Copied transect file:\n%s\n', transect_copy);

    fclose(fid);

    meta.wave_mat        = wave_mat;
    meta.transect_mat    = transect_mat;
    meta.wave_group      = wave_group;
    meta.test_id         = test_id;
    meta.profile_name    = profile_name;
    meta.treatment       = treatment_folder;
    meta.timestamp       = datetime('now');

    meta.param_overrides = param_overrides;

    if isfield(in, 'effb');  meta.effb  = in.effb;  end
    if isfield(in, 'efff');  meta.efff  = in.efff;  end
    if isfield(in, 'slp');   meta.slp   = in.slp;   end
    if isfield(in, 'slpot'); meta.slpot = in.slpot; end
    if isfield(in, 'gamma'); meta.gamma = in.gamma; end
    
    save(fullfile(run_dir, 'run_metadata.mat'), '-struct', 'meta');

    % ---------------------------
    % Write infile using temporary working directory
    % ---------------------------
    temp_run_dir = fullfile(outdir, 'temp_build');
    if ~exist(temp_run_dir, 'dir')
        mkdir(temp_run_dir);
    end

    olddir = pwd;
    cleanupObj = onCleanup(@() cd(olddir)); 
    cd(temp_run_dir);

    if exist('infile', 'file') == 2
        delete('infile');
    end

    makeinfile_usace_vegfeature(in);

    if ~exist('infile', 'file')
        error('makeinfile_usace_vegfeature did not create infile');
    end

    if exist(outfile_path, 'file') == 2
        delete(outfile_path);
    end

    [status, msg, msgID] = movefile('infile', outfile_path);

    if ~status
        error('movefile failed.\nOutput: %s\nMessage: %s\nID: %s', ...
            outfile_path, msg, msgID);
    end

    fprintf('Wrote: %s\n', outfile_path);
end