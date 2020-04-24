# Building the data used to estimate the basic Heirarchical model later

# == Libraries == #
library(tidyverse)
library(lubridate)

covid <- read_csv("https://api.covid19india.org/csv/latest/state_wise_daily.csv")

# We want to reshape the dataset to long for easy analysis.
covid <- covid %>%
    pivot_longer(-c(Date, Status), names_to = "state", values_to = "value") %>%
    rename_all(tolower)

# formatting date
covid <- covid %>%
    mutate(date = dmy(date))

# calculating total number of cases per day
covid <- covid %>%
    arrange(date) %>%
    group_by(state, status) %>%
    mutate(value_cumsum = cumsum(ifelse(is.na(value), 0, value)))

# specifying outcome variable
covid <- covid %>%
    group_by(state, status) %>%
    mutate(F5.value_cumsum = lead(value_cumsum, 5, order_by = date)) %>%
    ungroup


# writing the data
covid %>% write_csv("./outdata/simple_heir_data.csv")