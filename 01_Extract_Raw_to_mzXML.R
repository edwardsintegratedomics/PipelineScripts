#01_Extract_Raw_to_mzXML.R

#Remember, must be run in Windows
#Set working directory to where the files are
setwd("C:/Users/willi/Documents")

#Assumes Raw files are in a folder named "Raw" within WD

#Creates 3 new folders within WD:
#  mzXML_ms1_two_mode/ (initial convert raw to mzXML)
#  mzXML_pos/          (extracted positive mode data)
#  mzXML_neg/          (extracted negative mode data)

#Get a list of all the raw file names
rawFiles <- list.files("Raw")
baseNames <- gsub(pattern = ".raw", replacement = "", rawFiles)
filesToConvert <- rawFiles[!file.exists(paste0("mzXML_two_mode/", baseNames, ".mzxml"))]
filesToConvert <- paste0("Raw/", filesToConvert)

#Extract each of them
for(i in filesToConvert) {
  system(paste("msconvert", i, "--mzXML --filter \"peakPicking true 1-\" -o mzXML_two_mode -v"))
}

#Runs the shell command "msconvert FILENAME --mzXML --filter 'peakPicking true 1-' -o mzXML_ms1_two_mode -v"

filesToExtract <- paste0("mzXML_two_mode/", baseNames, ".mzXML")
#Extract them into positive and negative ion mode
for(i in 1:length(filesToExtract)) {
  system(paste0("msconvert ", filesToExtract[i], " --mzXML --filter \"polarity positive\" -o mzXML_pos -v"))
  system(paste0("msconvert ", filesToExtract[i], " --mzXML --filter \"polarity negative\" -o mzXML_neg -v"))
}

