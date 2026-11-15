# ============================================================
# 03_analysis.R
# Francesco Sanna, 15 Nov 2026
# Purpose: major arms transfers among China, Russia, Iran and North Korea,
#          2000-2025 (SIPRI TIV). Network metrics by period, asymmetry,
#          import dependence, export partners, robustness checks and plots.
# Input:  data/edges_clean.csv, data/totals_four.csv (made by 02_clean.R)
# Output: CSV tables and PNG charts in output/
# ============================================================

#install.packages("igraph")
#install.packages("ggraph")

library(tidyverse)
library(igraph)
library(ggraph)

# Section A: data among the four ----

edges  <- read_csv("data/edges_clean.csv")
totals <- read_csv("data/totals_four.csv")

# Only the trade among the four
four <- c("China", "Russia", "Iran", "North Korea")
edges_four <- filter(edges, from %in% four, to %in% four)

# Section B: annual series ----

# Year by year: how many edges, and amount of TIV
annual <- group_by(edges_four, year)
annual <- summarise(annual, n_ties = n(), tiv_total = sum(tiv))

# Density: share of the 12 possible edges that exist each year

annual <- mutate(annual, density = n_ties / 12)

# Section C: periods and network metrics ----

# Three periods, set from theory before looking at the data: Crimea (2014), full-scale invasion (2022).
# Deliveries lag decisions, so breaks are approximate. Section G checks this: moving both breaks
# two years earlier (G1) gives the same edges; volumes shift, so the annual series is also shown.

edges_four <- mutate(edges_four, period = case_when(
  year <= 2013 ~ "2000-2013",
  year <= 2021 ~ "2014-2021",
  TRUE         ~ "2022-2025"
))

# One row per edge per period, with total TIV

period_edges <- group_by(edges_four, period, from, to)
period_edges <- summarise(period_edges, tiv_total = sum(tiv), .groups = "drop")

# Periods have different lengths, so compare TIV per year
period_edges <- mutate(period_edges, n_years = case_when(
  period == "2000-2013" ~ 14,
  period == "2014-2021" ~ 8,
  TRUE                  ~ 4
))
period_edges <- mutate(period_edges, tiv_per_year = tiv_total / n_years)

# One network per period; a state with no edges still counts

nodes <- tibble(name = four)
p1 <- filter(period_edges, period == "2000-2013")
p1 <- select(p1, from, to, tiv_per_year)
g1 <- graph_from_data_frame(p1, directed = TRUE, vertices = nodes)

p2 <- filter(period_edges, period == "2014-2021")
p2 <- select(p2, from, to, tiv_per_year)
g2 <- graph_from_data_frame(p2, directed = TRUE, vertices = nodes)

p3 <- filter(period_edges, period == "2022-2025")
p3 <- select(p3, from, to, tiv_per_year)
g3 <- graph_from_data_frame(p3, directed = TRUE, vertices = nodes)

#Note: reciprocity just points at the existence of two-way ties, not whether they are equal

period_metrics <- tibble(
  period      = c("2000-2013", "2014-2021", "2022-2025"),
  n_edges     = c(ecount(g1), ecount(g2), ecount(g3)),
  density     = c(edge_density(g1), edge_density(g2), edge_density(g3)),
  reciprocity = c(reciprocity(g1), reciprocity(g2), reciprocity(g3))
)
  
# Section D: asymmetry ----

# Asymmetry: for each edge A -> B, look up the reverse edge B -> A

reverse   <- select(period_edges, period, from = to, to = from, tiv_back = tiv_per_year)
asymmetry <- left_join(period_edges, reverse, by = c("period", "from", "to"))
asymmetry <- mutate(asymmetry, tiv_back = replace_na(tiv_back, 0))
asymmetry <- mutate(asymmetry, share_out = tiv_per_year / (tiv_per_year + tiv_back))

# Section E: import dependence ----

# Dependence: total imports of each state per period

totals <- mutate(totals, period = case_when(
  year <= 2013 ~ "2000-2013",
  year <= 2021 ~ "2014-2021",
  TRUE         ~ "2022-2025"
))
totals_period <- group_by(totals, country, period)
totals_period <- summarise(totals_period, total_imports = sum(total_imports), .groups = "drop")

dependence <- left_join(period_edges, totals_period, by = c("to" = "country", "period"))
dependence <- mutate(dependence, share_of_imports = tiv_total / total_imports)

# dir.create("output")
# Save results

write_csv(annual,         "output/annual.csv")
write_csv(period_metrics, "output/period_metrics.csv")
write_csv(asymmetry,      "output/asymmetry.csv")
write_csv(dependence,     "output/dependence.csv")

# Section F: export partners (all recipients) ----

# Export partners: number of different recipient states per supplier and period
partners <- filter(edges, actor_type == "state")
partners <- mutate(partners, period = case_when(
  year <= 2013 ~ "2000-2013",
  year <= 2021 ~ "2014-2021",
  TRUE         ~ "2022-2025"
))
partners <- group_by(partners, from, period)
partners <- summarise(partners, n_partners = n_distinct(to), .groups = "drop")

