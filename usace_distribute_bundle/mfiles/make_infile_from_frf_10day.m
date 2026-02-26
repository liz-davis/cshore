function make_infile_from_frf_10day()
  % --- USER-DEFINED SETTINGS ---
  t0 = datetime(2019,11,14,0,0,0,'TimeZone','UTC');
  t1 = datetime(2019,11,21,0,0,0,'TimeZone','UTC'); % end exclusive

  % THREDDS OPeNDAP URLs (monthly files)
  waves_url = "https://chldata.erdc.dren.mil/thredds/dodsC/frf/oceanography/waves/waverider-26m/2019/FRF-ocean_waves_waverider-26m_201911.nc";
  wl_url    = "https://chldata.erdc.dren.mil/thredds/dodsC/frf/oceanography/waterlevel/eopNoaaTide/2019/FRF-ocean_waterlevel_eopNoaaTide_201911.nc";

  % --- Load defaults struct ---
  in = set_defaults();

  % --- Read WAVES ---
  % time = seconds since 1970-01-01 (Unix epoch) :contentReference[oaicite:1]{index=1}
  tw = ncread(waves_url, "time");
  Hs = ncread(waves_url, "waveHs");   % m :contentReference[oaicite:2]{index=2}
  Tp = ncread(waves_url, "waveTp");   % s :contentReference[oaicite:3]{index=3}
  Dir = ncread(waves_url, "waveMeanDirection"); % deg

  time_w = datetime(1970,1,1,0,0,0,'TimeZone','UTC') + seconds(tw);

  % Subset time window
  iw = (time_w >= t0) & (time_w < t1);
  time_w = time_w(iw);
  Hs = Hs(iw);
  Tp = Tp(iw);
  Dir = Dir(iw);

  % Convert to table for resampling
  Tw = timetable(time_w, Hs, Tp, Dir);

  % --- Read WATER LEVEL ---
  t_wl = ncread(wl_url, "time");
  time_wl = datetime(1970,1,1,0,0,0,'TimeZone','UTC') + seconds(t_wl);
  wl = ncread(wl_url, "waterLevel");
  
  % Subset WL time window (match waves)
  iwl = (time_wl >= t0) & (time_wl < t1);
  time_wl = time_wl(iwl);
  wl = wl(iwl);

  TWL = timetable(time_wl, wl);

  % --- Resample both to hourly ---
  Tw_hr  = retime(Tw,  "hourly", "mean");
  TWL_hr = retime(TWL, "hourly", "mean");

  % Synchronize on common timestamps
  Tall = synchronize(Tw_hr, TWL_hr, "intersection");
  Tall = rmmissing(Tall);

  % --- Build CSHORE boundary arrays ---
  Hrms = Tall.Hs ./ sqrt(2);
  angle_cshore = zeros(size(Hrms));
  swl_rel = Tall.wl - median(Tall.wl,"omitnan");
  Wsetup = zeros(size(Hrms));

  tstart = Tall.time_w(1);
  timebc_sec = seconds(Tall.time_w - tstart);

  % --- Use intervals convention (N-1) ---
  Npts = height(Tall);
  Nint = Npts - 1;
  idx  = 1:Nint;

  % --- Populate the in structure ---
  in.timebc_wave = timebc_sec(idx)';
  in.timebc_surg = timebc_sec(idx)';
  in.nwave = Nint;
  in.nsurg = Nint;

  in.Tp     = Tall.Tp(idx)';
  in.Hrms   = Hrms(idx)';
  in.angle  = angle_cshore(idx)';
  in.swlbc  = swl_rel(idx)';
  in.Wsetup = Wsetup(idx)';

  % confirm counts are correct
  assert(in.nwave == numel(in.timebc_wave), 'NWAVE mismatch');
  assert(in.nsurg == numel(in.timebc_surg), 'NSURGE mismatch');

  fprintf("Tall rows: %d\n", height(Tall));
  fprintf("Using intervals (Nint): %d\n", Nint);
  fprintf("Tall start: %s\n", string(Tall.time_w(1)));
  fprintf("Tall end:   %s\n", string(Tall.time_w(end)));

  % --- Write infile in the current folder ---
  makeinfile_usace_vegfeature(in);

  disp("Wrote infile using FRF 26m waves + water level for:");
  disp([char(t0) "  to  " char(t1)]);
end