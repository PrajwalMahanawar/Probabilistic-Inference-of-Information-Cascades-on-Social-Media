library(tidyverse)
library(igraph)
library(CascadeSimulatoR)
library(cowplot)
library(ggplot2)

g <- sample_gnp(1000,0.1)
adj <- as_adj(g)

sim1 <- CascadeSimulatoR::run_cascade_sim_tree_ICM(
  seed_node = 1,
  p=0.01,
  adj_sp_mat = adj,
  M=1000
)%>%as_tibble()

sim_l10 <- sim1 %>% count(sim_id)%>%filter(n>=10)

sim_true_cas <- sim1 %>% filter(sim_id %in% sim_l10$sim_id)

# sim1 %>% filter(sim_id==8)%>%select(child,generation)
sim_id_selected <-4 
cascade <- sim1 %>% filter(sim_id==sim_id_selected)%>%select(child,generation)
cascade <- cascade %>% add_row(child = 1, generation = 0, .before = 1)
cascade_reconsruct <- function(g,cascade){
  names(cascade)[names(cascade) == "child"] <- "node"
  inferred_edges <- list()
  cascade <- cascade %>% arrange(generation)
  
  for (i in 1:nrow(cascade)) {
    node <- cascade$node[i]
    gen <- cascade$generation[i]
    
    # Skip generation 0 (seed node)
    #if (gen == 0) next
    
    # Find neighbors that were active in previous generation
    neighbors_prev_gen <- neighbors(g, node) %>%
      as_ids() %>%
      intersect(cascade$node)
    
    candidates <- cascade %>%
      filter(node %in% neighbors_prev_gen, generation == (gen - 1))
    
    if (nrow(candidates) > 0) {
      # Choose first candidate as parent (or sample randomly)
      parent <- candidates$node[1]
      inferred_edges[[length(inferred_edges) + 1]] <- c(parent, node)
    }
  }
  
  # Convert edge list to dataframe
  edge_df <- do.call(rbind, inferred_edges) %>% as.data.frame()
  names(edge_df) <- c("parent", "child")
  
  # Build igraph from inferred cascade
  cascade_graph <- graph_from_data_frame(edge_df, directed = TRUE)
  
  return(list(
    edge_list = edge_df,
    cascade_graph = cascade_graph
  ))
}
result <- cascade_reconsruct(g, cascade)

# View the output
print(result$edge_list)
plot(result$cascade_graph)  

V(result$cascade_graph)$name <- as.character(V(result$cascade_graph)$name)
seed_node <- cascade %>% filter(generation == 0) %>% pull(child) %>% unique()
seed_node <- as.character(seed_node)


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
