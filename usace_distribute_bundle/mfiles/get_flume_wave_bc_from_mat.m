function bc = get_flume_wave_bc_from_mat(wave_mat)
%GET_FLUME_WAVE_BC_FROM_MAT
% Extract simple offshore boundary conditions from experimental wave-gauge mat file.
%
% Uses the most offshore gauge (smallest x).

    M = load(wave_mat);

    if ~isfield(M, 'data')
        error('Expected variable "data" not found in %s', wave_mat);
    end

    D = M.data;

    % struct array can come in different orientations
    D = D(:);

    n = numel(D);
    x  = nan(n,1);
    Tp = nan(n,1);
    Hm0 = nan(n,1);
    Hs = nan(n,1);

    for i = 1:n
        x(i) = D(i).x;
        if isfield(D, 'Tp');  Tp(i)  = D(i).Tp;  end
        if isfield(D, 'Hm0'); Hm0(i) = D(i).Hm0; end
        if isfield(D, 'Hs');  Hs(i)  = D(i).Hs;  end
    end

    % most offshore gauge = smallest x
    [~, ioff] = min(x);

    bc.x_gauge = x(ioff);
    bc.Tp = Tp(ioff);

    if ~isnan(Hm0(ioff))
        bc.Hm0 = Hm0(ioff);
        bc.Hrms = Hm0(ioff) / sqrt(2);
    elseif ~isnan(Hs(ioff))
        bc.Hm0 = Hs(ioff);
        bc.Hrms = Hs(ioff) / sqrt(2);
    else
        error('Could not find Hm0 or Hs in offshore gauge');
    end
end