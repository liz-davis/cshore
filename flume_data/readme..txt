These folders contain raw wave data from the vegetated dune overwash experiments. 
No reflection analysis/correction has been conducted on any values presented here 
and thus do not represent the metrics found in the journal paper.

Each .mat file has the following columns.

1)The channel assigment from Labview. Channel 0 was not used for any analysis.
2)The raw water level data. The only processing is the voltage has been converted to cm. 
	(Zero has no reference, please detrend (subtract mean) before performing calculations)
	(Data was taken for periods longer than the wave signals ran, see paper for exact length).
3)Strt is the point at which the first wave reaches that wave gauge.
4)S is the power spectrum
5)f is the frequencies for the power spectrum
6-22) Are various parameters used to evaluate the data immediately after each run
23) is the x location (meters) from the cutoff wall. See paper for more details. 