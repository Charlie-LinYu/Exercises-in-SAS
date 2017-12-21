options ls=70 nodate nocenter;

libname A3 "Q:\Data-ReadOnly\COMP\";

%let reqvar1 = gvkey fyear indfmt consol popsrc datafmt conm scf sich compst;

%let table_1 = current_r quick_r debt_equity_r;

%let table_2 = dso dio dpo cash_circle;

%let table_3 = total_asset_to inventory_to receivable_to;

%let table_4 = interest_burden interest_coverage leverage;

%let table_5 = roa roe profit_margin;

%let table_6 = z_score o_score;

%let table_var = &table_1 &table_2 &table_3 &table_4 &table_5 &table_6;

/*read data and compute required variables.*/
data fin_data;
    set A3.Funda ;

    if indfmt='INDL' & datafmt = 'STD' & popsrc = 'D' & consol = 'C';
    if fyear = . then delete;

    array change1 _numeric_;
        do over change1;
        if change1 = . then change1 = 0;
    end;

    current_r = act / lct;
    quick_r = (che + rect) / lct;
    debt_equity_r = lt / teq;

    if gvkey = lag(gvkey) then do;
        dso = ((rect + lag(rect)) / (2 * sale))*365;
        dio = ((invt + lag(invt)) / (2 * cogs))*365;
        dpo = ((ap + lag(ap)) / (2 * cogs))*365;
        cash_circle = dio + dso - dpo;

        total_asset_to = sale / ((at + lag(at))/2);
        inventory_to = cogs / ((invt + lag(invt))/2);
        receivable_to = sale / ((rect + lag(rect))/2);
    end;

    interest_burden = (oiadp - xint) / oiadp;
    interest_coverage = oiadp / xint;
    leverage = at / teq;

    if gvkey = lag(gvkey) then do;
        roa = oiadp / ((at + lag(at))/2);
        roe = ni / ((teq + lag(teq))/2);
    end;
    profit_margin = oiadp / sale;

    z_a = (act - lct) / at;
    z_b = re / at;
    z_c = oiadp / at;
    z_d = (prcc_f * csho) / lt;
    z_e = sale / at;
    z_score = 1.2 * z_a + 1.4 * z_b + 3.3 * z_c + 0.6 * z_d + 0.99 * z_e;

    o_a = log(at);
    o_b = lt / at;
    o_c = (act - lct) / at;
    o_d = lct / act;
    o_e = ni / at;
    o_f = (pi + dp) / lt;

    if lt > at then o_g = 1;
    else o_g = 0;
    if gvkey = lag(gvkey) then do;
        if ni < 0 and lag(ni) < 0 then o_h = 1;
        else o_h = 0;
        o_i = (ni - lag(ni)) / (abs(ni) + abs(lag(ni)));
        o_score = - 1.32 - 0.407 * o_a + 6.03 * o_b - 1.43 * o_c + 0.0757 * o_d -
          2.37 * o_e - 1.83 * o_f - 1.72 * o_g + 0.285 * o_h - 0.521 * o_i;
    end;

    keep &reqvar1 &table_var;
run;

proc sort data = fin_data;
    by fyear;
run;

/*generate datasets of statistical results for use of plotting*/
proc means data = fin_data mean p50 std noprint;
    var &table_var;
    by fyear;
    output out = mean_data mean = ;
    output out = median_data p50 = ;
    output out = standard_dev_data std = ;
run;

/*use macro to import data*/
%let in_table = usrec baaffm cfsi;

%macro get_infile(name);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&name));
      %let next = %scan(&name,&k);
        proc import datafile = "P:\assignment 3\3.2\&next..csv"
    	    out = &next dbms = csv;
    	run;
    	data &next;
    	    set &next;
    	    fyear = year(date);
    	    keep fyear &next;
    	run;
    %end;
%mend;

%get_infile(&in_table);
run;

/*merge data of usrec into the main dataset.*/
data fin_data;
    merge fin_data(in=a) usrec(in=b);
    by fyear;
    if a;
run;

/*merge data of baaffm and cfsi into statistical datasets for plooting,
  table_list is the names of statistical datasets that will be used later,
  vlist is the names of reference datasets that will be merged into the statistical datasets*/
