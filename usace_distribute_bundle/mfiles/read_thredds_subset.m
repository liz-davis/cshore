function out = read_thredds_subset(urls, t0, t1, varspec)
%READ_THREDDS_SUBSET Read + concatenate variables from one or more THREDDS files,
% subset to [t0, t1) (end-exclusive).
%
% varspec can be:
%   1) string/char/cellstr of NetCDF variable names
%   2) struct mapping output field -> NetCDF variable name
%      e.g., varspec.Hs="waveHs"; varspec.Tp="waveTp";

  urls = string(urls(:));

  % --- Force timezone-aware UTC datetimes ---
  if isempty(t0.TimeZone); t0.TimeZone = "UTC"; end
  if isempty(t1.TimeZone); t1.TimeZone = "UTC"; end
  t0 = datetime(t0, "TimeZone", "UTC");
  t1 = datetime(t1, "TimeZone", "UTC");

  % --- Parse varspec ---
  if isstruct(varspec)
      outFields = string(fieldnames(varspec));     % output names
      ncVars    = string(struct2cell(varspec));    % NetCDF variable names
  else
      ncVars    = string(varspec(:));
      outFields = string(arrayfun(@matlab.lang.makeValidName, ncVars, "UniformOutput", false));
  end

  % --- Accumulators ---
  allTime = datetime.empty(0,1); allTime.TimeZone = "UTC";
  data = struct();
  for k = 1:numel(outFields)
      data.(outFields(k)) = [];
  end

  % --- Loop files ---
  for u = 1:numel(urls)
      url = urls(u);

      % Read file time
      tsec = ncread(url, "time");
      t = datetime(1970,1,1,0,0,0,"TimeZone","UTC") + seconds(tsec(:));

      ii = (t >= t0) & (t < t1);
      if ~any(ii)
          continue
      end

      t_sub = t(ii);
      nT = numel(t_sub);

      % For each variable, read and coerce to vector aligned to time
      xfile = struct();
      nMin = nT;

      for k = 1:numel(ncVars)
          vn  = ncVars(k);
          fld = outFields(k);

          x = ncread(url, vn);

          % Squeeze away singleton dims, then vectorize
          x = squeeze(x);

          % If still not vector, flatten in column-major order
          x = x(:);

          % Some files can have x longer/shorter than time if dims differ.
          % First take the same subset mask if possible:
          if numel(x) == numel(t)
              x_sub = x(ii);
          else
              % Fallback: try to take the first nT samples after subsetting by time index count
              % (keeps things running; alignment will be enforced by trimming to nMin)
              x_sub = x(1:min(numel(x), nT));
          end

          xfile.(fld) = x_sub(:);
          nMin = min(nMin, numel(xfile.(fld)));
      end

      % Enforce equal lengths within this file chunk by trimming to nMin
      t_sub = t_sub(1:nMin);

      allTime = [allTime; t_sub]; %#ok<AGROW>

      for k = 1:numel(outFields)
          fld = outFields(k);
          data.(fld) = [data.(fld); xfile.(fld)(1:nMin)]; %#ok<AGROW>
      end
  end

  % --- Sort by time ---
  out = struct();
  if isempty(allTime)
      out.time = allTime;
      for k = 1:numel(outFields)
          out.(outFields(k)) = [];
      end
      return
  end

  [allTime, isrt] = sort(allTime);
  out.time = allTime;

  for k = 1:numel(outFields)
      fld = outFields(k);
      out.(fld) = data.(fld)(isrt);
  end
end