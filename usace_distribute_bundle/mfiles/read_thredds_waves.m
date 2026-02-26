function Tw = read_thredds_waves(source, id, t0, t1, varargin)
%READ_THREDDS_WAVES Read waves (FRF or WIS) over [t0,t1).
%
% Tw = read_thredds_waves("frf","waverider-26m",t0,t1)
% Tw = read_thredds_waves("wis","ST63108",t0,t1,"basin","Atlantic")

source = lower(string(source));
mons = month_starts(t0, t1);

switch source
    case "frf"
        urls = arrayfun(@(d) thredds_url("frf_waves", id, d), mons, "UniformOutput", false);
    case "wis"
        p = inputParser;
        addParameter(p, "basin", "Atlantic");
        parse(p, varargin{:});
        basin = p.Results.basin;
        urls = arrayfun(@(d) thredds_url("wis", id, d, "basin", basin), mons, "UniformOutput", false);
    otherwise
        error("source must be 'frf' or 'wis'");
end

urls = string(urls);

v = struct("time","time", "Hs","waveHs", "Tp","waveTp", "Dir","waveMeanDirection");
out = read_thredds_subset(urls, t0, t1, v);

% --- Force out.time to be a proper datetime column vector in UTC ---
t = out.time;

% If it came back numeric, interpret as unix seconds
if isnumeric(t)
    t = datetime(1970,1,1,0,0,0,"TimeZone","UTC") + seconds(t(:));
end

% If it came back string/cellstr, convert
if isstring(t) || iscellstr(t)
    t = datetime(t(:), "TimeZone", "UTC");
end

% Must be datetime or duration now
if ~isdatetime(t) && ~isduration(t)
    error("read_thredds_waves:BadTimeType", ...
        "out.time must be datetime/duration. Got: %s", class(t));
end

% Force vector shape
t = t(:);

% Force timezone if datetime
if isdatetime(t)
    if isempty(t.TimeZone)
        t.TimeZone = "UTC";
    else
        t = datetime(t, "TimeZone", "UTC");
    end
end

% Drop NaT rows (very common culprit)
if isdatetime(t)
    good = ~isnat(t);
else
    good = ~isnan(t);
end

t = t(good);
Hs  = out.Hs(good);
Tp  = out.Tp(good);
Dir = out.Dir(good);

% If still empty, fail cleanly
if isempty(t)
    error("read_thredds_waves:EmptySubset", ...
        "No valid wave records after subsetting/cleaning for [%s, %s).", string(t0), string(t1));
end

% Make sure lengths match
n = min([numel(t), numel(Hs), numel(Tp), numel(Dir)]);
t   = t(1:n);
Hs  = Hs(1:n);
Tp  = Tp(1:n);
Dir = Dir(1:n);

% Sort and unique timestamps (retime/synchronize behave better)
[t, isrt] = sort(t);
Hs = Hs(isrt); Tp = Tp(isrt); Dir = Dir(isrt);

[t, iu] = unique(t, "stable");
Hs = Hs(iu); Tp = Tp(iu); Dir = Dir(iu);

% Overwrite into out (optional)
out.time = t; out.Hs = Hs; out.Tp = Tp; out.Dir = Dir;

Tw = timetable(out.time, out.Hs, out.Tp, out.Dir, ...
    'VariableNames', {'Hs','Tp','Dir'});
end