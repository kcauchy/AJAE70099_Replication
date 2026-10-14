### ==============================================================================
### PROJECT: Empirical Replication - Jung, Sesmero, & Siebert (AJAE)
### STEP 5: Matching Robustness Checks (Appendix Tables B1 & B2)
### ==============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(fixest)

### Prevent OpenMP thread deadlocks in fixest
setFixest_nthreads(1)

### ------------------------------------------------------------------------------
### 5.1 Helper Function: Data Preparation for Matched Datasets
### ------------------------------------------------------------------------------
# Each matched Excel workbook stores data on "Sheet1". This helper reads the file,
# cleans the column headers, and constructs all de-meaned ratio and distance interactions.
prep_matched_data <- function(filepath) {
  # 1. Import dataset (matched files use "Sheet1")
  df_matched <- read_excel(filepath, sheet = "Sheet1")
  
  # 2. Compute pre-treatment benchmark mean (YEAR2013 == 1)
  mean_ratio <- mean(df_matched$RATIONEARTOT[df_matched$YEAR2013 == 1], na.rm = TRUE)
  
  # 3. Clean variable names and construct spatial/intensity interactions
  df_prepped <- df_matched %>%
    rename(
      countyname         = `county name`,
      CPRICE2014SRCELEV  = `CPRICE$2014SRCELEV`,
      TOTLSTOCKDEMANDMBY = `TOTLSTOCKDEMAND (MBY)`
    ) %>%
    mutate(
      # Quadratic distance and ratio interactions
      RATIOSQNEARTREAT = YEAR2013TREAT * RATIONEARTOT * RATIONEARTOT,
      DISTNEARTREAT    = YEAR2013TREAT * NEAR_DIST_MILES,
      DISTSQNEARTREAT  = YEAR2013TREAT * NEAR_DIST_MILES * NEAR_DIST_MILES,
      
      # De-meaned treatment intensity ratios
      MEANRATIONEARTOT = ifelse(YEAR2013 == 1, mean_ratio, NA_real_),
      DMRATIONEARTOT   = RATIONEARTOT - MEANRATIONEARTOT,
      
      # Interaction terms matching author Stata logic
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
  
  return(df_prepped)
}

### Standard Model 11 Specification Formula
m11_formula <- CPRICE2014SRCELEV ~ YEAR2013 + YEAR2013TREAT + DMRATIONEARTREAT + 
  DMRATIOSQNEARTREAT + DMRATIOTOTNEARDISTTREAT + DMRATIOTOTNEARDISTSQTREAT + 
  DISTNEARTREAT + DISTSQNEARTREAT + TOTLSTOCKDEMANDMBY | ID

### ------------------------------------------------------------------------------
### 5.2 Table B1: Nearest Neighbor Matching (NNM) Robustness
### ------------------------------------------------------------------------------
# Load and prep NNM datasets (1, 2, and 4 matched controls)
df_nnm1 <- prep_matched_data("data/DID_NNM(1)_Submission.xlsx")
df_nnm2 <- prep_matched_data("data/DID_NNM(2)_Submission.xlsx")
df_nnm4 <- prep_matched_data("data/DID_NNM(4)_Submission.xlsx")

# Estimate baseline Model 11 across matched NNM samples (Clustered by ID)
m_nnm1 <- feols(m11_formula, cluster = ~ID, data = df_nnm1)
m_nnm2 <- feols(m11_formula, cluster = ~ID, data = df_nnm2)
m_nnm4 <- feols(m11_formula, cluster = ~ID, data = df_nnm4)

cat("\n==================================================================\n")
cat("  Table B1: Nearest Neighbor Matching (NNM) Robustness Estimates\n")
cat("==================================================================\n")
etable(
  m_nnm1, m_nnm2, m_nnm4,
  headers = c("NNM (1 Neighbor)", "NNM (2 Neighbors)", "NNM (4 Neighbors)"),
  order = c("YEAR2013TREAT", "DMRATIONEARTREAT", "DISTNEARTREAT"),
  se.below = TRUE
)

### ------------------------------------------------------------------------------
### 5.3 Table B2: Propensity Score Matching (PSM) Robustness
### ------------------------------------------------------------------------------
# Load and prep PSM datasets (1, 2, and 4 matched controls)
df_psm1 <- prep_matched_data("data/DID_PSM(1)_Submission.xlsx")
df_psm2 <- prep_matched_data("data/DID_PSM(2)_Submission.xlsx")
df_psm4 <- prep_matched_data("data/DID_PSM(4)_Submission.xlsx")

# Estimate baseline Model 11 across matched PSM samples (Clustered by ID)
m_psm1 <- feols(m11_formula, cluster = ~ID, data = df_psm1)
m_psm2 <- feols(m11_formula, cluster = ~ID, data = df_psm2)
m_psm4 <- feols(m11_formula, cluster = ~ID, data = df_psm4)

cat("\n==================================================================\n")
cat("  Table B2: Propensity Score Matching (PSM) Robustness Estimates\n")
cat("==================================================================\n")
etable(
  m_psm1, m_psm2, m_psm4,
  headers = c("PSM (1 Neighbor)", "PSM (2 Neighbors)", "PSM (4 Neighbors)"),
  order = c("YEAR2013TREAT", "DMRATIONEARTREAT", "DISTNEARTREAT"),
  se.below = TRUE
)