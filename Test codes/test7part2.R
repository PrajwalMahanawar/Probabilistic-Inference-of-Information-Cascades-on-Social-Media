library(tidyverse)
library(igraph)
library(CascadeSimulatoR)
library(cowplot)
library(ggplot2)

set.seed(123)
g <- sample_gnp(1000, 0.1)
adj <- as_adj(g)

# Simulate cascades
sim1 <- CascadeSimulatoR::run_cascade_sim_tree_ICM(
  seed_node = 1,
  p = 0.01,
  adj_sp_mat = adj,
  M = 1000
) %>% as_tibble()

# Filter cascades with at least 10 nodes
sim_l10 <- sim1 %>% count(sim_id) %>% filter(n >= 10)
sim_true_cas <- sim1 %>% filter(sim_id %in% sim_l10$sim_id)

# Select a single cascade for reconstruction
sim_id_selected <- 1
cascade <- sim1 %>%
  filter(sim_id == sim_id_selected) %>%
  select(child, generation, sim_id)
cascade <- cascade %>% add_row(child = 1, generation = 0, sim_id = sim_id_selected, .before = 1)

# Reconstruction function
cascade_reconsruct <- function(g, cascade) {
  names(cascade)[names(cascade) == "child"] <- "node"
  inferred_edges <- list()
  inferred_generations <- list()
  cascade <- cascade %>% arrange(generation)
  
  for (i in 1:nrow(cascade)) {
    node <- cascade$node[i]
    gen <- cascade$generation[i]
    
    neighbors_prev_gen <- neighbors(g, node) %>%
      as_ids() %>%
      intersect(cascade$node)
    
    candidates <- cascade %>%
      filter(node %in% neighbors_prev_gen, generation == (gen - 1))
    
    if (nrow(candidates) > 0) {
      parent <- candidates$node[1]
      inferred_edges[[length(inferred_edges) + 1]] <- c(parent, node)
      inferred_generations[[length(inferred_generations) + 1]] <- gen
    }
  }
  
  edge_df <- do.call(rbind, inferred_edges) %>% as.data.frame()
  names(edge_df) <- c("parent", "child")
  edge_df$generation <- unlist(inferred_generations)
  
  edge_df$sim_id <- if ("sim_id" %in% names(cascade)) unique(cascade$sim_id) else NA
  
  cascade_graph <- graph_from_data_frame(edge_df, directed = TRUE)
  
  return(list(
    edge_list = edge_df,
    cascade_graph = cascade_graph
  ))
}

# Reconstruct
result <- cascade_reconsruct(g, cascade)
print(result$edge_list)
#plot(result$cascade_graph)  

# Plot reconstructed cascade
V(result$cascade_graph)$name <- as.character(V(result$cascade_graph)$name)
seed_node <- cascade %>% filter(generation == 0) %>% pull(child) %>% unique() %>% as.character()

V(result$cascade_graph)$color <- "skyblue"
V(result$cascade_graph)[name == seed_node]$color <- "tomato"

plot(
  result$cascade_graph,
  layout = layout_as_tree(result$cascade_graph, root = seed_node),
  vertex.size = 20,
  vertex.label.cex = 0.7,
  vertex.label.color = "black",
  edge.arrow.size = 0.3,
  vertex.color = V(result$cascade_graph)$color,
  main = paste("Reconstructed Cascade Tree\n(sim_id =", sim_id_selected, ")")
)

true_sizes <- sim_true_cas %>%
  group_by(sim_id) %>%
  summarise(size = n(), .groups = "drop")

# Reconstruct all cascades into a single edge list
reconstructed_all <- sim_true_cas %>%
  group_by(sim_id) %>%
  group_modify(~{
    cascade <- .x %>% select(parent, child, generation)
    
    # Ensure root node is added if missing
    if (!any(cascade$generation == 0)) {
      root_node <- setdiff(cascade$child, cascade$parent)[1]
      cascade <- cascade %>% add_row(child = root_node, generation = 0, .before = 1)
    }
    
    result <- cascade_reconsruct(g, cascade)
    
    # Remove sim_id to avoid group_modify() duplication
    result$edge_list %>% select(parent, child, generation)
    tibble(size = length(V(result$cascade_graph)))
  }) %>%
  ungroup()


hist_data <- table(reconstructed_all$size)

plot(as.numeric(names(hist_data)),
     as.numeric(hist_data),
     log = "xy",
     type = "b",
     pch = 19,
     col = "blue",
     xlab = "Cascade Size",
     ylab = "Frequency",
     main = "Cascade Size Distribution (log-log scale)")

