function TWL = read_thredds_wl(wl_product, t0, t1)
%READ_THREDDS_WL Read FRF water level product and return hourly timetable-ready data
%
% wl_product examples:
%   "eopNoaaTide"  (your current one)
%   (others if you add support later)

    arguments
        wl_product (1,1) string
        t0 (1,1) datetime
        t1 (1,1) datetime
    end

    % Ensure timezone consistency
    if isempty(t0.TimeZone), t0.TimeZone = "UTC"; end
    if isempty(t1.TimeZone), t1.TimeZone = "UTC"; end

    % Build monthly URLs covering [t0,t1)
    urls = build_frf_wl_urls(wl_product, t0, t1);

    % Read time + wl from one or more monthly files
    out = read_thredds_subset(urls, t0, t1, ["time","waterLevel"]);

    % --- normalize time ---
    t = out.time;

    if isnumeric(t)
        t = datetime(1970,1,1,0,0,0,"TimeZone","UTC") + seconds(t(:));
    elseif isstring(t) || iscellstr(t)
        t = datetime(t(:), "TimeZone","UTC");
    end

    if ~isdatetime(t)
        error("read_thredds_wl:BadTimeType","out.time must be datetime. Got %s", class(t));
    end

    t = t(:);
    if isempty(t.TimeZone)
        t.TimeZone = "UTC";
    else
        t = datetime(t, "TimeZone","UTC");
    end

    wl = out.waterLevel;

    % Force wl into a column vector
    wl = wl(:);

    % --- make lengths match robustly ---
    n = min(numel(t), numel(wl));
    t  = t(1:n);
    wl = wl(1:n);

    % Drop NaT and NaN together
    good = ~isnat(t) & ~isnan(wl);
    t  = t(good);
    wl = wl(good);

    if isempty(t)
        error("read_thredds_wl:EmptySubset", ...
            "No WL records after subsetting/cleaning for [%s, %s).", string(t0), string(t1));
    end

    % Sort + unique timestamps
    [t, isrt] = sort(t);
    wl = wl(isrt);

    [t, iu] = unique(t, "stable");
    wl = wl(iu);

    % --- construct timetable (use char vector + cellstr names for compatibility) ---
    TWL = timetable(t, wl, 'VariableNames', {'wl'});
end