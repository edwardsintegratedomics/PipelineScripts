# Run_LOBSTAHS.R

# Setup things ----

library(tools)
library(xcms)
library(CAMERA)
library(rsm)
library(parallel)
library(IPO)
library(snow)
library(BiocParallel)
library(LOBSTAHS)

register(bpstart(MulticoreParam(1)))

# General settings ----

#User: define locations of data files and database(s)
working_dir <- "/media/windows/Users/willi/Documents/Berkeley/Elab/SURFIN"
setwd(working_dir)

data_source <- "/media/wkumler/TheVault/6a_TLE_ESI" #Specify working directory for Ubuntu

mzXMLdirs <- c("/mzXML_pos", "/mzXML_neg")

# specify which of the directories above you wish to analyze this time through
chosenFileSubset = paste0(data_source, "/mzXML_pos/")

# specify the ID numbers (i.e., Orbi_xxxx.mzXML) of any files you don't want to push through xcms 
excluded.mzXMLfiles = NULL #leaving this blank (i.e. c() ) excludes all of them?

retcor.meth = "loess"

# Define functions ----

# readinteger: for a given prompt, allows capture of user input as an integer; rejects non-integer input
readinteger = function(prompttext) {
  
  n = readline(prompt=prompttext)
  
  if (!grepl("^[0-9]+$", n)) {
    
    return(readinteger(prompttext))
    
  }
  
  as.integer(n)
  
}

# readyesno: for a given prompt, allows capture of user input as y or n; rejects other input
readyesno = function(prompttext) {
  
  n = readline(prompt=prompttext)
  
  if (!grepl("y|n", n)) {
    
    return(readyesno(prompttext))
    
  }
  
  as.character(n)
  
}

