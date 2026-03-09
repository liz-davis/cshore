function in = add_vegetation_profile_from_elevation(in)
%ADD_VEGETATION_PROFILE_FROM_ELEVATION
% Interpolate vegetation properties as a function of elevation (NAVD88)
% and populate the CSHORE input structure with spatially variable veg fields.
%
% INPUT:
%   in.x   - cross-shore coordinate (m), offshore -> onshore
%   in.zb  - bed elevation (m NAVD88)
%
% OUTPUT:
%   in updated with:
%       in.iveg
%       in.veg_Cd
%       in.veg_n
%       in.veg_dia
%       in.veg_ht
%       in.veg_rod
%
% NOTES:
%   - Stem density unit is stems/m^2
%   - Vegetation height is converted from cm to m
%   - Stem diameter is converted from mm to m
%   - Interpolation is linear in elevation
%   - Below the minimum vegetation elevation, vegetation is set to zero
%   - Above the maximum vegetation elevation, end values are held constant

    % ---------------------------
    % User-defined vegetation observations
    % ---------------------------
    elev_data = [ ...
        3.078
        5.571
        6.190
        7.348 ];

    stem_density_data = [ ...
          0
        176
         16
         48 ];              % stems / m^2

    avg_height_data_cm = [ ...
         0
        39
        50
        36 ];               % cm

    stem_diameter_data_mm = [ ...
        0
        2.6
        2.6
        2.6 ];              % mm

    % ---------------------------
    % Fixed vegetation parameters
    % ---------------------------
    vegCd = 1.0;            % bulk vegetation drag coefficient
    rod_default = 1.0;      % root depth / erosion threshold below bed surface (m)

    % ---------------------------
    % Convert units
    % ---------------------------
    avg_height_data_m = avg_height_data_cm / 100.0;
    stem_diameter_data_m = stem_diameter_data_mm / 1000.0;

    % ---------------------------
    % Turn vegetation on
    % ---------------------------
    in.iveg = 1;
    in.veg_Cd = vegCd;

    % ---------------------------
    % Interpolate vegetation properties by elevation
    % ---------------------------
    z = in.zb(:);

    % Linear interpolation.
    % 'extrap' is used temporarily, then we manually constrain values below min elevation.
    veg_n   = interp1(elev_data, stem_density_data,    z, 'linear', 'extrap');
    veg_ht  = interp1(elev_data, avg_height_data_m,    z, 'linear', 'extrap');
    veg_dia = interp1(elev_data, stem_diameter_data_m, z, 'linear', 'extrap');

    % ---------------------------
    % Physical constraints
    % ---------------------------
    % Below the lowest observed vegetation elevation: no vegetation
    below_min = z < min(elev_data);
    veg_n(below_min)   = 0;
    veg_ht(below_min)  = 0;
    veg_dia(below_min) = 0;

    % Above the highest observed vegetation elevation:
    % hold the highest observed value constant
    above_max = z > max(elev_data);
    veg_n(above_max)   = stem_density_data(end);
    veg_ht(above_max)  = avg_height_data_m(end);
    veg_dia(above_max) = stem_diameter_data_m(end);

    % Prevent negative interpolation artifacts
    veg_n   = max(veg_n, 0);
    veg_ht  = max(veg_ht, 0);
    veg_dia = max(veg_dia, 0);

    % If no stems, set all other vegetation properties to zero there too
    no_veg = veg_n <= 0;
    veg_ht(no_veg)  = 0;
    veg_dia(no_veg) = 0;

    % Root depth threshold
    veg_rod = rod_default * ones(size(z));
    veg_rod(no_veg) = 0;

    % ---------------------------
    % Save into structure
    % ---------------------------
    in.veg_n   = veg_n;
    in.veg_dia = veg_dia;
    in.veg_ht  = veg_ht;
    in.veg_rod = veg_rod;

    % ---------------------------
    % Diagnostics
    % ---------------------------
    fprintf('\n--- VEGETATION PROFILE ---\n');
    fprintf('Vegetated nodes: %d of %d\n', sum(~no_veg), numel(z));
    fprintf('Stem density range: %.2f to %.2f stems/m^2\n', min(veg_n), max(veg_n));
    fprintf('Vegetation height range: %.3f to %.3f m\n', min(veg_ht), max(veg_ht));
    fprintf('Stem diameter range: %.4f to %.4f m\n', min(veg_dia), max(veg_dia));
    fprintf('Root-depth threshold: %.3f m\n', rod_default);
end