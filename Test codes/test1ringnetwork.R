install.packages("igraph")


library(igraph)
ring <- make_ring(6)
show(ring)
plot(ring)

icm_simulation <- function(graph,seed_node,activation_prob=0.2){
  V(graph)$active<-0
  
  V(graph)[seed_node]$active<-1
  
  newly_active <- seed_node
  
  activation_hist<-list()
  activation_hist[[1]]<-V(graph)$active
  
  step <- 1
  while(length(newly_active)>0){
    step<-step+1
    currently_new_active<-c()
    
    for (node_id in newly_active){
      neighbors <- neighbors(graph, node_id)
      inactive_neighbors <- neighbors[V(graph)[neighbors]$active==0]
      
      for (neighbor_id in inactive_neighbors) {
        if(runif(1)<=activation_prob){
          V(graph)[neighbor_id]$active<-1
          currently_new_active<-c(currently_new_active, neighbor_id)
        }
        
      }
    } 
    newly_active <- unique(currently_new_active)
    
    activation_hist[[step]]<-V(graph)$active
    
    if(length(newly_active)==0){
      break
    }
  }
  return(list(final_state=V(graph)$active, history = activation_hist))
}
seed_node <- 1

cat(paste0("Starting ICM simulation with seed node: ", seed_node, " and activation probability of 1.\n"))

# Run the simulation
icm_result <- icm_simulation(ring, seed_node, activation_prob = 1)

# Display the final activation state
cat("\nFinal activation state (0 = inactive, 1 = active):\n")
print(icm_result$final_state)


node_colors <- c("lightgray", "red") # lightgray for inactive, red for active


# Plot each step of the activation history
par(mfrow = c(1, length(icm_result$history)), mar = c(1, 1, 3, 1)) # Arrange plots in a row

for (i in seq_along(icm_result$history)) {
  current_state <- icm_result$history[[i]]
  # Set node colors based on activation state
  V(ring)$color <- node_colors[current_state + 1] # +1 because R indexing starts at 1
  
  # Plot the graph for the current step
  plot(ring,
       main = paste0("Step ", i-1, ": Activated Nodes = ", sum(current_state)),
       vertex.label = V(ring)$name,
       vertex.label.color = "black",
       vertex.size = 30,
       edge.color = "gray",
       layout = layout_in_circle(ring)) 
}

# Reset plotting parameters
par(mfrow = c(1, 1), mar = c(5, 4, 4, 2) + 0.1)
