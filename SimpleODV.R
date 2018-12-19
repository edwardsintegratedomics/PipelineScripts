#===========================
# ODV Script
#
# Inputs: Data frame, in long format. 
#   Columns: Stations (x axis), Depth (y axis), intensity (z axis, aka color)
# Outputs: Contour image
#
#===========================

# Packages ----
library(dplyr)
library(ggplot2)
library(MBA)
library(reshape2)

# Where's the csv data file located?
# Remember that the function is expecting a data frame with 3 columns:
#   Stations (or kilometers, or something else) - used for x axis
#   Depth - used for y axis
#   Intensity - used for z axis, aka color
csv <- "/home/wkumler/Desktop/Elab/EdwardsLipids/Data/Clean_Complete.csv"

# What are your columns called?
xaxis <- "km"
yaxis <- "Depth"
zaxis <- "intensity"

# What are the units on the x axis?
xunits <- "Km"

# What do you want the axis labels to be?
xlabel <- "Distance"
ylabel <- "Depth"
zlabel <- "Intensity"




# Define the function ----
ODV <- function(data) {
  #Group and sum all samples with the same station and depth
  long_samples_i <- data %>% 
    group_by("xaxis"=get(xaxis), "yaxis"=get(yaxis)) %>%
    summarize("total" = sum(get(zaxis)))
  
  #Interpolating via MBA
  surf_i <- mba.surf(long_samples_i, no.X = 300, no.Y = 300, extend = T)
  dimnames(surf_i$xyz.est$z) <- list(surf_i$xyz.est$x, surf_i$xyz.est$y)
  surf_i <- melt(surf_i$xyz.est$z, varnames = c(xaxis, yaxis), 
                 value.name = zaxis)
  
  #Drawing
  gp <- ggplot(data = surf_i, aes(x = get(xaxis), y = get(yaxis))) +
    geom_raster(aes(fill = get(zaxis))) +
    scale_fill_gradientn(colours = rev(rainbow(5)), name=zlabel) +
    geom_point(data = long_samples_i, 
               alpha = 0.2, 
               aes(x=xaxis, y=yaxis)) +
    geom_contour(aes(z = get(zaxis)), 
                 binwidth = max(surf_i[[zaxis]])/8, 
                 colour = "black", 
                 alpha = 0.2) +
    scale_y_reverse() +
    scale_x_continuous(breaks=long_samples_i[["xaxis"]],
                     labels=paste(xaxis, long_samples_i[["xaxis"]])) +
    ylab(ylabel) + xlab(xlabel)
  print(xlab)
  return(gp)
}

# Load the data ----
data <- read.csv(csv, stringsAsFactors = F)


#Apply the function ----
ODV(data)
  #Plots all the data found in the LOBdata file

PG_data <- data %>% filter(species == "PG")
ODV(PG_data)
  #Plots only the PG data

shal_PG_data <- PG_data %>% filter(Depth < 10)
ODV(shal_PG_data)
  #Plots only the PG data less than 10m