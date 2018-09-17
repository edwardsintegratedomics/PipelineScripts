#StationCollation

#Accepts the two metadata excel files, one describing nutrients and the other
#providing the link between Orbitrap sample numbers and CTD/depth

#Outputs a single excel file "Clean_Stations.csv"

pw <- getwd()
save.image("Pre-Collation")
setwd("/mnt/windows/Users/willi/Documents/Berkeley/Elab/SURFIN/Data") #Assumes running in Ubuntu

library(xlsx)
library(dplyr)

#This excel file comes from Bethanie via the Dropbox Lipidomics Pipeline Pieces folder
#Needs to be manually downloaded and placed in the folder
nutrients <- read.xlsx("Copy of DYEatom_Summary_for_Bethanie_11-2015.xlsx", 
                       sheetIndex = 1, header = F, stringsAsFactors = F,
                       startRow = 1, endRow = 56)
nutrients <- nutrients[-c(50:54)] #Throw out NA columns
nms <- c(as.character(nutrients[1,1:30]), as.character(nutrients[2,31:49])) #get names
nutrients <- nutrients[-c(1:3),] #Throw out useless excel headers
names(nutrients) <- nms #Rename everything
nutrients$Long_prop <- round(as.numeric(nutrients$`Longitude (dd) W`)+as.numeric(nutrients$`Longitude (mm.mmm) W`)/60, 6)
nutrients$Lat_prop <- round(as.numeric(nutrients$`Latitude (dd) N`)+as.numeric(nutrients$`Latitude (mm.mmm) N`)/60, 6)
nutrients$PAR_prop <- as.numeric(gsub("%", "", nutrients$`Corrected PAR (%)`))/100
nutrients$Time_hour <- as.numeric(nutrients$`Time Local`)*24
nutrients$Date_prop <- as.numeric(nutrients$`Date Local`)-41451

#This excel file comes from the internet, from Bethanie's management website
#https://www2.whoi.edu/staff/bvanmooy/gordon-and-betty-moore-foundation-project-data/
url <- "http://www.whoi.edu/fileserver.do?id=205544&pt=2&p=192529"
download.file(url, destfile = paste0(getwd(), "/GBMF_Data_Exp2_BRE.xlsx"))
#Extract only the TLE-ESI data for the water column (6a)
OrbiNums <- read.xlsx("GBMF_Data_Exp2_BRE.xlsx", sheetIndex = 1, header=F,
                  startRow = 9, endRow = 72, stringsAsFactors = F)[3:4]
names(OrbiNums) <- c("Orbi Number", "Gross") #Rename them
ctdnum <- gsub(pattern = "sfc", "0m", OrbiNums$Gross) #Replace "sfc" with 0m
ctdnum <- gsub(pattern = "PS1312 CTD", "", ctdnum) #Throw out useless bit in front
ctdnum <- do.call(rbind, strsplit(ctdnum, "-")) #Extract depth and CTD separately
CTDs <- as.numeric(ctdnum[,1]) 
depths <- as.numeric(gsub("m", "", ctdnum[,2]))
OrbiNums <- cbind(OrbiNums, CTDs, depths)

cbind(OrbiNums$CTDs, OrbiNums$depths, NA, nutrients$CTD, nutrients$`Target Depth (m)`)
#nutrients has a duplicate CTD14, depth 2m
#throw out OrbiNum casts #25, 27 (duplicates from Station 9)

Orbi_keep <- c(1:40, 53:64)
Orbi_clean <- filter(OrbiNums, 1:64%in%Orbi_keep)

nut_keep <- c(1:23, 25:53)
nut_clean <- filter(nutrients, 1:53%in%nut_keep)

cbind(Orbi_clean$CTDs, Orbi_clean$depths, NA, 
      nut_clean$CTD, nut_clean$`Target Depth (m)`)

#What do I want in the complete data set?
#Orbi number
#Station
#CTD
#Depth
#Long
#Lat
#Date?
#Nutrients
#Corrected corrected PAR

stations_clean <- cbind(Orbi_num = Orbi_clean$`Orbi Number`, 
                        Station = nut_clean$Station,
                        CTD = Orbi_clean$CTDs, 
                        Depth = nut_clean$`Depth (m)`,
                        Long = nut_clean$Long_prop,
                        Lat = nut_clean$Lat_prop,
                        Day = nut_clean$Date_prop,
                        Time = nut_clean$Time_hour,
                        Phos = nut_clean$`Phosphate (umol/L)`,
                        Nitr = nut_clean$`Nitrate+Nitrite (umol/L)`,
                        Chl = nut_clean$`total chl (ug/L)`,
                        Chla = nut_clean$`chl a (ug/L)`,
                        Phaeo = nut_clean$`phaeo (ug/L)`,
                        diSi = nut_clean$`dSi (umol Si/L)`,
                        biSi = nut_clean$`bSi (umol Si/L)`,
                        Temp = nut_clean$`Temperature0 (oC)`,
                        Sal = nut_clean$`Salinity0 (PSU)`,
                        Density = nut_clean$`Density0 (sigma-theta)`,
                        NormPAR = nut_clean$PAR_prop
                        )

write.csv(x = stations_clean, file = "Clean_Stations.csv")

#And clean up afterward.
setwd(pw)
rm(list = ls())
load("Pre-Collation")
file.remove("Pre-Collation")
