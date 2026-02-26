function urls = build_frf_wl_urls(wl_product, t0, t1)
%BUILD_FRF_WL_URLS Build monthly FRF WL THREDDS OPeNDAP URLs spanning [t0,t1)

    if isempty(t0.TimeZone), t0.TimeZone = "UTC"; end
    if isempty(t1.TimeZone), t1.TimeZone = "UTC"; end

    y0 = year(t0); m0 = month(t0);
    y1 = year(t1 - seconds(1)); m1 = month(t1 - seconds(1)); % inclusive month cover

    % iterate months
    urls = strings(0,1);
    yy = y0; mm = m0;

    while (yy < y1) || (yy == y1 && mm <= m1)
        ystr = sprintf("%04d", yy);
        mstr = sprintf("%02d", mm);

        % Example:
        % https://.../waterlevel/eopNoaaTide/2019/FRF-ocean_waterlevel_eopNoaaTide_201911.nc
        urls(end+1,1) = "https://chldata.erdc.dren.mil/thredds/dodsC/frf/oceanography/waterlevel/" + ...
                        wl_product + "/" + ystr + "/FRF-ocean_waterlevel_" + wl_product + "_" + ystr + mstr + ".nc";

        % increment month
        mm = mm + 1;
        if mm == 13
            mm = 1;
            yy = yy + 1;
        end
    end
end