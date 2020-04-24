# Estimating R0 by state but correcting for testing

library(tidyverse)
theme_set(theme_bw())
library(rstan)
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
library(lubridate)


# Estiamting hierarchical model for Covid in India

covid <- read_csv("https://api.covid19india.org/csv/latest/state_wise_daily.csv")
testing_rates <- read_csv("./outdata/testing_rates_state.csv") %>%
    rename(statename = state,
           state = statecode)

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

# Merging with testing rates data
covid <- covid %>%
    left_join(testing_rates, by = c("date", "state"))

# Forward fill total tested
covid <- covid %>%
    group_by(state) %>%
    arrange(date) %>%
    fill(statename, .direction = "updown") %>%
    fill(total_tested, population, testing_rate, statename) %>%
    fill(population, statename, .direction = "up") %>%
    ungroup %>%
    mutate(total_tested = replace_na(total_tested, 0))

# some testing rates are still missing causing of no date overlaps
covid <- covid %>%
    mutate(testing_rate = ifelse(is.na(testing_rate), 
                                 1 + log(1 + total_tested/population), 
                                 testing_rate))

# Specifying parameter values for stan

# remove India total and keep only confirmed cases
covid_confirmed <- covid %>%
    filter(status == "Confirmed" & state != "TT" & state != "UT")

# Deflate confirmation numbers by testing rates
covid_confirmed <- covid_confirmed %>%
    mutate(value_cumsum_defl = ifelse(value_cumsum == 0 & testing_rate == 0,
                                      0,
                                      value_cumsum/testing_rate),
           F5.value_cumsum_defl = ifelse(F5.value_cumsum == 0 & testing_rate == 0,
                                         0,
                                         F5.value_cumsum/testing_rate))

# Which states hve missing value cumsum deflated
covid_confirmed %>%
    filter(complete.cases(value_cumsum) & is.na(value_cumsum_defl)) %>% 
    group_by(state) %>% summarize()
# seems like they are the states for which we dont have testing data

# == Cleaning and Specifying parameter values for stan == #
# remove obs with NA
covid_confirmed <- covid_confirmed %>%
    drop_na(F5.value_cumsum, F5.value_cumsum)

# Make state categorical
covid_confirmed <- covid_confirmed %>%
    mutate(state = as.factor(state))

# Parameters to pass into stan
N <- nrow(covid_confirmed)
J <- length(unique(covid_confirmed$state))
K <- 2 # r coefficient and intercept
id <- c(unclass(covid_confirmed$state))
X <- cbind(rep(1, nrow(covid_confirmed)),covid_confirmed$value_cumsum)
y <- covid_confirmed$F5.value_cumsum


## Running Stan
m_hier<-stan(file="./heir_testing/covid_model.stan",
             data=list(N=N,J=J,K=K,id=id,X=X,y=y))
 
# == Storing Results == #
## Storing Coefficients with Each State
mcmc_hier<-extract(m_hier)
ind_coeff<-apply(mcmc_hier$beta,c(2,3),quantile,probs=c(0.025,0.5,0.975))


# state levels
df_ind_coeff<-tibble(LI=ind_coeff[1,,2],
                     Median=ind_coeff[2,,2],
                     HI=ind_coeff[3,,2])

df_ind_coeff$state <- rep(unique(levels(covid_confirmed$state)))


# population level
pop_extract <- apply(mcmc_hier$r,2,quantile,probs=c(0.025,0.5,0.975))
pop_lvl<-tibble(LI = pop_extract[1, 2],
                Median=pop_extract[2, 2],
                HI = pop_extract[3, 2],
                state = "Population")

# Appending
coeff_out <- bind_rows(df_ind_coeff, pop_lvl)

# Saving data
coeff_out %>%
    write_csv("./heir_testing/coeff.csv")