true_hist <- table(true_sizes$size)
recon_hist <- table(reconstructed_all$size)

# Plot true cascades
plot(as.numeric(names(true_hist)),
     as.numeric(true_hist),
     log = "xy",
     type = "b",
     pch = 19,
     col = "darkgreen",
     xlab = "Cascade Size",
     ylab = "Frequency",
     main = "Cascade Size Distribution (log-log scale)")

# Add reconstructed cascades
points(as.numeric(names(recon_hist)),
       as.numeric(recon_hist),
       type = "b",
       pch = 17,
       col = "darkred")

# Add legend
legend("topright",
       legend = c("True Cascade", "Reconstructed Cascade"),
       col = c("darkgreen", "darkred"),
       pch = c(19, 17),
       lty = 1)



# Structural virality for TRUE cascades
sv_true <- CascadeSimulatoR::summarise_tree_structural_virality(sim_true_cas)



# Filter out empty reconstructed cascades
reconstructed_all <- sim_true_cas %>%
  group_by(sim_id) %>%
  group_modify(~{
    cascade <- .x %>% select(parent, child, generation)
    
    if (!any(cascade$generation == 0)) {
      root_node <- setdiff(cascade$child, cascade$parent)[1]
      cascade <- cascade %>% add_row(parent = NA, child = root_node, generation = 0, .before = 1)
    }
    
    result <- cascade_reconsruct(g, cascade)
    
    #Always return consistent columns without sim_id
    if (nrow(result$edge_list) == 0) {
      tibble(parent = NA_character_, child = NA_character_, generation = NA_real_)
    } else {
      result$edge_list %>% select(parent, child, generation)
    }
  }) %>%
  ungroup() %>%
  #Safe filtering
  filter(!is.na(parent) & !is.na(child))

# Structural virality for RECONSTRUCTED cascades
sv_reconstructed <- CascadeSimulatoR::summarise_tree_structural_virality(reconstructed_all)

# Round to 2 decimal places for binning
sv_true_rounded <- round(sv_true$structural_virality, 2)
sv_recon_rounded <- round(sv_reconstructed$structural_virality, 2)

# Create frequency tables
sv_true_hist <- table(sv_true_rounded)
sv_recon_hist <- table(sv_recon_rounded)
# Plot TRUE structural virality
plot(as.numeric(names(sv_true_hist)),
     as.numeric(sv_true_hist),
     log = "xy",
     type = "b",
     pch = 19,
     col = "darkgreen",
     xlab = "Structural Virality",
     ylab = "Frequency",
     main = "Structural Virality Distribution (log-log scale)")

# Add RECONSTRUCTED structural virality
points(as.numeric(names(sv_recon_hist)),
       as.numeric(sv_recon_hist),
       type = "b",
       pch = 17,
       col = "darkred")

# Add legend
legend("topright",
       legend = c("True Cascade", "Reconstructed Cascade"),
       col = c("darkgreen", "darkred"),
       pch = c(19, 17),
       lty = 1)
# Average depth for TRUE cascades
depth_true <- CascadeSimulatoR::summarize_tree_mean_depth(sim_true_cas)

# Average depth for RECONSTRUCTED cascades
depth_reconstructed <- CascadeSimulatoR::summarize_tree_mean_depth(reconstructed_all)

# Round to 2 decimal places
depth_true_rounded <- round(depth_true$average_depth, 2)
depth_recon_rounded <- round(depth_reconstructed$average_depth, 2)

# Frequency tables
depth_true_hist <- table(depth_true_rounded)
depth_recon_hist <- table(depth_recon_rounded)

# Plot TRUE average depth
plot(as.numeric(names(depth_true_hist)),
     as.numeric(depth_true_hist),
     log = "xy",
     type = "b",
     pch = 19,
     col = "darkgreen",
     xlab = "Average Depth",
     ylab = "Frequency",
     main = "Average Cascade Depth Distribution (log-log scale)")

# Add RECONSTRUCTED average depth
points(as.numeric(names(depth_recon_hist)),
       as.numeric(depth_recon_hist),
       type = "b",
       pch = 17,
       col = "darkred")

# Legend
legend("topright",
       legend = c("True Cascade", "Reconstructed Cascade"),
       col = c("darkgreen", "darkred"),
       pch = c(19, 17),
       lty = 1)

