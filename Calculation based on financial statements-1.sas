options ls=70 nodate nocenter;

libname A3 "Q:\Data-ReadOnly\COMP\";

%let reqvar1 = gvkey fyear indfmt consol popsrc datafmt conm scf sich compst; 

/*attention, the at, dv, seq, mkvalt are special, because at should keep its absolute value to become a dominator and
dv appears both in table 2 and table 8
seq and mkvalt do not occur directly*/

%let table1_var = ch ivst rect invt aco act ppent ivaeq ivao intan ao 
dlc ap txp lco lct dltt lo txditc mib lt pstk ceq teq;

%let table2_var = dv investments change_net_work_cap internal_cash_flow fin_deficit 
net_debt_issue net_equity_issue net_external_fin;

%let table8_var = sale cogs xsga oibdp dp oiadp xint non_op_income_sp pi txt mii ib dvp cstke xido ni 
ibc dpc oth_fund_fr_op fopt recch invch apalch txach aoloch oancf
ivch siv capx sppe aqc short_invest_cha_oth ivncf
sstk prstkc dltis dltr dlcch fiao fincf exre chech fsrco fuseo wcapc;


%let table9_var = at sale book_value_debt dv investments change_net_work_cap internal_cash_flow fin_deficit
dltis dltr net_debt_issue sstk prstkc net_equity_issue net_external_fin net_asset
cash_div_r invest_r net_incr_work_cap_r inter_cash_flow_r
fin_deficit_r g_debt_issue_r net_debt_issue_r net_equity_issue_r net_exter_fin_r
cur_mat_long_debt_r change_long_debt_r long_debt_r book_leverage tangibility mkt_value_b_value_r profitablity;

%let used_year = 1971 1974 1979 1984 1988 1990 1995 1999 2002 2005 2008 2012 2015;

data fin_data;
  set A3.Funda ;

  if indfmt='INDL' & datafmt = 'STD' & popsrc = 'D' & consol = 'C';
  if scf = 1 or scf = 2 or scf = 3 or scf = 7;
  if compst ne 'AB';
  if sich < 4900 or 4999 < sich < 6000 or sich > 6999; 

  array change1 _numeric_;
    do over change1;
	if change1 = . then change1 = 0;
	end;
  if 0 < scf < 4 then investments = capx + ivch + aqc + fuseo - sppe -siv;
  if scf = 7 then investments = capx + ivch + aqc - sppe - siv - ivstch - ivaco;
  if scf = 1 then change_net_work_cap = wcapc + chech + dlcch;
  if scf = 2 or scf = 3 then change_net_work_cap = -wcapc + chech - dlcch;
  if scf = 7 then change_net_work_cap = -recch - invch - apalch - txach - aoloch + chech -fiao - dlcch;
  if 0 < scf < 4 then internal_cash_flow = ibc + xidoc + dpc + txdc + esubc + sppiv + fopo + fsrco;
  if scf = 7 then internal_cash_flow = ibc + xidoc + dpc + txdc + esubc + sppiv + fopo + exre;
  fin_deficit = dv + investments + change_net_work_cap - internal_cash_flow;
  net_debt_issue = dltis - dltr;
  net_equity_issue = sstk - prstkc;
  net_external_fin = net_debt_issue + net_equity_issue;

  non_op_income_sp = nopi + spi;
  oth_fund_fr_op = xidoc + txdc + esubc + sppiv + fopo;
  short_invest_cha_oth = ivstch + ivaco;
  keep &reqvar1 &table1_var &table2_var &table8_var at seq mkvalt;
run;

%macro get_ratio_of_at(vlist);
%local i next;
%do i = 1 %to %sysfunc(countw(&vlist));
  %let next = %scan(&vlist,&i);
  
    data fin_data;
    set fin_data;
    &next = &next / at;
    run;
%end;
%mend;

%get_ratio_of_at(&table1_var);
run;
%get_ratio_of_at(&table2_var);
run;
%get_ratio_of_at(&table8_var);
run;

data fin_data;
set fin_data;
  at = 1;
run;

data fin_data;
set fin_data;

  book_value_debt = dlc + dltt;
  net_asset = at - lct;

  if net_asset ne 0 then
  do;
    cash_div_r = dv / net_asset;
    invest_r = investments / net_asset;
    net_incr_work_cap_r = change_net_work_cap / net_asset;
    inter_cash_flow_r = internal_cash_flow / net_asset;
    fin_deficit_r = fin_deficit / net_asset;
    g_debt_issue_r = dltis / net_asset;
    net_debt_issue_r = net_debt_issue / net_asset;
    net_equity_issue_r = net_equity_issue / net_asset;
    net_exter_fin_r = net_external_fin / net_asset;
    cur_mat_long_debt_r = dlc / net_asset;
  end;
  if (at ne 0) and ((dltt + dlc + seq) ne 0) then
  do;
    change_long_debt_r = net_debt_issue / at;
    long_debt_r = dltt / at;
    book_leverage = (dltt + dlc) / (dltt + dlc + seq);
    tangibility = ppent / at;
    mkt_value_b_value_r = mkvalt / at;
    profitablity = ni/at;
  end;

  if sale > 0 then log_sale = log(sale);

keep _all_;
run;

proc sort data = fin_data;
by fyear;
run;

ods pdf file = "P:\assignment 3\Report for 0920.pdf";

proc means data = fin_data n mean p25 p50 p75 std max min;
var &table1_var;
where fyear in (&used_year);
by fyear;
title 'Descriptive statistics of table 1 in selective years';
run;

proc means data = fin_data n mean p25 p50 p75 std max min;
var &table2_var;
where fyear in (&used_year);
by fyear;
title 'Descriptive statistics of table 2 in selective years';
run;

proc means data = fin_data n mean p25 p50 p75 std max min;
var &table8_var;
where fyear in (&used_year);
by fyear;
title 'Descriptive statistics of table 8 in selective years';
run;

proc means data = fin_data n mean p25 p50 p75 std max min;
var &table9_var;
where fyear in (&used_year);
by fyear;
title 'Descriptive statistics of table 9 in selective years';
run;

/*ods pdf file = "P:\assignment 3\Correlation Matrix.pdf";*/

proc corr data = fin_data pearson;
var cash_div_r invest_r net_incr_work_cap_r inter_cash_flow_r fin_deficit_r g_debt_issue_r net_debt_issue_r 
net_equity_issue_r net_exter_fin_r book_leverage tangibility mkt_value_b_value_r log_sale profitablity;

title 'Correlation matrix of selective variables';
run;

ods pdf close;







/*keep &reqvar;*/


