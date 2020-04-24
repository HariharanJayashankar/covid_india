# Estimating the Effective Reproduction Number for Covid-19 in India - By State

## Overview

This repo attempts to estimate the effective reproduction number (R) of India.

You can read the main completed writeup [here](https://htmlpreview.github.io/?https://github.com/HariharanJayashankar/covid_india/blob/master/simple_heir/estimating_model.html)(this will open an HTML preview but it is safe)

The numbers have to interpretted with some care. Only if we assume testing rates are similar across states, we can comment on whether a state with a higher R is doing worse than a state with a lower one. But not matter what, a high R is worrying. For example, most epidemiological models predict that for a disease to stop spreading R should be lower than 1. Presumeably this is when we can think of lifting lockdowns.


## Directory Structure

./code
    /analysis - contains analysis scripts
    /build - contains scripts to process and save data
./experimental - contains weird ideas
./notebooks - contains writeups
./outdata - contains processed data (from ./code/build/)
./product - contains graphs and tables (usually from ./code/analysis)
./rawdata - contains any rawdata. Used by ./code/build usually