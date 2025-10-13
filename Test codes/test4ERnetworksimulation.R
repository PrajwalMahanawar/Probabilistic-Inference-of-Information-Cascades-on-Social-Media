library(igraph)

# ICM simulation function with activation history
icm_with_history <- function(graph, seed_node, activation_prob, max_steps = 2000) {
  V(graph)$active <- 0
  V(graph)[seed_node]$active <- 1
  newly_active <- seed_node
  
  activation_hist <- list()
  activation_hist[[1]] <- V(graph)$active
  step <- 1
  
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
    activation_hist[[step]] <- V(graph)$active
  }
  
  return(activation_hist)
}

# Monte Carlo Simulation Function
run_monte_carlo_icm <- function(n, p, activation_prob, u = 500, max_steps = 2000) {
  cascade_sizes <- numeric(u)
  
  for (i in 1:u) {
    g <- sample_gnp(n, p, directed = FALSE)
    seed_node <- sample(1:vcount(g), 1)
    history <- icm_with_history(g, seed_node, activation_prob, max_steps)
    final_state <- history[[length(history)]]
    cascade_sizes[i] <- sum(final_state)
  }
  
  return(cascade_sizes)
}

# Parameters
set.seed(42)
n <- 100
p <- 0.05
activation_prob <- 0.1
u <- 500
max_steps <- 2000

# Run Monte Carlo simulation
cascade_sizes <- run_monte_carlo_icm(n, p, activation_prob, u, max_steps)

# Plot cascade size distribution (log-log)
hist_data <- table(cascade_sizes)
plot(as.numeric(names(hist_data)),
     as.numeric(hist_data),
     log = "xy",
     type = "b",
     pch = 19,
     col = "blue",
     xlab = "Cascade Size",
     ylab = "Frequency",
     main = "Cascade Size Distribution (log-log scale)")

# Optional: Visualize one sample simulation (step-by-step activation)
# Generate one ER graph and run ICM
g <- sample_gnp(n, p, directed = FALSE)
seed_node <- sample(1:vcount(g), 1)
activation_history <- icm_with_history(g, seed_node, activation_prob, max_steps)
total_steps <- length(activation_history)
node_colors <- c("lightgray", "red")

# Plot each activation step one-by-one
for (i in 1:total_steps) {
  V(g)$color <- node_colors[activation_history[[i]] + 1]
  
  plot(g,
       main = paste("Activation Step", i - 1),
       vertex.label = NA,
       vertex.size = 6,
       edge.width = 1,
       layout = layout_with_fr(g))
  
  Sys.sleep(0.4)
}
