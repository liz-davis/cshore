function make_infile_from_flume_deepcollision()
%MAKE_INFILE_FROM_FLUME_DEEPCOLLISION
% Build a CSHORE infile for the deep-collision flume experiment.
%
% Requirements
%   - set_defaults()
%   - makeinfile_usace_vegfeature(in)
%   - get_flume_wave_bc_from_mat()

    % ---------------------------
    % User settings
    % ---------------------------
    transect_mat = '/Users/elizabeth/cshore/usace_distribute_bundle/mfiles/final_transects_deepcollision.mat';
    wave_mat     = '/Users/elizabeth/cshore/usace_distribute_bundle/mfiles/TestC1-AB.mat';

    profile_name = 'AB';   % options: 'A', 'AB', 'B', 'cntrl'

    % flume sediment / grid
    dx  = 0.005;   % m
    d50 = 0.15;    % mm

    % vegetation properties from Bryant et al. (2019)
    use_vegetation = true;
    veg_n   = 158;      % stems/m^2
    veg_ht  = 0.1525;   % m
    veg_rod = 0.1525;   % m
    veg_dia = 0.003175; % m

    % forcing duration
    dt_bc   = 10;       % s
    t_final = 1200;     % s, based on paper

    % ---------------------------
    % Load defaults
    % ---------------------------
    in = set_defaults();

    % overwrite grid/sediment settings
    in.dx = dx;
    in.d50 = d50;
    in.wf = vfall(in.d50,20,0);

    % flume-style setup
    in.iroll = 1;
    in.iover = 1;
    in.ilab  = 0;

    % ---------------------------
    % Load pre-transect and extend to full flume profile
    % ---------------------------
    T = load(transect_mat);

    switch lower(profile_name)
        case 'a'
            zb_raw = T.zmean_pre_A(:);
        case 'ab'
            zb_raw = T.zmean_pre_AB(:);
        case 'b'
            zb_raw = T.zmean_pre_B(:);
        case 'cntrl'
            zb_raw = T.zmean_pre_cntrl(:);
        otherwise
            error('Unknown profile_name: %s', profile_name);
    end

    % Measured transect is flipped so it runs offshore -> onshore
    zb_meas = flipud(zb_raw);

    % Rebuild x for measured section only
    x_meas = (0:numel(zb_meas)-1)' * dx;

    % ---------------------------
    % Known flume geometry (offshore -> onshore)
    % ---------------------------
    L_deep   = 5.4;         % m, deep flat zone near paddle
    L_slope  = 19.5;        % m, 1:44 slope
    L_flat   = 19.0;        % m, flat zone landward of slope
    L_beach_total = 7.8;    % m
    L_measured = 2.0;       % m
    L_beach_missing = L_beach_total - L_measured;   % m, missing beach/dune section before measured transect = 5.8 m

    slope_foreshore = 1/44;   % m/m

    % Offshore-most measured elevation (where extension joins measured data)
    z_join = zb_meas(1);

    % Build offshore geometry
    % Choose deep-zone elevation so the 19.5 m slope rises by L_slope/44
    dz_slope = L_slope * slope_foreshore;
    z_flat_inner = z_join - slope_foreshore * L_beach_missing;   % elevation at end of 19 m flat / start of missing beach ramp
    z_deep = z_flat_inner - dz_slope;                            % deep flat elevation

    % Segment 1: deep flat
    x1 = (0:dx:L_deep)';
    z1 = z_deep * ones(size(x1));

    % Segment 2: 1:44 slope upward
    x2 = (dx:dx:L_slope)';   % omit duplicate join point
    z2 = z_deep + slope_foreshore * x2;

    % Segment 3: 19 m flat
    x3 = (dx:dx:L_flat)';
    z3 = z_flat_inner * ones(size(x3));

    % Segment 4: missing beach ramp up to measured profile
    x4 = (dx:dx:L_beach_missing)';
    z4 = linspace(z_flat_inner, z_join, numel(x4)+1)';
    z4 = z4(2:end);   % omit duplicate first point

    % Concatenate offshore extension
    zb_ext = [z1; z2; z3; z4];

    % Full profile
    zb = [zb_ext; zb_meas];

    % Rebuild x from scratch so it starts at 0 and increases onshore
    x = (0:numel(zb)-1)' * dx;

    % ---------------------------
    % Vertical datum adjustment
    % Match dune crest to paper value: 49.8 cm above flume floor
    % ---------------------------
    z_target_crest = 0.498;      % m
    z_current_crest = max(zb);   % current crest elevation
    z_offset = z_target_crest - z_current_crest;

    zb = zb + z_offset;

    % Assign final flume profile into CSHORE input structure
    in.x  = x;
    in.zb = zb;
    in.fw = in.fric_fac * ones(size(zb));

    figure
    plot(x, zb, 'k-', 'LineWidth', 1.5); hold on
    plot(x(end-numel(zb_meas)+1:end), zb_meas, 'r-', 'LineWidth', 1.5)
    xlabel('Cross-shore distance x (m)', 'FontWeight','bold')
    ylabel('Elevation z (m)', 'FontWeight','bold')
    title('Extended Flume Profile', 'FontWeight','bold')
    legend('Full extended profile', 'Measured 2 m segment', 'Location', 'best')
    grid on

    assert(numel(x) == numel(zb), 'Extended x and zb must have same length');

    % ---------------------------
    % Get simple wave BC from flume mat
    % ---------------------------
    bc = get_flume_wave_bc_from_mat(wave_mat);

    % Constant BC over 1200 s burst
    tvec = 0:dt_bc:t_final;

    in.timebc_wave = tvec;
    in.timebc_surg = tvec;

    % Keep current working convention:
    in.nwave = numel(tvec) - 1;
    in.nsurg = numel(tvec) - 1;

    in.Tp     = bc.Tp   * ones(size(tvec));
    in.Hrms   = bc.Hrms * ones(size(tvec));
    in.angle  = zeros(size(tvec));
    in.swlbc  = 0.35 * ones(size(tvec));    % from Bryant et al. 2019
    in.Wsetup = zeros(size(tvec));

    % ---------------------------
    % Vegetation
    % ---------------------------
    if use_vegetation
        in.iveg   = 1;
        in.veg_Cd = 1.0;

        % initialize vegetation arrays with zeros everywhere
        in.veg_n   = zeros(size(in.x));
        in.veg_dia = zeros(size(in.x));
        in.veg_ht  = zeros(size(in.x));
        in.veg_rod = zeros(size(in.x));

       % vegetation occupies the last 1 m of the profile (closest to dune)
       veg_mask = in.x >= (max(in.x) - 1.0);

       % assign uniform vegetation values within that 1 m zone
       in.veg_n(veg_mask)   = veg_n;
       in.veg_dia(veg_mask) = veg_dia;
       in.veg_ht(veg_mask)  = veg_ht;
       in.veg_rod(veg_mask) = veg_rod;

       fprintf('Vegetated zone: x >= %.3f m\n', max(in.x) - 1.0);
       fprintf('Vegetated nodes: %d of %d\n', sum(veg_mask), numel(in.x));
    else
       in.iveg = 0;
    end

    % ---------------------------
    % Checks
    % ---------------------------
    assert(numel(in.timebc_wave) == in.nwave + 1, 'NWAVE timing mismatch');
    assert(numel(in.timebc_surg) == in.nsurg + 1, 'NSURGE timing mismatch');
    
    % ---------------------------
    % Diagnostics
    % ---------------------------
    fprintf('\n--- FLUME INFILE BUILD ---\n');
    fprintf('Profile: %s\n', profile_name);
    fprintf('Nodes: %d\n', numel(in.x));
    fprintf('x range: %.3f to %.3f m\n', min(in.x), max(in.x));
    fprintf('z range: %.3f to %.3f m\n', min(in.zb), max(in.zb));
    fprintf('Boundary dt: %.1f s\n', dt_bc);
    fprintf('Boundary duration: %.1f s\n', t_final);
    fprintf('Number of BC records: %d\n', numel(tvec));
    fprintf('NWAVE: %d   NSURGE: %d\n', in.nwave, in.nsurg);
    fprintf('Offshore gauge x: %.3f m\n', bc.x_gauge);
    fprintf('Tp: %.3f s\n', bc.Tp);
    fprintf('Hrms: %.3f m\n', bc.Hrms);
    fprintf('Vegetation on: %d\n', in.iveg);
    if use_vegetation
        fprintf('Vegetated zone starts at x >= %.3f m\n', max(in.x) - 1.0);
        fprintf('Vegetated nodes: %d of %d\n', sum(veg_mask), numel(in.x));
    end


    % ---------------------------
    % Write infile
    % ---------------------------

    if exist('infile','file')
        delete('infile');       % remove old infile, causing problems
    end

    makeinfile_usace_vegfeature(in);

    disp('Finished writing flume infile');
end