# Total exports per supplier and period (all recipients)
exports <- mutate(edges, period = case_when(
  year <= 2013 ~ "2000-2013",
  year <= 2021 ~ "2014-2021",
  TRUE         ~ "2022-2025"
))
exports <- group_by(exports, from, period)
exports <- summarise(exports, tiv_total = sum(tiv), .groups = "drop")

# Top 5 clients per supplier and period (all recipients)

clients <- mutate(edges, period = case_when(
  year <= 2013 ~ "2000-2013",
  year <= 2021 ~ "2014-2021",
  TRUE         ~ "2022-2025"
))
clients <- group_by(clients, from, period, to)
clients <- summarise(clients, tiv_total = sum(tiv), .groups = "drop")
clients <- group_by(clients, from, period)
clients <- slice_max(clients, tiv_total, n = 5)

# Non-state actors and international organisations (whole period)

non_state <- filter(edges, actor_type != "state")
non_state <- group_by(non_state, from, to, actor_type)
non_state <- summarise(non_state, tiv_total = sum(tiv), .groups = "drop")

# Section G: robustness checks ----

# Robustness check 1: different period breaks (2012 and 2020)

robust <- mutate(edges_four, period_alt = case_when(
  year <= 2011 ~ "2000-2011",
  year <= 2019 ~ "2012-2019",
  TRUE         ~ "2020-2025"
))
robust <- group_by(robust, period_alt, from, to)
robust <- summarise(robust, tiv_total = sum(tiv), .groups = "drop")

# Robustness check 2: one break only (2022)

robust2 <- mutate(edges_four, period_alt = case_when(
  year <= 2021 ~ "2000-2021",
  TRUE         ~ "2022-2025"
))
robust2 <- group_by(robust2, period_alt, from, to)
robust2 <- summarise(robust2, tiv_total = sum(tiv), .groups = "drop")

# Robustness check 3: drop period edges under 5 TIV per year

strong <- filter(period_edges, tiv_per_year >= 5)


# Save results
write_csv(partners,  "output/partners.csv")
write_csv(exports,   "output/exports.csv")
write_csv(clients,   "output/top_clients.csv")
write_csv(non_state, "output/non_state.csv")
write_csv(robust,    "output/robust_2012_2020.csv")
write_csv(robust2,   "output/robust_2022_only.csv")
write_csv(strong,    "output/strong_edges.csv")

# Section H: Plots ----

# Direction of each edge, for the annual time series

flows <- mutate(edges_four, direction = case_when(
  from == "Russia" ~ "From Russia",
  to == "Russia"   ~ "To Russia",
  TRUE             ~ "Among the other three"
))

annual_dir <- group_by(flows, year, direction)
annual_dir <- summarise(annual_dir, tiv = sum(tiv), .groups = "drop")

# Years with no flow get 0 (empty in SIPRI = no deliveries), so lines don't skip them

annual_dir <- complete(annual_dir, year, direction, fill = list(tiv = 0))


plot_annual <- ggplot(annual_dir, aes(x = year, y = tiv, colour = direction)) +
  geom_line()

plot_annual <- plot_annual +
  geom_vline(xintercept = c(2014, 2022), linetype = "dashed")

plot_annual <- plot_annual +
  labs(title = "Major arms transfers among China, Russia, Iran and North Korea, 2000-2025",
       x = "Year", y = "TIV (millions)", colour = "Direction",
       caption = "Source: SIPRI Arms Transfers Database (March 2026). Dashed lines: 2014 and 2022.")

plot_zoom <- plot_annual +
  coord_cartesian(xlim = c(2014, 2025), ylim = c(0, 2000))



# Saving the plots

ggsave("output/annual_flows.png",      plot_annual, width = 9, height = 5)
ggsave("output/annual_flows_zoom.png", plot_zoom,   width = 9, height = 5)


# Network by period: one graph, each edge keeps its period and TIV per year

edges_plot <- select(period_edges, from, to, period, tiv_per_year)
g_all <- graph_from_data_frame(edges_plot, directed = TRUE, vertices = nodes)


plot_network <- ggraph(g_all, layout = "circle") +
  geom_edge_arc(aes(width = tiv_per_year,
                    start_cap = label_rect(node1.name),
                    end_cap = label_rect(node2.name)),
                strength = 0.2, colour = "firebrick", alpha = 0.7,
                arrow = arrow(length = unit(3, "mm"), type = "closed")) +
  scale_edge_width(range = c(0.4, 4), trans = "sqrt", name = "TIV per year") +
  geom_node_label(aes(label = name), size = 3.5) +
  facet_edges(~ period) +
  coord_fixed(clip = "off") +
  theme_void() +
  theme(legend.position = "bottom",
        strip.text = element_text(size = 11, face = "bold"),
        panel.spacing = unit(2, "lines"),
        plot.margin = margin(10, 40, 10, 40),
        plot.title = element_text(margin = margin(b = 15))) +
  labs(title = "Major arms transfers among the four, TIV per year by period",
       caption = "Source: SIPRI Arms Transfers Database (March 2026). Edge width on a square-root scale.")

ggsave("output/network_by_period.png", plot_network, width = 12, height = 5, bg = "white")