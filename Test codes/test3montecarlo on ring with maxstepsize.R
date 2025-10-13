library(igraph)

# ICM simulation with max step limit
icm_simulation <- function(graph, seed_node, activation_prob, max_steps = 2000) {
  V(graph)$active <- 0
  V(graph)[seed_node]$active <- 1
  newly_active <- seed_node
  
  step <- 0
  while (length(newly_active) > 0 && step < max_steps) {
    step <- step + 1
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
  
  return(sum(V(graph)$active))  # Return cascade size
}

# Parameters
set.seed(42)                    # For reproducibility
ring <- make_ring(100)         # Use a larger graph
seed_node <- 1
activation_prob <- 0.1
max_steps <- 2000
u <- 10000                     # Number of simulations

# Run Monte Carlo simulations
cascade_sizes <- numeric(u)
for (i in 1:u) {
  cascade_sizes[i] <- icm_simulation(ring, seed_node, activation_prob, max_steps)
}

# Frequency table
cascade_freq <- table(cascade_sizes)

# Prepare data for log-log plot
x <- as.numeric(names(cascade_freq))
y <- as.numeric(cascade_freq)

# Plot on log-log scale
plot(x, y,
     log = "xy", col = "blue", type = "l", lwd = 2,
     xlab = "Cascade Size",
     ylab = "Count",
     main = "Cascade Size Distribution (Log-Log Scale with max_steps = 2000)")
grid()
