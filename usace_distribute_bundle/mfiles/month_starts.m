function months = month_starts(t0, t1)
%MONTH_STARTS Month-start datetimes that intersect [t0, t1) (end-exclusive)

t0.TimeZone = "UTC";
t1.TimeZone = "UTC";

m0 = dateshift(t0, "start", "month");
m1 = dateshift(t1 - seconds(1), "start", "month");  % end-exclusive

months = (m0 : calmonths(1) : m1).';
end