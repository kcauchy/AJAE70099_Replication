# ==============================================================================
# PROJECT: Empirical Replication - Jung, Sesmero, & Siebert (AJAE)
# STEP 3: Dynamic & Panel Extensions (Tables A1, C4 & Figure A1)
# ==============================================================================

# Load all required libraries
library(readxl)
library(dplyr)
library(tidyr)
library(fixest)
library(did)
library(ggplot2)

# Prevent C++ OpenMP thread deadlocks in fixest on Intel Macs
setFixest_nthreads(1)

# ==============================================================================
# 3.1 Data Preparation for Staggered Panel
# ==============================================================================
# Import the staggered panel dataset
df_panel <- read_excel("data/StaggeredDID_Submission.xlsx", sheet = "Data")

# Clean and harmonize variable names matching the Stata workflow
df_panel <- df_panel %>%
  rename(
    CPRICE2014SRCELEV = `CPRICE$2014SRCELEV`
  ) %>% 
  mutate(
    # The 'did' package requires the group variable (FIRST_TREAT) to be exactly 0 for never-treated units.
    FIRST_TREAT = replace_na(FIRST_TREAT, 0),
    
    # Ensure ID, YEAR, and FIRST_TREAT are integers to prevent obscure mapping errors
    ID = as.integer(ID),
    YEAR = as.integer(YEAR),
    FIRST_TREAT = as.integer(FIRST_TREAT)
  )

# Verify treatment cohorts and never-treated group (FIRST_TREAT == 0)
table(df_panel$FIRST_TREAT)

# ==============================================================================
# 3.2 Callaway & Sant'Anna (2021) Staggered DiD (Table A1 & Figure A1)
# ==============================================================================
# Step A: Estimate group-time average treatment effects ATT(g, t)
cs_att <- att_gt(
  yname = "CPRICE2014SRCELEV",
  tname = "YEAR",
  idname = "ID",
  gname = "FIRST_TREAT",
  data = df_panel,
  control_group = "nevertreated",
  est_method = "dr",
  clustervars = "ID",
  print_details = FALSE
)

# Step B: Aggregate ATT(g, t) into an event study (relative time)
cs_event <- aggte(
  cs_att,
  type = "dynamic",
  na.rm = TRUE
)

# Display Table A1 results in Console
cat("\n=======================================================\n")
cat(" Replicating Table A1: Callaway & Sant'Anna Event Study \n")
cat("=======================================================\n")
summary(cs_event)

# Step C: Extract Table A1 coefficients and 95% Confidence Intervals into a clean dataframe
table_a1 <- data.frame(
  Event_Time = cs_event$egt,
  Estimate   = round(cs_event$att.egt, 4),
  Std_Error  = round(cs_event$se.egt, 4),
  Lower_95CI = round(cs_event$att.egt - 1.96 * cs_event$se.egt, 4),
  Upper_95CI = round(cs_event$att.egt + 1.96 * cs_event$se.egt, 4)
)
print(table_a1)

# ==============================================================================
# 3.3 Visualizing the Event Study (Replicating Figure A1)
# ==============================================================================
# Plotting the dynamic effects using the native ggdid function layered with ggplot2
p_event <- ggdid(cs_event) +
  theme_minimal(base_size = 12) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red", alpha = 0.7) +
  labs(
    title = "Figure A1: Dynamic Price Response to First Ethanol Plant Entry",
    subtitle = "Callaway & Sant'Anna (2021) Staggered DiD Estimator (Doubly Robust)",
    x = "Years Relative to First Treatment (Event Time)",
    y = "Estimated Treatment Effect on Corn Price ($/bu)"
  ) + 
  theme(
    plot.title = element_text(face = "bold", size = 13),
    panel.grid.minor = element_blank()
  )

# Display plot in RStudio Plots pane
print(p_event)

# Save high-resolution figure to a dedicated output folder
if (!dir.exists("figures")) dir.create("figures")
ggsave("figures/Figure_A1_Event_Study.png", plot = p_event, width = 8, height = 5, dpi = 300)

# ==============================================================================
# 3.4 Full Elevator-Year Panel Regressions (Appendix Table C4)
# ==============================================================================
# Evaluates conventional panel fixed effects over all 11 years (2004-2014)
# Map these four models exactly to the authors' 4 raw specifications:

# Model C4.1: Pooled OLS (No Fixed Effects)
panel_m1 <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + USAGEEPLANTTOT_NEAR + TOTLSTOCKDEMAND, 
                  cluster = ~ID, data = df_panel)

# Model C4.2: Elevator Fixed Effects Only
panel_m2 <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + USAGEEPLANTTOT_NEAR + TOTLSTOCKDEMAND | ID, 
                  cluster = ~ID, data = df_panel)

# Model C4.3: Year Fixed Effects Only
panel_m3 <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + USAGEEPLANTTOT_NEAR + TOTLSTOCKDEMAND | YEAR, 
                  cluster = ~ID, data = df_panel)

# Model C4.4: Two-Way Fixed Effects (Elevator FE + Year FE)
panel_m4 <- feols(CPRICE2014SRCELEV ~ NEAR_DIST_MILES + USAGEEPLANTTOT_NEAR + TOTLSTOCKDEMAND | ID + YEAR, 
                  cluster = ~ID, data = df_panel)

# Display Table C4 panel results
cat("\n=======================================================\n")
cat(" Replicating Table C4: Annual Panel Fixed-Effects Models \n")
cat("=======================================================\n")
etable(panel_m1, panel_m2, panel_m3, panel_m4, 
       headers = c("Pooled OLS", "Elevator FE", "Year FE", "Both FE"),
       title = "Table C4: Annual Panel Regressions")