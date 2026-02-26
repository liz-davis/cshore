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
  t0 = datetime(2019,11,14,0,0,0,'TimeZone','UTC');
  t1 = datetime(2019,11,21,0,0,0,'TimeZone','UTC'); % end-exclusive [t0, t1)

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
  use_relative_wl = true;   % true for synthetic profile testing; false when using NAVD88 profile
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
      % Placeholder: you can implement a real transform later if needed
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
  idx  = 1:Nint;

  % Populate struct
  in.timebc_wave = timebc_sec(idx)';  % row vector
  in.timebc_surg = timebc_sec(idx)';  % row vector
  in.nwave = Nint;
  in.nsurg = Nint;

  in.Tp     = Tall.Tp(idx)';          % row vector
  in.Hrms   = Hrms(idx)';             % row vector
  in.angle  = angle_cshore(idx)';     % row vector
  in.swlbc  = swl(idx)';              % row vector
  in.Wsetup = Wsetup(idx)';           % row vector

  % Sanity checks
  assert(in.nwave == numel(in.timebc_wave), "NWAVE mismatch: nwave=%d, numel(timebc_wave)=%d", in.nwave, numel(in.timebc_wave));
  assert(in.nsurg == numel(in.timebc_surg), "NSURGE mismatch: nsurg=%d, numel(timebc_surg)=%d", in.nsurg, numel(in.timebc_surg));
  assert(all(diff(in.timebc_wave) > 0), "timebc_wave is not strictly increasing.");

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
  % Write infile
  % ---------------------------
  makeinfile_usace_vegfeature(in);

  disp("Wrote infile using hourly mean forcing for:");
  disp([char(t0) "  to  " char(t1) " (end-exclusive)"]);
end