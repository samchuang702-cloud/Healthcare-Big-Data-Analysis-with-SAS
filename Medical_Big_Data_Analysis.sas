/*Section 1 Traumatic brain injury issue*/

/* Update these paths before running the analysis. */
%let enrol_path = C:\path\to\enrol;
%let ipdte_path = C:\path\to\ipdte;
%let opdte_path = C:\path\to\opdte;
%let output_path = C:\path\to\output;

libname ENROL  "&enrol_path.";
libname IPDTE  "&ipdte_path.";
libname OPDTE  "&opdte_path.";
libname Course "&output_path.";


/*Problem1-1: Identify TBI outpatient and inpatient records (PRIMARY diagnosis only: ICD9CM_1)*/
data Course.TBI_OPD_RAW;
 set OPDTE.H_NHI_OPDTE10301_10
        OPDTE.H_NHI_OPDTE10302_10
        OPDTE.H_NHI_OPDTE10303_10
        OPDTE.H_NHI_OPDTE10304_10
        OPDTE.H_NHI_OPDTE10305_10
        OPDTE.H_NHI_OPDTE10306_10
        OPDTE.H_NHI_OPDTE10307_10
        OPDTE.H_NHI_OPDTE10308_10
        OPDTE.H_NHI_OPDTE10309_10
        OPDTE.H_NHI_OPDTE10310_10
        OPDTE.H_NHI_OPDTE10311_10
        OPDTE.H_NHI_OPDTE10312_10;

    where substr(ICD9CM_1, 1, 3) in
        ('800','802','803','804','880','881','882','883','884');
run;

data Course.TBI_IPD_RAW;
    set IPDTE.H_NHI_IPDTE103;

    where substr(ICD9CM_1, 1, 3) in
        ('800','802','803','804','880','881','882','883','884');
run;

/*Problem1-1: Count visits and calculate total medical points Grouped by individual (ID)*/
proc sql;
    create table Course.TBI_OPD_SUM as
    select
        ID,
        count(*) as OPD_Visits,
        sum(T_DOT) as OPD_TotPoints
    from Course.TBI_OPD_RAW
    group by ID;

    create table Course.TBI_IPD_SUM as
    select
        ID,
        count(*) as IPD_Visits,
        sum(MED_DOT) as IPD_TotPoints
    from Course.TBI_IPD_RAW
    group by ID;
quit;
/*Problem1-2:Merge with ENROL file*/
/* Merge OPD/IPD by ID */
proc sort data=Course.TBI_OPD_SUM; by ID; run;
proc sort data=Course.TBI_IPD_SUM; by ID; run;

data Course.TBI_VISIT_SUM;
    merge Course.TBI_OPD_SUM(in=a) Course.TBI_IPD_SUM(in=b);
    by ID;
    if a or b;
if missing(OPD_Visits)  then OPD_Visits = 0;
if missing(IPD_Visits)then IPD_Visits = 0;
 if missing(OPD_TotPoints)  then OPD_TotPoints = 0;
 if missing(IPD_TotPoints) then IPD_TotPoints = 0;
run;
/* Read ENROL (gender) and keep one record per person */
data Course.ENROL_ALL;
    set ENROL.H_NHI_ENROL10301 - ENROL.H_NHI_ENROL10312;
    keep ID ID_S;
run;

proc sort data=Course.ENROL_ALL out=Course.ENROL_ONE nodupkey;
    by ID;
run;
/* Merge TBI summary with ENROL; keep TBI persons only; delete unknown gender */
proc sort data=Course.TBI_VISIT_SUM; by ID; run;
proc sort data=Course.ENROL_ONE;     by ID; run;

data Course.TBI_PERSON;
    merge Course.TBI_VISIT_SUM(in=t) Course.ENROL_ONE(in=e);
    by ID;
    if t; 

/* Problem1-3:Deleting those gender were missing */
    if missing(ID_S) or ID_S='9' then delete;
/*Problem1-5:Create “TotalMedPoint,”TBI outpatient medical points plus total TBI inpatient inpatient medical points.*/
    TotalMedPoint = OPD_TotPoints + IPD_TotPoints;
run;
/*Problem 1-4: How many TBI patients?*/
title "Problem 1-4– Number of TBI patients (after deleting unknown gender)";
proc sql;
    select count(distinct ID) as TBI_Patients
    from Course.TBI_PERSON;
