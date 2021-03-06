# Estimating hierarchical model for Covid in India

library(tidyverse)
theme_set(theme_bw())
library(rstan)
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)
library(lubridate)


# Reading in processed data
covid <- read_csv("./outdata/simple_heir_data.csv")

# Specifying parameter values for stan

# remove India total and keep only confirmed cases
covid_confirmed <- covid %>%
    filter(status == "Confirmed" & state != "TT" & state != "UT")

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
m_hier<-stan(file="./code/analysis/simple_heir.stan",
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
    write_csv("./outdata/simple_heir_coeff.csv")
