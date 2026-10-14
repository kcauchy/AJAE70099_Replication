### ==============================================================================
### PROJECT: Empirical Replication - Jung, Sesmero, & Siebert (AJAE)
### STEP 1: Core Data Preparation
### ==============================================================================

# Load required libraries
library(readxl)
library(dplyr)
library(tidyr)
library(fixest)

# Import the main dataset 
df <- read_excel("data/DID_Submission.xlsx", sheet = "Data")

# Calculate the mean of RATIONEARTOT specifically for the pre-treatment year (YEAR2013 == 1)
mean_ratio <- mean(df$RATIONEARTOT[df$YEAR2013 == 1], na.rm = TRUE)

df <- df %>%
  # Rename columns to remove special characters so they match the authors' Stata formulas
  rename(
    CPRICE2014SRCELEV = `CPRICE$2014SRCELEV`,
    TOTLSTOCKDEMANDMBY = `TOTLSTOCKDEMAND (MBY)`
  ) %>%
  mutate(
    # Basic distance and ratio squared interactions
    RATIOSQNEARTREAT = YEAR2013TREAT * RATIONEARTOT * RATIONEARTOT,
    DISTNEARTREAT = YEAR2013TREAT * NEAR_DIST_MILES,
    DISTSQNEARTREAT = YEAR2013TREAT * NEAR_DIST_MILES * NEAR_DIST_MILES,
    
    # Generate De-meaned Ratio variables matching the Stata logic
    MEANRATIONEARTOT = ifelse(YEAR2013 == 1, mean_ratio, NA_real_),
    DMRATIONEARTOT = RATIONEARTOT - MEANRATIONEARTOT,
    
    # De-meaned treatment interactions
    DMRATIONEARTREAT = YEAR2013TREAT * DMRATIONEARTOT,
    DMRATIOSQNEARTREAT = YEAR2013TREAT * DMRATIONEARTOT * DMRATIONEARTOT,
    DMRATIOTOTNEARDISTTREAT = YEAR2013TREAT * DMRATIONEARTOT * NEAR_DIST_MILES,
    DMRATIOTOTNEARDISTSQTREAT = YEAR2013TREAT * DMRATIONEARTOT * NEAR_DIST_MILES * NEAR_DIST_MILES
  ) %>%
  mutate(
    # Replace missing generated interaction values with 0 
    across(
      c(DMRATIONEARTREAT, DMRATIOSQNEARTREAT, DMRATIOTOTNEARDISTTREAT, DMRATIOTOTNEARDISTSQTREAT), 
      ~ replace_na(.x, 0)
    )
  )

# ==============================================================================
# STEP 2: The Main Specifications (Table 3)
# ==============================================================================

# Note: The `fixest::feols` function uses the `|` operator to separate the main 
# formula from the fixed effects. The `cluster` argument replicates Stata's `vce(cluster ID)`.

# Model 1 (Pooled OLS, clustered by ID)
m1 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + TOTLSTOCKDEMANDMBY, 
            cluster = ~ID, data = df)

# Model 2 (Baseline DiD with Elevator Fixed Effects)
m2 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + TOTLSTOCKDEMANDMBY | ID, 
            cluster = ~ID, data = df)

# Model 3 (De-meaned Ratio)
m3 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
              TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 4 (De-meaned Ratio + Ratio-Distance Interaction)
m4 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
              DMRATIOTOTNEARDISTTREAT + TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 5 (De-meaned Ratio + Quadratic Ratio-Distance Interactions)
m5 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
              DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + 
              TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 6 (De-meaned Ratio + Distance Interaction)
m6 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
              DISTNEARTREAT + TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 7 (De-meaned Ratio + Quadratic Distance Interactions)
m7 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
              DISTNEARTREAT + DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID, 
            cluster = ~ID, data = df)

# Model 8 (Quadratic Distance Interactions Only)
m8 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DISTNEARTREAT + 
              DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 9 (Quadratic Distance + Ratio-Distance Interactions)
m9 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DISTNEARTREAT + 
              DISTSQNEARTREAT + DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + 
              TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 10 (De-meaned Ratio + All Spatial/Ratio Interactions)
m10 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
               DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + DISTNEARTREAT + 
               DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID, cluster = ~ID, data = df)

# Model 11 (Fully Saturated Model - Most Flexible Specification)
m11 <- feols(CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
               DMRATIOSQNEARTREAT + DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + 
               DISTNEARTREAT + DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID, 
             cluster = ~ID, data = df)

# Display results for Model 11 matching the main text finding
etable(m11)