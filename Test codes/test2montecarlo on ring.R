library(igraph)

# ICM simulation function
icm_simulation <- function(graph, seed_node, activation_prob) {
  V(graph)$active <- 0
  V(graph)[seed_node]$active <- 1
  newly_active <- seed_node
  
  while (length(newly_active) > 0) {
    next_active <- c()
    for (node in newly_active) {
      inactive_neighbors <- neighbors(graph, node)[V(graph)[neighbors(graph, node)]$active == 0]
      for (neighbor in inactive_neighbors) {
        if (runif(1) <= activation_prob) {
          V(graph)[neighbor]$active <- 1
          next_active <- c(next_active, neighbor)
        }
      }
    }
    newly_active <- unique(next_active)
  }
  return(sum(V(graph)$active))  # Cascade size
}

# Parameters
ring <- make_ring(100)           # Larger graph for more variability
seed_node <- 1
activation_prob <- 0.1           # Low prob for heavy-tailed cascades
u <- 500                       # High number of simulations

# Run simulations
cascade_sizes <- numeric(u)
for (i in 1:u) {
  cascade_sizes[i] <- icm_simulation(ring, seed_node, activation_prob)
}

# Frequency table
cascade_freq <- table(cascade_sizes)

# Prepare for log-log plot
x <- as.numeric(names(cascade_freq))
y <- as.numeric(cascade_freq)

# Plot: log-log scale
plot(x, y,
     log = "xy", col = "blue", type = "l", lwd = 2,
     xlab = "Cascade Size",
     ylab = "Count",
     main = "Distribution of Cascade Size (Log-Log Scale)")
grid()
