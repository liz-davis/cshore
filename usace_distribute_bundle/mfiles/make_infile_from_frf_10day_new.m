function make_infile_from_frf_10day()
%MAKE_INFILE_FROM_FRF_10DAY Build a CSHORE infile from THREDDS FRF or WIS forcing.
%
% Requirements (on MATLAB path):
%   - set_defaults()
%   - makeinfile_usace_vegfeature(in)
%   - get_hourly_forcing(t0,t1,wave_source,wave_id,wl_product, ...)
%       plus its helper functions (thredds_url, month_starts, read_thredds_*)
%   - add_vegetation_profile_from_elevation()

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

  % Setup at boundary
  Wsetup = 0.2 * Hrms;

  % Time in seconds since model start (CSHORE wants seconds)
  rt = Tall.Properties.RowTimes;   % datetime vector
  tstart = rt(1);
  timebc_sec = seconds(rt - tstart);

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
  % Quick diagnostics: forcing ranges
  % ---------------------------
  fprintf('\n--- WAVE FORCING ---\n')
  fprintf('Tall.Hs  min: %.2f m   max: %.2f m\n', min(Tall.Hs), max(Tall.Hs))
  fprintf('in.Hrms  min: %.2f m   max: %.2f m\n', min(in.Hrms), max(in.Hrms))

  fprintf('\n--- WATER LEVEL FORCING ---\n')
  fprintf('Tall.wl  min: %.2f m   max: %.2f m\n', min(Tall.wl), max(Tall.wl))
  fprintf('in.swlbc min: %.2f m   max: %.2f m\n', min(in.swlbc), max(in.swlbc))

  % ---------------------------
  % External elevation profile (CSV with ONE column: zb values, NAVD88)
  % x increases offshore -> onshore, 1 m spacing
  % ---------------------------
  profile_csv = "/Users/elizabeth/Downloads/output_1m_smoothed_flipped_duck_teddy.csv";

  % inputs
  dx     = 1;        % m
  z_off  = -8;       % offshore constant depth (NAVD88)
  L_flat = 100;      % length of constant-depth section (m)
  slope_off = 0.01;  % offshore slope (m/m) from z_off up to first measured point 

  % field measurements
  zb_meas = readmatrix(profile_csv);
  zb_meas = zb_meas(:);
  zb_meas = zb_meas(isfinite(zb_meas));

  if numel(zb_meas) < 2
      error("Measured profile in %s has <2 finite points.", profile_csv);
  end

  z0 = zb_meas(1);  % first measured elevation (offshore-most measured point)

  if z0 <= z_off
      warning("First measured point z0=%.3f is <= z_off=%.3f. Offshore slope segment will be skipped.", z0, z_off);
      n_flat = round(L_flat/dx);
      zb_flat = z_off * ones(n_flat,1);
      zb = [zb_flat; zb_meas];
  else
      % --- flat section ---
      n_flat = round(L_flat/dx);
      zb_flat = z_off * ones(n_flat,1);

      % --- 0.01 slope section up to z0 ---
      L_slope = (z0 - z_off) / slope_off;      % meters needed to rise from z_off to z0
      n_slope = ceil(L_slope / dx);            % number of dx steps (not counting the join point)

      x_slope = (0:n_slope)' * dx;             % includes endpoint
      zb_slope = z_off + slope_off * x_slope;  % perfect slope
      zb_slope(end) = z0;                      % force exact match at join

      % drop the endpoint so we don't duplicate z0 with the first measured point
      zb_slope = zb_slope(1:end-1);

      % --- concatenate ---
      zb = [zb_flat; zb_slope; zb_meas];
  end

  % x increases offshore -> onshore, starting at 0
  x  = (0:numel(zb)-1)' * dx;

  % assign to CSHORE struct
  in.dx = dx;
  in.x  = x;
  in.zb = zb;
  in.fw = 0.015 * ones(size(zb));

  assert(numel(in.x) == numel(in.zb) && numel(in.x) == numel(in.fw), ...
      "Profile vectors must match length.");

  % ---------------------------
  % External vegetation builder
  % ---------------------------
  in = add_vegetation_profile_from_elevation(in);
  
  % ---------------------------
  % Write infile
  % ---------------------------
  makeinfile_usace_vegfeature(in);

  disp("Wrote infile using hourly mean forcing for:");
  disp([char(t0) "  to  " char(t1) " (end-exclusive)"]);
end