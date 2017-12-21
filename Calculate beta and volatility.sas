options ls=70 nodate nocenter;

libname A4 "Q:\Data-ReadOnly\CRSP\";

%let reqvar = permno date ret prc vol;

%let comp_var = ret prc vol;

data stock_data;
    set A4.dsf(where=(2005<=year(date)<=2014) keep = &reqvar);
    prc = abs(prc);
run;

data index_data;
    set A4.dsi(where=(2005<=year(date)<=2014) keep = date vwretd sprtrn);
run;

proc sort data = stock_data out = stock_data_sorted;
    by date;
run;

/*
generate a new dataset of the mean value of
three variables(ret prc vol) by date
*/
proc means data = stock_data_sorted mean noprint;
    output out = mean_by_date mean = ;
    by date;
    var &comp_var;
run;

/*
merge the stock data with the index data by date,
and sort by the name of stocks for regression analysis
*/
proc sql;
    create table stock_index_data as
	select *
	from stock_data, index_data
	where stock_data.date = index_data.date
	order by stock_data.permno, stock_data.date;
quit;

/*
run regression model of ret on measurement of market return(sprtrn),
output the coefficient of the independent variable as the beta
*/
proc reg data = stock_index_data outest = est(rename=(Intercept=ALPHA sprtrn=BETA)
    drop = _MODEL_ _DEPVAR_ _type_ ret) noprint;
model ret = sprtrn;
by PERMNO;
run;
quit;

/*
generate a new dataset of statistical information of each stock over the full sample period
*/
proc means data = stock_index_data noprint;
output out = mean_by_stock (drop = _type_ _freq_ VOL_StdDev) mean = std = /autoname;
by permno;
var vol ret;
run;

/*
generate a new dataset of the standard deviation of the index,
it will be used to calculate the systematic volatility
*/
proc means data = index_data noprint;
output out = std_index(drop = _type_ _freq_) std = /autoname;
var vwretd sprtrn;
run;

/*
match the value of beta to each stock
*/
proc sql;
    create table stock_camp as
	select *
	from mean_by_stock, est
	where mean_by_stock.permno = est.permno
	order by mean_by_stock.permno;
quit;

/*
add new variables of standard deviation of the market return to the dataset that
contains statistical information of stocks, in order to calculate the systematic volatility
*/
data stock_camp;
merge stock_camp(in=a) std_index(in=b);
if a;
run;

data stock_camp(drop = RET_StdDev filledone1 filledone2);
    set stock_camp;
	retain filledone1;
	retain filledone2;
	if not missing(sprtrn_StdDev) then filledone1 = sprtrn_StdDev;
	sprtrn_StdDev=filledone1;
	if not missing(vwretd_StdDev) then filledone2 = vwretd_StdDev;
	vwretd_StdDev=filledone2;
	Total_Volatility = RET_StdDev;
run;

/*
just make some adjustment of labels to make them more concise
*/
proc datasets library=work nodetails nolist;
    modify stock_camp;
	attrib _all_ lable=' ';
run;

/*
calculate the systematic volatility and the idiosyncratic volatility
*/
data stock_camp;
    set stock_camp;
	Sys_Volatility = abs(BETA) * sprtrn_StdDev;
	Idio_Volatility = Total_Volatility - Sys_Volatility;
run;

/*
generate a new dataset with quintile information regrading systematic volatility
*/
proc rank data = stock_camp groups = 5 out = quint_sys;
var Sys_Volatility;
ranks quint_sys;
run;

proc sort data = quint_sys;
by quint_sys;
run;

/*
generate a new dataset with quintile information regrading idiosyncratic volatility
*/
proc rank data = stock_camp groups = 5 out = quint_idio;
var Idio_Volatility;
ranks quint_idio;
run;

proc sort data = quint_idio;
by quint_idio;
run;


ods pdf file = "P:\assignment 4\Report for Assignment4.pdf";

/*
print out descriptive statistics requried by Question 1
*/
proc means data = stock_data n mean std p25 p50 p75 max min ;
    var &comp_var;
	title "Descriptive Statistics for the Full Period";
run;

/*
plot the daily averages of the variables required by Question 2
*/
%macro get_mean_plot(vlist);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&vlist));
        %let next = %scan(&vlist,&k);
        proc gplot data = mean_by_date;
            symbol i = spline v = dot h = 0.5;
            title "Mean of &next. over time";
            plot &next*date;
        run;
    %end;
%mend;

%get_mean_plot(&comp_var);

/*
print out information of beta, systematic volatility and idiosyncratic volatility
*/
proc print data = stock_camp;
var PERMNO VOL_Mean RET_Mean BETA Total_Volatility Sys_Volatility Idio_Volatility;
title "Beta and Volatility of Each Stock";
run;

/*
print out statistical information by the quintile of systematic volatility
*/
proc means data = quint_sys n mean std p25 p50 p75 max min;
    var RET_Mean VOL_Mean;
	by quint_sys;
	title "Characteristics of Daily Returns and Daily Volumes of Quintile Portfolios Based on Systematic Volatility";
run;

/*
print out statistical information by the quintile of idiosyncratic volatility
*/
proc means data = quint_idio n mean std p25 p50 p75 max min;
    var RET_Mean VOL_Mean;
	by quint_idio;
	title "Characteristics of Daily Returns and Daily Volumes of Quintile Portfolios Based on Idiosyncratic Volatility";
run;

ods pdf close;
