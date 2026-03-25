function bc = get_flume_wave_bc_from_mat(wave_mat)
%GET_FLUME_WAVE_BC_FROM_MAT
% Extract offshore boundary conditions from experimental wave-gauge mat file.
%
% IMPORTANT:
%   - Channel 0 is not used for analysis (per README)
%   - x is distance from cutoff wall, so the MOST OFFSHORE gauge is the
%     valid gauge with the LARGEST x
%   - Summary wave-height metrics in this .mat appear to already be in meters

    fprintf('\nRUNNING HELPER: %s\n', mfilename('fullpath'));

    M = load(wave_mat);

    if ~isfield(M, 'data')
        error('Expected variable "data" not found in %s', wave_mat);
    end

    D = M.data(:);
    n = numel(D);

    channel = nan(n,1);
    x       = nan(n,1);
    Tp      = nan(n,1);
    Hm0     = nan(n,1);
    Hs      = nan(n,1);

    for i = 1:n
        channel(i) = get_scalar(D(i), 'channel');
        x(i)       = get_scalar(D(i), 'x');
        Tp(i)      = get_scalar(D(i), 'Tp');
        Hm0(i)     = get_scalar(D(i), 'Hm0');
        Hs(i)      = get_scalar(D(i), 'Hs');
    end

    % Exclude channel 0 (README: not used for analysis)
    valid = channel ~= 0 & isfinite(x);

    if ~any(valid)
        error('No valid gauges found after excluding channel 0.');
    end

    % Most offshore gauge = largest x from cutoff wall
    valid_idx = find(valid);
    [~, imax_local] = max(x(valid));
    ioff = valid_idx(imax_local);

    bc.channel = channel(ioff);
    bc.x_gauge = x(ioff);

    % Use Hm0 if available, else Hs
    if isfinite(Hm0(ioff))
        bc.Hsource = 'Hm0';
        bc.Hm0 = Hm0(ioff);   % appears already in meters
    elseif isfinite(Hs(ioff))
        bc.Hsource = 'Hs';
        bc.Hm0 = Hs(ioff);    % fallback
    else
        error('No valid Hm0 or Hs at offshore gauge.');
    end

    bc.Tp = Tp(ioff);         % appears already in seconds
    bc.Hrms = bc.Hm0 / sqrt(2);

    fprintf('\n--- OFFSHORE WAVE BC DEBUG ---\n');
    fprintf('Using channel: %d\n', bc.channel);
    fprintf('Gauge location: x = %.3f m from cutoff wall\n', bc.x_gauge);
    fprintf('Height source: %s\n', bc.Hsource);
    fprintf('Hm0 = %.6f m\n', bc.Hm0);
    fprintf('Tp  = %.6f s\n', bc.Tp);
    fprintf('Hrms = %.6f m\n', bc.Hrms);
    fprintf('--------------------------------\n');
end

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

    if numel(val) > 1
        val = val(1);
    end

    v = double(val);
end