# verifyFileIonMode: return the ion mode of data in a particular mzXML file, 
# by examining "polarity" attribute of each scan in the file
verifyFileIonMode = function(mzXMLfile) {
  
  rawfile = xcmsRaw(mzXMLfile) # create an xcmsraw object out of the first file
  
  # determine ion mode by examining identifier attached to scan events
  
  if (table(rawfile@polarity)["negative"]==0 & (table(rawfile@polarity)["positive"]==length(rawfile@scanindex))) { 
    
    filepolarity = 1 # positive
    
  } else if (table(rawfile@polarity)["positive"]==0 & (table(rawfile@polarity)["negative"]==length(rawfile@scanindex))) { 
    
    filepolarity = -1 # negative
    
  } else if (table(rawfile@polarity)["positive"]>=1 & table(rawfile@polarity)["negative"]>=1) { 
    
    stop("At least one file in the current dataset contains scans of more than one ion mode. 
         Please ensure data for different ion modes have been extracted into separate files. Stopping...") 
    
  } else if (table(rawfile@polarity)["positive"]==0 & table(rawfile@polarity)["negative"]==0) {
    
    stop("Can't determine ion mode of data in the first file. Check manner in which files were converted. Stopping...") 
    
  }
  
  filepolarity
  
}

# getSubsetIonMode: return the ion mode of a subset of files, using sapply of verifyFileIonMode
getSubsetIonMode = function(mzXMLfilelist) {
  
  ionmodecount = sum(sapply(mzXMLfilelist, verifyFileIonMode)) # get sum of ion mode indicators for the files in the subset
  
  if (ionmodecount==length(mzXMLfilelist)) { # can conclude that all files contain positive mode data
    
    subset.polarity = "positive"
    
  } else if (ionmodecount==-length(mzXMLfilelist)) { # can conclude that all files contain negative mode data
    
    subset.polarity = "negative"
    
  }
  
  subset.polarity
  
}

# selectXMLSubDir: allows user to choose which subset of files to process
selectXMLSubDir = function(mzXMLdirList) {
  
  print(paste0("mzXML files exist in the following directories:"))
  
  for (i in 1:length(mzXMLdirList)) {
    
    # get number of mzXML files in this directory
    numGoodFiles = length(list.files(mzXMLdirList[i], recursive = TRUE, full.names = TRUE, pattern = "*(.mzXML|.mzxml)"))
    
    if (numGoodFiles>0) { # there are .mzXML data files in this directory
      
      print(paste0(i, ". ", numGoodFiles," .mzXML files in directory '",mzXMLdirList[i],"'"))
      
    }
    
  }
  
  processDecision = readinteger("Specify which subset you'd like to process, using integer input: ")
  
  mzXMLdirList[processDecision]
  
}

# getFNmatches: returns index(es) of file names in a given file list containing the ID numbers in a match list
getFNmatches = function(filelist,IDnumlist) {
  
  unique(grep(paste(IDnumlist,collapse="|"),filelist, value=FALSE))
  
}

# genTimeStamp: generates a timestamp string based on the current system time
genTimeStamp = function () {
  
  output_DTG = format(Sys.time(), "%Y-%m-%dT%X%z") # return current time in a good format
  output_DTG = gsub(" ", "_", output_DTG) # replace any spaces
  output_DTG = gsub(":", "-", output_DTG) # replaces any colons with dashes (Mac compatibility)
  
}


# Load in mzXML files ----
# check to make sure user has specified at least something in mzXMLdirs
if (!exists("mzXMLdirs")) {
  
  stop("User has not specified any directories containing mzXML files. Specify a value for mzXMLdirs.")
  
}


# load selected subset for processing
mzXMLfiles.raw = list.files(chosenFileSubset, recursive = TRUE, full.names = TRUE)

# verify the ion mode of the data in these files
#subset.polarity = getSubsetIonMode(mzXMLfiles.raw)
subset.polarity = "positive" #Note the hack here for the sake of expediency

# provide some feedback to user
print(paste0("Loaded ",length(mzXMLfiles.raw)," mzXML files. These files contain ",
             subset.polarity," ion mode data. Raw dataset consists of:"))

print(mzXMLfiles.raw)

# Create xcmsSet ----

centW.min_peakwidth = 10
centW.max_peakwidth = 45
centW.ppm = 2.5
centW.mzdiff = 0.005
centW.snthresh = 10
centW.prefilter = c(3,7500)
centW.noise = 500
centW.fitgauss = TRUE
centW.sleep = 1
centW.mzCenterFun = c("wMean")
centW.verbose.columns = TRUE
centW.integrate = 1
centW.profparam = list(step=0.01) 
centW.nSlaves = 4 

# Create xcmsSet using selected settings
print(paste0("Creating xcmsSet object from ",length(mzXMLfiles),
             " mzXML files remaining in dataset using specified settings..."))

xset_centWave = xcmsSet(mzXMLfiles,
                        method = "centWave",
                        profparam = centW.profparam,
                        ppm = centW.ppm,
                        peakwidth = c(centW.min_peakwidth,centW.max_peakwidth),
                        fitgauss = centW.fitgauss,
                        noise = centW.noise,
                        mzdiff = centW.mzdiff,
                        verbose.columns = centW.verbose.columns,
                        snthresh = centW.snthresh,
                        integrate = centW.integrate,
                        prefilter = centW.prefilter,
                        mzCenterFun = centW.mzCenterFun,
                        #                 sleep = centW.sleep
                        BPPARAM = bpparam()
)

print(paste0("xcmsSet object xset_centWave created:"))

print(xset_centWave)
save(xset_centWave, file = "xset_CentWave")
#Conclude xcmsSet object creation, saved as xset_CentWave


# Retention time correction and grouping ----
load("xset_CentWave")

loess.missing = 1
loess.extra = 1
loess.smoothing = "loess"
loess.span = c(0.2)
loess.family = "gaussian"
obiwarp.center = NULL
obiwarp.profStep = 1
obiwarp.response = 1
obiwarp.distFunc = "cor_opt"
obiwarp.gapInit = NULL
obiwarp.gapExtend = NULL
obiwarp.factorDiag = 2
obiwarp.factorGap = 1
obiwarp.localAlignment = 0
density.bw = 5
density.max = 50
density.minfrac = 0.25
density.minsamp = 2
density.mzwid = 0.015
obiwarp.center = NULL
obiwarp.plottype = "deviation" # "none"
density.sleep = 0
loess.plottype = "mdevden" # none

# Group for the first time

xset_gr = group(xset_centWave,
                method = "density",
                bw = density.bw,
                minfrac = density.minfrac,
                minsamp = density.minsamp,
                mzwid = density.mzwid,
                max = density.max,
                sleep = density.sleep
)
rm(xset_centWave)

# Correct the retention times based on groupings
xset_gr.ret = retcor(xset_gr,
                     missing = loess.missing,
                     extra = loess.extra,
                     smooth = "loess",
                     span = loess.span,
                     family = loess.family,
                     plottype = loess.plottype,
                     col = NULL,
                     ty = NULL)
rm(xset_gr)

# Group for the second time
xset_gr.ret.rg = group(xset_gr.ret,
                       method = "density",
                       bw = density.bw,
                       minfrac = density.minfrac,
                       minsamp = density.minsamp,
                       mzwid = density.mzwid,
                       max = density.max,
                       sleep = density.sleep
)
save(xset_gr.ret.rg, file="xset_gr.ret.rg")
rm("xset_gr.ret")

# Fill in missing peaks ----
# Begin peak filling
register(bpstart(MulticoreParam(1)))

load("xset_gr.ret.rg")
xset_gr.ret.rg.fill = fillPeaks.chrom(xset_gr.ret.rg, BPPARAM = bpparam())

save(xset_gr.ret.rg.fill, file = "xset_gr.ret.rg.fill")
rm(xset_gr.ret.rg)

# CAMERA ----
load("xset_gr.ret.rg.fill")

imports = parent.env(getNamespace("CAMERA"))
unlockBinding("groups", imports)
imports[["groups"]] = xcms::groups
lockBinding("groups", imports)

xset_a = annotate(xset_gr.ret.rg.fill,
                  
                  quick=FALSE, 
                  sample=NA, # use all samples
                  nSlaves=1, # use 4 sockets
                  
                  # group FWHM settings
                  # using defaults for now
                  
                  sigma=6,
                  perfwhm=0.6,
                  
                  # groupCorr settings
                  # using defaults for now
                  
                  cor_eic_th=0.75,
                  graphMethod="hcs",
                  pval=0.05,
                  calcCiS=TRUE,
                  calcIso=TRUE,
                  calcCaS=FALSE, # weird results with this set to TRUE
                  
                  # findIsotopes settings
                  
                  maxcharge=4,
                  maxiso=4,
                  minfrac=0.5, # 0.25?
                  
                  # adduct annotation settings
                  
                  psg_list=NULL,
                  rules=NULL,
                  polarity=subset.polarity,
                  multiplier=3,
                  max_peaks=100,
                  
                  # common to multiple tasks
                  
                  intval="into",
                  ppm=2.5,
                  mzabs=0.0015
                  
)
rm(xset_gr.ret.rg.fill)

save(xset_a, file = "prepCompletedxsA")
load("prepCompletedxsA")

# LOBSTAHS ----
data(default.LOBdbase)

LOB <- doLOBscreen(xsA=xset_a, polarity = "positive", match.ppm = 2.5, 
                   retain.unidentified = F, rt.restrict = T)

LOBscreen_diagnostics(LOB)
LOBdata <- getLOBpeaklist(LOB) 
write.csv(LOBdata, file = "LOB_Peaklist_Pos.csv")

rm(xset_a, LOB, default.LOBdbase)
