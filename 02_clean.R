# ============================================================
# 02_clean.R
# Francesco Sanna, 10 Nov 2026
# Purpose: turn SIPRI TIV data (2000-2025) into a clean edge list
# Data: SIPRI Arms Transfers Database, March 2026 release
# ============================================================

# Packages I used; tidyverse for data tools, janitor for column names

#install.packages(c("tidyverse", "janitor"))
#dir.create("data/raw", recursive = TRUE)

library(tidyverse)  
library(janitor)    


#Cleaning and preparing the Russian file

russia <- read_csv("data/raw/Supplier_Russia_import-export-values_2000-2025.csv",
                   skip = 9, skip_empty_rows = FALSE,
                   col_types = cols(.default = col_character()))
russia <- mutate(russia, from = "Russia")


#Cleaning and preparing the China file

china <- read_csv("data/raw/Supplier_China_import-export-values_2000-2025.csv",
                  skip = 9, skip_empty_rows = FALSE,
                  col_types = cols(.default = col_character()))
china <- mutate(china, from = "China")


#Cleaning and preparing the Iran file

iran <- read_csv("data/raw/Supplier_Iran_import-export-values_2000-2025.csv",
                 skip = 9, skip_empty_rows = FALSE,
                 col_types = cols(.default = col_character()))
iran <- mutate(iran, from = "Iran")


#Cleaning and preparing the North Korea file

north_korea <- read_csv("data/raw/Supplier_NorthKorea_import-export-values_2000-2025.csv",
                        skip = 9, skip_empty_rows = FALSE,
                        col_types = cols(.default = col_character()))
north_korea <- mutate(north_korea, from = "North Korea")


#Stacking the four tables into one:

raw_four <- bind_rows(china, russia, iran, north_korea)

# Tidy column names once for all four files (e.g. "2000" -> "x2000", "Recipient" -> "recipient")

raw_four <- clean_names(raw_four)

# One row per year instead of one column per year

edges_all <- pivot_longer(raw_four, cols = x2000:x2025,
                          names_to = "year", values_to = "tiv")

# Turn year and tiv from text into numbers (read as text first so R doesn't mistake empty cells for TRUE/FALSE)

edges_all <- mutate(edges_all, year = as.integer(str_remove(year, "x")))
edges_all <- mutate(edges_all, tiv = parse_number(tiv))

edges_all <- filter(edges_all, !is.na(tiv))

# Remove SIPRI's total rows

edges_all <- filter(edges_all, !str_starts(recipient, "Total"))

# Drop unknown recipients (12 TIV, 0.007% of all TIV)

edges_all <- filter(edges_all, !str_detect(recipient, "unknown"))

# Label recipients: ** = international organisation, * = non-state actor, no star = state

edges_all <- mutate(edges_all, actor_type = case_when(
  str_detect(recipient, fixed("**")) ~ "int_org",
  str_detect(recipient, fixed("*"))  ~ "non_state",
  TRUE                               ~ "state"
))

# Network names, and keep only the columns we need, in this order

edges_all <- rename(edges_all, to = recipient)
edges_all <- select(edges_all, from, to, year, tiv, actor_type)

# Clean edge list
write_csv(edges_all, "data/edges_clean.csv")


# Total imports of each of the four (denominators for dependence)

tot_russia <- read_csv("data/raw/Recipient_Russia_import-export-values_2000-2025.csv",
                       skip = 9, skip_empty_rows = FALSE,
                       col_types = cols(.default = col_character()))
tot_russia <- clean_names(tot_russia)
tot_russia <- filter(tot_russia, recipient == "Russia")

tot_china <- read_csv("data/raw/Recipient_China_import-export-values_2000-2025.csv",
                      skip = 9, skip_empty_rows = FALSE,
                      col_types = cols(.default = col_character()))
tot_china <- clean_names(tot_china)
tot_china <- filter(tot_china, recipient == "China")

tot_iran <- read_csv("data/raw/Recipient_Iran_import-export-values_2000-2025.csv",
                     skip = 9, skip_empty_rows = FALSE,
                     col_types = cols(.default = col_character()))
tot_iran <- clean_names(tot_iran)
tot_iran <- filter(tot_iran, recipient == "Iran")

tot_nk <- read_csv("data/raw/Recipient_NorthKorea_import-export-values_2000-2025.csv",
                   skip = 9, skip_empty_rows = FALSE,
                   col_types = cols(.default = col_character()))
tot_nk <- clean_names(tot_nk)
tot_nk <- filter(tot_nk, recipient == "North Korea")

#Merging 4 totals into one

totals <- bind_rows(tot_china, tot_russia, tot_iran, tot_nk)
totals <- rename(totals, country = recipient)
totals <- pivot_longer(totals, cols = x2000:x2025,
                       names_to = "year", values_to = "total_imports")
totals <- mutate(totals, year = as.integer(str_remove(year, "x")))
totals <- mutate(totals, total_imports = parse_number(total_imports))
totals <- mutate(totals, total_imports = replace_na(total_imports, 0))
totals <- select(totals, country, year, total_imports)

# Save the totals (denominators for dependence)

write_csv(totals, "data/totals_four.csv")