function bc = get_flume_wave_bc_from_mat(wave_mat)
%GET_FLUME_WAVE_BC_FROM_MAT
% Extract offshore boundary conditions from experimental wave-gauge mat file.
% Uses the most offshore gauge (smallest x).
%
% Handles:
%   - nested / non-scalar struct fields
%   - cm -> m conversion
%   - Tp scaling issues
%
% Output:
%   bc.Tp     [s]
%   bc.Hm0    [m]
%   bc.Hrms   [m]
%   bc.x_gauge [m]

    fprintf('\nRUNNING HELPER: %s\n', mfilename('fullpath'));

    M = load(wave_mat);

    if ~isfield(M, 'data')
        error('Expected variable "data" not found in %s', wave_mat);
    end

    D = M.data(:);
    n = numel(D);

    x   = nan(n,1);
    Tp  = nan(n,1);
    Hm0 = nan(n,1);
    Hs  = nan(n,1);

    for i = 1:n
        x(i) = get_scalar(D(i), 'x');

        Tp(i)  = get_scalar(D(i), 'Tp');
        Hm0(i) = get_scalar(D(i), 'Hm0');
        Hs(i)  = get_scalar(D(i), 'Hs');
    end

    % ---------------------------
    % Find offshore gauge
    % ---------------------------
    [~, ioff] = min(x);

    bc.x_gauge = x(ioff);

    % ---------------------------
    % Extract wave height
    % ---------------------------
    if ~isnan(Hm0(ioff))
        Hraw = Hm0(ioff);
        Hlabel = 'Hm0';
    elseif ~isnan(Hs(ioff))
        Hraw = Hs(ioff);
        Hlabel = 'Hs';
    else
        error('No valid Hm0 or Hs found at offshore gauge');
    end

    % Convert cm -> m if needed
    if Hraw > 1      % likely in cm
        Hm0_m = Hraw / 100;
        unit_flag = 'cm -> m';
    else             % already in m
        Hm0_m = Hraw;
        unit_flag = 'already m';
    end

    % ---------------------------
    % Extract Tp
    % ---------------------------
    Tp_raw = Tp(ioff);

    % Fix likely scaling issue (0.369 vs 3.69)
    if Tp_raw < 1
        Tp_final = Tp_raw * 10;
        Tp_flag = 'scaled x10';
    else
        Tp_final = Tp_raw;
        Tp_flag = 'no scaling';
    end

    % ---------------------------
    % Convert to Hrms
    % ---------------------------
    Hrms = Hm0_m / sqrt(2);

    % ---------------------------
    % Output
    % ---------------------------
    bc.Tp     = Tp_final;
    bc.Hm0    = Hm0_m;
    bc.Hrms   = Hrms;

    % ---------------------------
    % DEBUG PRINTS (VERY IMPORTANT)
    % ---------------------------
    fprintf('\n--- OFFSHORE WAVE BC DEBUG ---\n');
    fprintf('Gauge location: x = %.3f m\n', bc.x_gauge);

    fprintf('\nHeight source: %s\n', Hlabel);
    fprintf('Raw value: %.6f\n', Hraw);
    fprintf('Converted: %.6f m (%s)\n', Hm0_m, unit_flag);

    fprintf('\nTp raw: %.6f\n', Tp_raw);
    fprintf('Tp final: %.6f s (%s)\n', Tp_final, Tp_flag);

    fprintf('\nDerived Hrms: %.6f m\n', Hrms);

    fprintf('--------------------------------\n');
end


% ================================
% Helper to safely extract scalar
% ================================
function v = get_scalar(S, fieldname)

    if ~isfield(S, fieldname)
        v = NaN;
        return;
    end

    val = S.(fieldname);

    if isempty(val)
        v = NaN;
        return;
    end

    val = squeeze(val);

    % If it's still not scalar, take first value
    if numel(val) > 1
        val = val(1);
    end

    v = double(val);
end