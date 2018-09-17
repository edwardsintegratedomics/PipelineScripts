# 04_Data_Cleaning.R

#Accepts the Clean_Stations.csv and LOB_Peaklist_Pos.csv

# Startup things ----
library(dplyr)

setwd("C:/Users/willi/Documents/Berkeley/Elab/SURFIN")

stations <- read.csv("Data/Clean_Stations.csv", stringsAsFactors = F, row.names = NULL)


# Positive mode data ----


raw_peaks <- read.csv("Data/LOB_Peaklist_Pos.csv", stringsAsFactors = F, row.names = NULL)

#Throw out all questionable assignments
peaks <- raw_peaks %>% mutate(questionable=C3c+C3f+C3r+C4+C5+C6a+C6b) %>%
  filter(questionable==0) %>% filter(!grepl("^L", species))

#Throw out all samples that don't have a match in the Stations file
statsamples <- stations$Orbi_num
allsamples <- grep("^Orbi", names(peaks), value = T)
nonsamples <- setdiff(allsamples, statsamples)
normal_samples <- select(peaks, setdiff(names(peaks), nonsamples))

#Throw out all samples with a weirdly low DNPPE value
normal_DNPPE <- normal_samples %>% filter(species=="DNPPE") %>% 
  select(grep("^Orbi", names(.))) %>% as.numeric()>5000000
normal_samples <- normal_samples %>% select(grep("^Orbi", names(.)))
normal_samples <- normal_samples[,normal_DNPPE]

#Normalize to the DNPPE value
norm_factor <- normal_samples %>% 
  slice(grep("DNPPE", peaks$compound_name)) %>% 
  as.numeric()
norm_factor <- max(norm_factor)/norm_factor
normed_samples <- sweep(x = normal_samples, MARGIN = 2, STATS = norm_factor, FUN = `*`)
slice(normed_samples, grep("DNPPE", peaks$compound_name))

#And replace all the old, gross samples with the shiny new ones
peaks[grep("^Orbi", names(peaks))] <- NULL
peaks <- cbind(peaks, normed_samples)

#Convert to long format
goodcolumns <- c("compound_name", "species", "lipid_class", grep("^Orbi", names(peaks), value = T))
peaks2melt <- select(peaks, goodcolumns)

longpeaks <- reshape2::melt(peaks2melt, id=c("compound_name", "species", "lipid_class"), 
               variable.name = "Orbi_num", value.name="intensity")

#And add the information from stations to make one massive data frame
Orbi_nums <- as.character(unique(longpeaks$Orbi_num))

lp <- list()
for(i in 1:length(Orbi_nums)) {
  longpeaks_i <- filter(longpeaks, Orbi_num==Orbi_nums[i])
  orbidata <- filter(stations, Orbi_num==Orbi_nums[i])
  orbidata$Orbi_num <- NULL
  longpeaks_i <- cbind(longpeaks_i, orbidata)
  lp[[i]] <- longpeaks_i
}
longpeaks <- do.call(rbind, lp)
longpeaks_pos <- cbind(longpeaks, polarity="Positive")





# Negative mode data ----

raw_peaks <- read.csv("Data/LOB_Peaklist_Neg.csv", stringsAsFactors = F, row.names = NULL)

#Throw out all questionable assignments
peaks <- raw_peaks %>% mutate(questionable=C3c+C3f+C3r+C4+C5+C6a+C6b) %>%
  filter(questionable==0) %>% filter(!grepl("^L", species))

#Throw out all samples that don't have a match in the Stations file
statsamples <- stations$Orbi_num
allsamples <- grep("^Orbi", names(peaks), value = T)
nonsamples <- setdiff(allsamples, statsamples)
normal_samples <- select(peaks, setdiff(names(peaks), nonsamples))

#Throw out all samples with a weirdly low DNPPE value
normal_DNPPE <- normal_samples %>% filter(species=="DNPPE") %>% 
  select(grep("^Orbi", names(.))) %>% as.numeric()>5000000
normal_samples <- normal_samples %>% select(grep("^Orbi", names(.)))
normal_samples <- normal_samples[,normal_DNPPE]

#Normalize to the DNPPE value
norm_factor <- normal_samples %>% 
  slice(grep("DNPPE", peaks$compound_name)) %>% 
  as.numeric()
norm_factor <- max(norm_factor)/norm_factor
normed_samples <- sweep(x = normal_samples, MARGIN = 2, STATS = norm_factor, FUN = `*`)
slice(normed_samples, grep("DNPPE", peaks$compound_name))

#And replace all the old, gross samples with the shiny new ones
peaks[grep("^Orbi", names(peaks))] <- NULL
peaks <- cbind(peaks, normed_samples)

#Convert to long format
goodcolumns <- c("compound_name", "species", "lipid_class", grep("^Orbi", names(peaks), value = T))
peaks2melt <- select(peaks, goodcolumns)

longpeaks <- reshape2::melt(peaks2melt, id=c("compound_name", "species", "lipid_class"), 
                            variable.name = "Orbi_num", value.name="intensity")

#And add the information from stations to make one massive data frame
Orbi_nums <- as.character(unique(longpeaks$Orbi_num))

lp <- list()
for(i in 1:length(Orbi_nums)) {
  longpeaks_i <- filter(longpeaks, Orbi_num==Orbi_nums[i])
  orbidata <- filter(stations, Orbi_num==Orbi_nums[i])
  orbidata$Orbi_num <- NULL
  longpeaks_i <- cbind(longpeaks_i, orbidata)
  lp[[i]] <- longpeaks_i
}
longpeaks <- do.call(rbind, lp)
longpeaks_neg <- cbind(longpeaks, polarity="Negative")



# Combination ----

comp_peaks <- rbind(longpeaks_pos, longpeaks_neg)

write.csv(comp_peaks, file = "Data/Clean_Complete.csv")
