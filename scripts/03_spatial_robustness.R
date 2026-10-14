# ==============================================================================
# PROJECT: Empirical Replication - Jung, Sesmero, & Siebert (AJAE)
# STEP 4: Alternative Models & Spatial Inference (Appendix C)
# ==============================================================================

# Load required libraries
library(readxl)
library(dplyr)
library(tidyr)
library(fixest) 

# Prevent OpenMP thread deadlocks
setFixest_nthreads(1)

# ------------------------------------------------------------------------------
# 4.1 Data Preparation (Full Sample & Posey Exclusion Sample)
# ------------------------------------------------------------------------------

# Import the primary dataset (Renamed to df_main to avoid base R function conflicts)
df_main <- read_excel("data/DID_Submission.xlsx", sheet = "Data")

# Calculate pre-treatment mean ratio (2013 baseline where YEAR2013 == 1)
mean_ratio <- mean(df_main$RATIONEARTOT[df_main$YEAR2013 == 1], na.rm = TRUE)

df_main <- df_main %>%
  rename(
    countyname         = `county name`,
    CPRICE2014SRCELEV  = `CPRICE$2014SRCELEV`,
    TOTLSTOCKDEMANDMBY = `TOTLSTOCKDEMAND (MBY)`
  ) %>%
  mutate(
    # Quadratic and distance interactions
    RATIOSQNEARTREAT = YEAR2013TREAT * RATIONEARTOT * RATIONEARTOT,
    DISTNEARTREAT    = YEAR2013TREAT * NEAR_DIST_MILES,
    DISTSQNEARTREAT  = YEAR2013TREAT * NEAR_DIST_MILES * NEAR_DIST_MILES,
    
    # De-meaned ratio construction
    MEANRATIONEARTOT = ifelse(YEAR2013 == 1, mean_ratio, NA_real_),
    DMRATIONEARTOT   = RATIONEARTOT - MEANRATIONEARTOT,
    
    # De-meaned interactions
    DMRATIONEARTREAT          = YEAR2013TREAT * DMRATIONEARTOT,
    DMRATIOSQNEARTREAT        = YEAR2013TREAT * DMRATIONEARTOT * DMRATIONEARTOT,
    DMRATIOTOTNEARDISTTREAT   = YEAR2013TREAT * DMRATIONEARTOT * NEAR_DIST_MILES,
    DMRATIOTOTNEARDISTSQTREAT = YEAR2013TREAT * DMRATIONEARTOT * NEAR_DIST_MILES * NEAR_DIST_MILES
  ) %>%
  mutate(
    across(
      c(DMRATIONEARTREAT, DMRATIOSQNEARTREAT, DMRATIOTOTNEARDISTTREAT, DMRATIOTOTNEARDISTSQTREAT),
      ~ replace_na(.x, 0)
    )
  )

# Create the subset excluding Posey County (Using dplyr::filter to prevent conflicts)
df_no_posey <- df_main %>%
  dplyr::filter(countyname != "Posey")

# Re-run Model 11 (Baseline)
m11_formula <- CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
  DMRATIOSQNEARTREAT + DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + 
  DISTNEARTREAT + DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID

m11 <- feols(m11_formula, cluster = ~ID, data = df_main)

# ------------------------------------------------------------------------------
# 4.2 Table C2 & C3: Alternative Baseline Specifications
# ------------------------------------------------------------------------------

# Table C2: Regular OLS (No Fixed Effects) 
# FIXED: Reverted to raw NEAR_DIST_MILES to correctly match the author specification
m_ols <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + DMRATIONEARTREAT + TOTLSTOCKDEMANDMBY, 
               cluster = ~ID, data = df_main)

m_ols_no_posey <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + DMRATIONEARTREAT + TOTLSTOCKDEMANDMBY, 
                        cluster = ~ID, data = df_no_posey)

# Table C3: Regular Difference-in-Differences 
m_did <- feols(CPRICE2014SRCELEV ~ YEAR2013 + TREATMENT + YEAR2013TREAT + TOTLSTOCKDEMANDMBY, 
               cluster = ~ID, data = df_main)

m_did_no_posey <- feols(CPRICE2014SRCELEV ~ YEAR2013 + TREATMENT + YEAR2013TREAT + TOTLSTOCKDEMANDMBY, 
                        cluster = ~ID, data = df_no_posey)

cat("\n=======================================================\n")
cat(" Tables C2 & C3: Alternative Baseline Specifications \n")
cat("=======================================================\n")
etable(m_ols, m_ols_no_posey, m_did, m_did_no_posey,
       headers = c("OLS (Full)", "OLS (No Posey)", "Reg DiD (Full)", "Reg DiD (No Posey)"))

# ------------------------------------------------------------------------------
# 4.3 Table C5: Alternative Inference / Spatial Clustering 
# ------------------------------------------------------------------------------

# 1. Clustered at the County level (fip)
m11_county <- summary(m11, cluster = ~fip)

# 2. Conley Spatial Standard Errors at 80 miles 
m11_conley80 <- summary(m11, vcov = vcov_conley(lat = "latitude", lon = "longitude", cutoff = "80mi"))

# 3. Conley Spatial Standard Errors at 160 miles
m11_conley160 <- summary(m11, vcov = vcov_conley(lat = "latitude", lon = "longitude", cutoff = "160mi"))

cat("\n=======================================================\n")
cat(" Replicating Table C5: Alternative Standard Errors \n")
cat("=======================================================\n")
etable(m11, m11_county, m11_conley80, m11_conley160, 
       headers = c("ID Cluster (Orig)", "County Cluster", "Conley (80 mi)", "Conley (160 mi)"))

# ------------------------------------------------------------------------------
# 4.4 Table C6: The Posey County Exclusion 
# ------------------------------------------------------------------------------

# Re-estimate Model 11 without Posey County 
m11_no_posey <- feols(m11_formula, cluster = ~ID, data = df_no_posey)

cat("\n=======================================================\n")
cat(" Replicating Table C6: Impact Excluding Posey County \n")
cat("=======================================================\n")
etable(m11, m11_no_posey, 
       headers = c("Original (w/ Posey)", "Excluded (w/o Posey)"))