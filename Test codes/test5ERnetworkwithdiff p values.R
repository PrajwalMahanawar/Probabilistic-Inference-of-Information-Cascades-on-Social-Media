library(igraph)

# ICM function with history
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

# Monte Carlo for a single p
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
activation_prob <- 0.1
u <- 500
max_steps <- 2000
p_values <- c(0.01, 0.03, 0.05, 0.1)
colors <- c("red", "blue", "green", "purple")

# Run simulations
cascade_distributions <- list()
for (i in seq_along(p_values)) {
  cat("Running for p =", p_values[i], "\n")
  cascade_distributions[[i]] <- run_monte_carlo_icm(n, p_values[i], activation_prob, u, max_steps)
}

# Plotting log-log cascade size distributions
plot(NULL, xlim = c(1, n), ylim = c(1, u), log = "xy",
     xlab = "Cascade Size", ylab = "Frequency",
     main = "Cascade Size Distribution for Different p (log-log)")

for (i in seq_along(p_values)) {
  size_table <- table(cascade_distributions[[i]])
  points(as.numeric(names(size_table)),
         as.numeric(size_table),
         type = "b",
         col = colors[i],
         pch = 19)
}

legend("topright", legend = paste0("p = ", p_values), col = colors, pch = 19)

