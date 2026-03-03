function make_infile_from_frf_10day()
%MAKE_INFILE_FROM_FRF_10DAY Build a CSHORE infile from THREDDS FRF or WIS forcing.
%
% Requirements (on MATLAB path):
%   - set_defaults()
%   - makeinfile_usace_vegfeature(in)
%   - get_hourly_forcing(t0,t1,wave_source,wave_id,wl_product, ...)
%       plus its helper functions (thredds_url, month_starts, read_thredds_*)

  % ---------------------------
  % USER SETTINGS
  % ---------------------------
  t0 = datetime(2020,09,10,0,0,0,'TimeZone','UTC');
  t1 = datetime(2020,09,25,0,0,0,'TimeZone','UTC'); % end-exclusive [t0, t1)

  % Waves: choose source and id
  %   FRF example: wave_source="frf"; wave_id="waverider-26m"
  %   WIS example: wave_source="wis"; wave_id="ST63108"; basin="Atlantic"
  wave_source = "frf";
  wave_id     = "waverider-26m";

  % If wave_source=="wis", set basin here
  basin = "Atlantic";

  % Water level product (FRF)
  wl_product = "eopNoaaTide";

  % Boundary condition options
  use_relative_wl = false;   % true for synthetic profile testing; false when using NAVD88 profile
  use_normal_incidence = true;

  % ---------------------------
  % Load defaults struct
  % ---------------------------
  in = set_defaults();

  % ---------------------------
  % Get hourly forcing timetable Tall
  % Tall has vars: Hs, Tp, Dir, wl
  % ---------------------------
  if lower(wave_source) == "wis"
      Tall = get_hourly_forcing(t0, t1, "wis", wave_id, wl_product, "basin", basin);
  else
      Tall = get_hourly_forcing(t0, t1, "frf", wave_id, wl_product);
  end

  if height(Tall) < 2
      error("Tall has %d rows. Need at least 2 hourly points to form intervals.", height(Tall));
  end

  % ---------------------------
  % Build CSHORE boundary arrays from Tall
  % ---------------------------
  % Convert FRF/WIS Hs to Hrms typically used in CSHORE:
  Hrms = Tall.Hs ./ sqrt(2);

  % Wave angle at boundary
  if use_normal_incidence
      angle_cshore = zeros(size(Hrms));
  else
      % Placeholder: implement a real transform later if needed
      angle_cshore = zeros(size(Hrms));
  end

  % Water level
  if use_relative_wl
      swl = Tall.wl - median(Tall.wl, "omitnan");
  else
      swl = Tall.wl;
  end

  % Setup at boundary (keep 0 for now)
  Wsetup = zeros(size(Hrms));

  % Time in seconds since model start (CSHORE wants seconds)
  rt = Tall.Properties.RowTimes;   % datetime vector
  tstart = rt(1);
  timebc_sec = seconds(rt - tstart);

  % ---------------------------
  % IMPORTANT: "intervals" convention (N-1)
  % Compiled CSHORE build expects NWAVE/NSURGE = number of intervals,
  % so we use the first (N-1) entries consistently.
  % ---------------------------
  Npts = height(Tall);
  Nint = Npts - 1;

  in.nwave = Nint;
  in.nsurg = Nint;

  % Important: provide Nint_1 = (Npts) records
  in.timebc_wave = timebc_sec(:)';
  in.timebc_surg = timebc_sec(:)';

  in.Tp     = Tall.Tp(:)';
  in.Hrms   = Hrms(:)';
  in.angle  = angle_cshore(:)';
  in.swlbc  = swl(:)';
  in.Wsetup = Wsetup(:)';

  % Checks
  assert(numel(in.timebc_wave) == in.nwave + 1);
  assert(numel(in.timebc_surg) == in.nsurg + 1);

  % Helpful prints
  fprintf("Tall rows: %d\n", Npts);
  fprintf("Using intervals (Nint): %d\n", Nint);
  fprintf("Tall start: %s\n", string(rt(1)));
  fprintf("Tall end:   %s\n", string(rt(end)));
  fprintf("Wave source: %s | Wave id: %s\n", wave_source, wave_id);
  if lower(wave_source) == "wis"
      fprintf("WIS basin: %s\n", basin);
  end
  fprintf("WL product: %s\n", wl_product);

  % ---------------------------
  % External elevation profile (CSV with ONE column: zb values, NAVD88)
  % x increases offshore -> onshore, 1 m spacing
  % ---------------------------
  profile_csv = "/Users/elizabeth/Downloads/output_1m_smoothed_flipped_duck.csv";

  % inputs
  dx     = 1;        % m
  z_off  = -8;       % offshore constant depth (NAVD88)
  L_flat = 100;      % length of constant-depth section (m)
  L_ramp = 120;      % length of ramp-to-measured section (m) 

  % field measurements
  zb = readmatrix(profile_csv);

  % force to a single column vector
  zb = zb(:);

  % remove non-finite (protects the NaN check + Fortran read)
  zb = zb(isfinite(zb));

  zb_meas = zb(:);    % NAVD88
  z0 = zb_meas(1);    % first measured point elevation

  % --- build offshore extension ---
  n_flat = round(L_flat/dx);
  n_ramp = round(L_ramp/dx);

  zb_flat = z_off * ones(n_flat,1);

  % linear ramp from z_off up to the first measured point elevation
  zb_ramp = linspace(z_off, z0, n_ramp+1).';
  zb_ramp = zb_ramp(1:end-1);   % drop endpoint to avoid duplicate with z0

  % --- concatenate ---
  zb = [zb_flat; zb_ramp; zb_meas];

  % x increases offshore -> onshore, starting at 0
  x  = (0:numel(zb)-1)' * dx;

  % assign to CSHORE struct
  in.dx = dx;
  in.x  = x;
  in.zb = zb;
  in.fw = 0.015 * ones(size(zb));   % 

  % quick sanity checks (helpful if something’s off)
  assert(numel(in.x) == numel(in.zb) && numel(in.x) == numel(in.fw), "Profile vectors must match length.");
  
  % ---------------------------
  % Write infile
  % ---------------------------
  makeinfile_usace_vegfeature(in);

  disp("Wrote infile using hourly mean forcing for:");
  disp([char(t0) "  to  " char(t1) " (end-exclusive)"]);
end