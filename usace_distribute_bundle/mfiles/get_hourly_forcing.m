function Tall = get_hourly_forcing(t0, t1, wave_source, wave_id, wl_product, varargin)
%GET_HOURLY_FORCING Return hourly forcing timetable Tall with Hs,Tp,Dir,wl.
%
% Tall = get_hourly_forcing(t0,t1,"frf","waverider-26m","eopNoaaTide")
% Tall = get_hourly_forcing(t0,t1,"wis","ST63108","eopNoaaTide","basin","Atlantic")

t0.TimeZone = "UTC";
t1.TimeZone = "UTC";

% waves (FRF or WIS)
Tw = read_thredds_waves(wave_source, wave_id, t0, t1, varargin{:});

% WL (FRF only, at least for now)
TWL = read_thredds_wl(wl_product, t0, t1);

% hourly averages
Tw_hr  = retime(Tw,  "hourly", "mean");
TWL_hr = retime(TWL, "hourly", "mean");

% intersection of timestamps + drop missing
Tall = synchronize(Tw_hr, TWL_hr, "intersection");
Tall = rmmissing(Tall);
end