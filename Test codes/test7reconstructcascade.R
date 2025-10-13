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
  M=100
)%>%as_tibble()

sim1 %>% count(sim_id)%>%filter(n==6)
sim1 %>% filter(sim_id==13)%>%select(child,generation)

cascade <- sim1 %>% filter(sim_id==71)%>%select(child,generation)

cascade_reconsruct <- function(g,cascade){
  names(cascade)[names(cascade) == "child"] <- "node"
  inferred_edges <- list()
  cascade <- cascade %>% arrange(generation)
  
  for (i in 1:nrow(cascade)) {
    node <- cascade$node[i]
    gen <- cascade$generation[i]
    
    # Skip generation 0 (seed node)
    if (gen == 0) next
    
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
 