%macro get_merge(table_list, vlist);
    %local i j next_table next_var;
    %do i = 1 %to %sysfunc(countw(&table_list));
        %let next_table = %scan(&table_list,&i);
    	%do j = 1 %to %sysfunc(countw(&vlist));
            %let next_var = %scan(&vlist,&j);
    	    data &next_table;
    	        merge &next_table(in = a) &next_var(in = b);
    	        by fyear;
    	        if a;
    	    run;
    	%end;
    %end;
%mend;

%get_merge(table_list = (mean_data median_data standard_dev_data), vlist = (baaffm cfsi));
run;

ods pdf file = "P:\assignment 3\3.2\Report for Assignment3-2.pdf";
/*Get the descriptive statistics and correlation matrixes in each table and per every year,
  table_list is the name of used dataset,
  vlist is used to indicate different variables,
  end_pos is used to represent the ending position of variables in each table,
  so that it is able to get statistics per table according the excel file */
%macro get_statistics(table_list,vlist,end_pos);
    %local i text tmp;
    %let j = 1;
    %do i = 1 %to %sysfunc(countw(&end_pos));
        %let next = ;
        %do %while(&j <= %qscan(&end_pos,&i));
            %let tmp = %scan(&vlist, &j);
            %let next = &next &tmp;
            %let j = %eval(&j. + 1);
        %end;
            proc means data = &table_list n mean p25 p50 p75 std max min;
                var &next;
                by fyear;
    	        title "Descriptive Statistics of Table &i.";
            run;
            proc corr data = &table_list pearson;
                var &next;
    	        title "Correlation Matrix of Table &i.";
            run;
    %end;
%mend;
%get_statistics(table_list = fin_data, vlist = &table_var, end_pos = (3 7 10 13 16 18));
run;

/*plot the mean median and standard deviation of each variable over years
  vlist is used to indicate different variables*/
%macro get_plot(vlist);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&vlist));
        %let next = %scan(&vlist,&k);
        proc gplot data = mean_data;
            symbol i = spline v = Dot h = 1;
            title "Mean of &next. over time";
            plot &next*fyear;
        run;
        proc gplot data = median_data;
            symbol i = spline v = Dot h = 1;
            title "Median of &next. over time";
            plot &next*fyear;
        run;
        proc gplot data = standard_dev_data;
            symbol i = spline v = Dot h = 1;
            title "Standard deviation of &next. over time";
            plot &next*fyear;
        run;
    %end;
%mend;

%get_plot(vlist = &table_var);
run;

/*Compute the descriptive statistics for NBER recession = 1 and NBER recession = 0.*/
proc means data = fin_data(where=(usrec = 1)) n mean p25 p50 p75 std max min;
    var &table_var;
    title 'Descriptive statistics in recession years';
run;

proc means data = fin_data(where=(usrec = 0)) n mean p25 p50 p75 std max min;
    var &table_var;
    title 'Descriptive statistics in non-recession years';
run;

/*use macro to plot financial variables along with baaffm and cfsi
  table_list is the name of dataset,
  vlist1 is used to indicate different financial variables,
  vlist2 is used to indicate the name of reference argument (baaffm and cfsi)*/
%macro get_plot_2(vlist1,vlist2);
    %local k next;
    %do k = 1 %to %sysfunc(countw(&vlist1));
        %let next = %scan(&vlist1,&k);
        proc sgplot data = mean_data nocycleattrs;
    	    series x = fyear y = &next / datalabel lineattrs=(color=blue);
            series x = fyear y = &vlist2 / datalabel y2axis lineattrs=(color=red);
            title "Mean of &next. along with &vlist2. over years";
        run;
        proc sgplot data = median_data nocycleattrs;
            series x = fyear y = &next / datalabel lineattrs=(color=blue);
            series x = fyear y = &vlist2 / datalabel y2axis lineattrs=(color=red);
            title "Median of &next. along with &vlist2. over years";
        run;
    %end;
%mend;

%get_plot_2(vlist1 = &table_var,vlist2 = baaffm);
run;
%get_plot_2(vlist1 = &table_var,vlist2 = cfsi);
run;

ods pdf close;
