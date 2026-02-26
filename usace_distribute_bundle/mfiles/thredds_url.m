function url = thredds_url(which, id, dt, varargin)
%THREDDS_URL Build OPeNDAP URL for FRF or WIS monthly files.
%
% url = thredds_url("frf_waves","waverider-26m",dt)
% url = thredds_url("frf_wl","eopNoaaTide",dt)
% url = thredds_url("wis","ST63108",dt,"basin","Atlantic")

dt.TimeZone = "UTC";
YYYY   = datestr(dt, "yyyy");
YYYYMM = datestr(dt, "yyyymm");

which = string(which);

switch which
    case "frf_waves"
        gauge = string(id);
        url = "https://chldata.erdc.dren.mil/thredds/dodsC/frf/oceanography/waves/" + ...
              gauge + "/" + YYYY + "/FRF-ocean_waves_" + gauge + "_" + YYYYMM + ".nc";

    case "frf_wl"
        product = string(id);
        url = "https://chldata.erdc.dren.mil/thredds/dodsC/frf/oceanography/waterlevel/" + ...
              product + "/" + YYYY + "/FRF-ocean_waterlevel_" + product + "_" + YYYYMM + ".nc";

    case "wis"
        p = inputParser;
        addParameter(p, "basin", "Atlantic");
        parse(p, varargin{:});
        basin = string(p.Results.basin);
        stn   = string(id);
        url = "https://chldata.erdc.dren.mil/thredds/dodsC/wis/" + basin + "/" + ...
              stn + "/" + YYYY + "/WIS-ocean_waves_" + stn + "_" + YYYYMM + ".nc";

    otherwise
        error("Unknown dataset type: %s", which);
end
end