quit;

/*Problem1-6:finish the table*/
/* 1) All people base: one record per ID from ENROL */
data Course.ALL_PERSON;
    set ENROL.H_NHI_ENROL10301 - ENROL.H_NHI_ENROL10312;
    keep ID ID_S;
run;

proc sort data=Course.ALL_PERSON out=Course.ALL_PERSON_UNIQUE nodupkey;
    by ID;
run;

/* (Optional) If teacher requires excluding unknown gender like before */
data Course.ALL_PERSON_UNIQUE;
    set Course.ALL_PERSON_UNIQUE;
    if missing(ID_S) or ID_S='9' then delete;
run;

/* 2) Merge ALL people with TBI stats (TBI_VISIT_SUM) */
proc sort data=Course.TBI_VISIT_SUM;        by ID; run;
proc sort data=Course.ALL_PERSON_UNIQUE;    by ID; run;

data Course.ALL_PERSON_TBI;
    merge Course.ALL_PERSON_UNIQUE(in=all)
          Course.TBI_VISIT_SUM(in=tbi);
    by ID;
    if all; /* keep ALL people */

    /* fill missing as 0: non-TBI persons will become 0 */
    if missing(OPD_Visits)    then OPD_Visits    = 0;
    if missing(IPD_Visits)    then IPD_Visits    = 0;
    if missing(OPD_TotPoints) then OPD_TotPoints = 0;
    if missing(IPD_TotPoints) then IPD_TotPoints = 0;

    TotalMedPoint = OPD_TotPoints + IPD_TotPoints;
run;
title "Problem 1-6– Finish the table (ALL patients in ENROL)";

proc tabulate data=Course.ALL_PERSON_TBI format=comma12.7;
    var OPD_Visits IPD_Visits OPD_TotPoints IPD_TotPoints TotalMedPoint;

    keylabel min='Minimum'
             max='Maximum'
             mean='Mean'
             std='Standard deviation';

    table
        (OPD_Visits    ='Outpatient visits'
         IPD_Visits    ='Inpatient visits'
         OPD_TotPoints ='Outpatient total medical points'
         IPD_TotPoints ='Inpatient total medical points'
         TotalMedPoint ='Total medical points'),
        (min max mean std);
run;

title;


/*Section2:High frequency of outpatient hospitals*/

/* Problem2: Combine OPD files (10301–10312) */
data Course.OPD_ALL;
    set OPDTE.H_NHI_OPDTE10301_10
        OPDTE.H_NHI_OPDTE10302_10
        OPDTE.H_NHI_OPDTE10303_10
        OPDTE.H_NHI_OPDTE10304_10
        OPDTE.H_NHI_OPDTE10305_10
        OPDTE.H_NHI_OPDTE10306_10
        OPDTE.H_NHI_OPDTE10307_10
        OPDTE.H_NHI_OPDTE10308_10
        OPDTE.H_NHI_OPDTE10309_10
        OPDTE.H_NHI_OPDTE10310_10
        OPDTE.H_NHI_OPDTE10311_10
        OPDTE.H_NHI_OPDTE10312_10;
    keep HOSP_ID;
run;

/*Problem2: Count outpatient frequency by hospital */
proc sql;
    create table Course.OPD_HOSP_FREQ as
    select
        HOSP_ID,
        count(*) as Outpatient_Frequency
    from Course.OPD_ALL
    group by HOSP_ID;
quit;

/* Problem2: Sort by frequency (descending) */
proc sort data=Course.OPD_HOSP_FREQ;
    by descending Outpatient_Frequency;
run;

/* Problem2: Select top 10 and create ranking */
data Course.OPD_TOP10;
    set Course.OPD_HOSP_FREQ;
    Rank = _N_;
    if Rank <= 10;
run;

/* Problem2: Print result table */
title "Problem 2– Top 10 outpatient hospitals in Taiwan";
proc print data=Course.OPD_TOP10 noobs label;
    var Rank HOSP_ID Outpatient_Frequency;
    label
        Rank = "Rank"
        HOSP_ID = "HOSP_ID"
        Outpatient_Frequency = "Outpatient frequency";
run;

title;
