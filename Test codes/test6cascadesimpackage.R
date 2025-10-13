library(ggplot2)
library(tidyverse)
library(cowplot)
install.packages("~/Downloads/MSc thesis simulation/CascadeSimulatoR_0.1.0.tar.gz")
library(CascadeSimulatoR)
library(igraph)
g <- sample_gnp(1000,0.1)
adj <- as_adj(g)

sim1 <- CascadeSimulatoR::run_cascade_sim_tree_ICM(
  seed_node = 1,
  p=0.01,
  adj_sp_mat = adj,
  M=100
)%>%as_tibble()

dist_plot1<- CascadeSimulatoR::summarise_tree_cascade_size(sim1)
ggplot(dist_plot1,aes(x=cascade_size,y=prob))+
  geom_point()+
  geom_line()+
  scale_x_log10()+
  scale_y_log10()

dist_plot2 <- CascadeSimulatoR::summarise_tree_structural_virality(sim1)
ggplot(dist_plot2,aes(x=structural_virality ,y=prob))+
  geom_point()+
  geom_line()+
  scale_x_log10()+
  scale_y_log10()

sim1 %>% count(sim_id)%>%filter(n==6)
sim1%>% filter(sim_id==20)
#sim1%>% filter(sim_id==81)
cascade <- sim1%>% filter(sim_id==20)

cascade_graph <- graph_from_data_frame(d=cascade %>% select(parent,child), directed=TRUE)

installed.packages('tidygraph')
library(tidygraph)
tg <- as_tbl_graph(cascade_graph)%>%activate(nodes)%>% mutate(generation=cascade$generation[match(as.integer(name), cascade$child)])


library(ggraph)
ggraph(tg, layout = "tree") +
  geom_edge_link(arrow = arrow(length = unit(3, 'mm')), end_cap = circle(3, 'mm')) +
  geom_node_point(aes(color = as.factor(generation)), size = 4) +
  geom_node_text(aes(label = name), vjust = -0.5) +
  theme_minimal() +
  labs(title = "Cascade Tree (sim_id = 77)", color = "Generation")
