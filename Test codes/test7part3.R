
library(tidyverse)
library(igraph)
library(CascadeSimulatoR)
library(cowplot)
library(ggplot2)

# Generate random graph
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


sim_l10 <- sim1 %>% count(sim_id) %>% filter(n >= 10)
sim_true_cas <- sim1 %>% filter(sim_id %in% sim_l10$sim_id)


sim_id_selected <- 32
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

# Plot reconstructed cascade
V(result$cascade_graph)$name <- as.character(V(result$cascade_graph)$name)
seed_node <- cascade %>% filter(generation == 0) %>% pull(child) %>% unique() %>% as.character()

V(result$cascade_graph)$color <- "skyblue"
V(result$cascade_graph)[name == seed_node]$color <- "tomato"

plot(
  result$cascade_graph,
  layout = layout_as_tree(result$cascade_graph, root = seed_node),
  vertex.size = 7,
  vertex.label.cex = 0.7,
  vertex.label.color = "black",
  edge.arrow.size = 0.3,
  vertex.color = V(result$cascade_graph)$color,
  main = paste("Reconstructed Cascade Tree\n(sim_id =", sim_id_selected, ")")
)

reconstructed_all <- sim_true_cas %>%
  group_by(sim_id) %>%
  group_modify(~{
    cascade <- .x %>% select(child, generation)
    cascade <- cascade %>% add_row(child = 1, generation = 0, .before = 1)
    result <- cascade_reconsruct(g, cascade)
    
    result$edge_list %>% select(-sim_id)  # remove sim_id to avoid conflict
  }) %>%
  ungroup()


# Cascade size distribution
dist_plot2 <- CascadeSimulatoR::summarise_tree_cascade_size(reconstructed_all)

ggplot(dist_plot2, aes(x = cascade_size, y = prob)) +
  geom_point() +
  geom_line() +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "Reconstructed Cascade Size Distribution (Log-Log)",
    x = "Cascade Size",
    y = "Probability"
  ) +
  theme_minimal()

dist_plot1 <- CascadeSimulatoR::summarise_tree_cascade_size(sim_true_cas) %>%
  mutate(Type = "True")

dist_plot2 <- dist_plot2 %>% mutate(Type = "Reconstructed")

cascade_dist_all <- bind_rows(dist_plot1, dist_plot2)

ggplot(cascade_dist_all, aes(x = cascade_size, y = prob, color = Type)) +
  geom_point(alpha = 0.7) +
  geom_line(alpha = 0.7) +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    title = "True vs Reconstructed Cascade Size Distributions (Log-Log)",
    x = "Cascade Size (log10)",
    y = "Probability (log10)",
    color = "Cascade Type"
  ) +
  theme_minimal()

# structural virality distribution
sv_reconstructed <- CascadeSimulatoR::summarise_tree_structural_virality(reconstructed_all)

ggplot(sv_reconstructed, aes(x = structural_virality)) +
  geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7) + 
  labs(
    title = "Structural Virality Distribution (Reconstructed Cascades)",
    x = "Structural Virality",
    y = "Count"
  ) +
  theme_minimal()

sv_true <- CascadeSimulatoR::summarise_tree_structural_virality(sim_true_cas) %>%
  mutate(source = "True Cascade")

reconstructed_df <- bind_rows(reconstructed_all)

sv_reconstructed <- CascadeSimulatoR::summarise_tree_structural_virality(reconstructed_df) %>%
  mutate(source = "Reconstructed Cascade")

sv_all <- bind_rows(sv_true, sv_reconstructed)

ggplot(sv_all, aes(x = structural_virality, fill = source)) +
  geom_histogram(alpha = 0.6, bins = 40, position = "identity") +
  labs(
    title = "Structural Virality Distribution: True vs Reconstructed Cascades",
    x = "Structural Virality",
    y = "Count"
  ) +
  theme_minimal()

# Average depth distribution

md_reconstructed <- CascadeSimulatoR::summarise_tree_mean_depth(reconstructed_all)

ggplot(md_reconstructed, aes(x = average_depth)) +
  geom_histogram(bins = 40, fill = "steelblue", alpha = 0.7) + 
  labs(
    title = "Average Depth Distribution (Reconstructed Cascades)",
    x = "Average Depth",
    y = "Count"
  ) +
  theme_minimal()

md_true <- CascadeSimulatoR::summarise_tree_mean_depth(sim_true_cas) %>%
  mutate(source = "True Cascade")


reconstructed_df <- bind_rows(reconstructed_all)

md_reconstructed <- CascadeSimulatoR::summarise_tree_mean_depth(reconstructed_df) %>%
  mutate(source = "Reconstructed Cascade")


md_all <- bind_rows(md_true, md_reconstructed)


ggplot(md_all, aes(x = average_depth, fill = source)) +
  geom_histogram(alpha = 0.6, bins = 40, position = "identity") +
  labs(
    title = "Mean Depth Distribution: True vs Reconstructed Cascades",
    x = "Mean Depth",
    y = "Count"
  ) +
  theme_minimal()

