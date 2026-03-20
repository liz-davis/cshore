function make_infile_from_flume_deepcollision()
%MAKE_INFILE_FROM_FLUME_DEEPCOLLISION
% Build a CSHORE infile for the deep-collision flume experiment.

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
    dt_bc   = 0.5;      % s, choose a simple interval
    t_final = 60;       % s, PLACEHOLDER; update to experiment duration

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
    % Load pre-transect
    % ---------------------------
    T = load(transect_mat);

    x = T.X(:);

    switch lower(profile_name)
        case 'a'
            zb = T.zmean_pre_A(:);
        case 'ab'
            zb = T.zmean_pre_AB(:);
        case 'b'
            zb = T.zmean_pre_B(:);
        case 'cntrl'
            zb = T.zmean_pre_cntrl(:);
        otherwise
            error('Unknown profile_name: %s', profile_name);
    end

    assert(numel(x)==numel(zb), 'X and zb must have same length');

    in.x  = x;
    in.zb = zb;
    in.fw = in.fric_fac * ones(size(zb));

    % ---------------------------
    % Get simple wave BC from flume mat
    % ---------------------------
    bc = get_flume_wave_bc_from_mat(wave_mat);

    % Constant BC over experiment duration
    tvec = 0:dt_bc:t_final;

    in.timebc_wave = tvec;
    in.timebc_surg = tvec;
    in.nwave = numel(tvec) - 1;
    in.nsurg = numel(tvec) - 1;

    in.Tp     = bc.Tp   * ones(size(tvec));
    in.Hrms   = bc.Hrms * ones(size(tvec));
    in.angle  = zeros(size(tvec));
    in.swlbc  = zeros(size(tvec));
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
    % Diagnostics
    % ---------------------------
    fprintf('\n--- FLUME INFILE BUILD ---\n');
    fprintf('Profile: %s\n', profile_name);
    fprintf('Nodes: %d\n', numel(in.x));
    fprintf('x range: %.3f to %.3f m\n', min(in.x), max(in.x));
    fprintf('z range: %.3f to %.3f m\n', min(in.zb), max(in.zb));
    fprintf('Tp: %.3f s\n', bc.Tp);
    fprintf('Hrms: %.3f m\n', bc.Hrms);
    fprintf('Vegetation on: %d\n', in.iveg);

    % ---------------------------
    % Write infile
    % ---------------------------
    makeinfile_usace_vegfeature(in);

    disp('Finished writing flume infile');
end