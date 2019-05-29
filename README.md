# PipelineScripts
Contains the R code necessary for converting Orbitrap mass-spec files into a cohesive peaklist



## Inputs:
- .RAW data files from an Orbitrap. In this case, can be downloaded here: ftp://ftp.whoi.edu/pub/science/MCG/gbmf/VanMooy/OxylipinAnalysis/expt%206%20&%207/

- Data summary file [here](https://www2.whoi.edu/staff/bvanmooy/gordon-and-betty-moore-foundation-project-data/)

- Nutrient data, from Bethanie (Lipid dropbox)

## Outputs:
- .csv file in long format with each compound, species, and class juxtaposed with the nutrient data for each experiment.

## Workflow:

### 1. Run 01_Extract_Raw_to_mzXML.R.
  - Inputs: .raw data files
  - Outputs: .mzxml data files, extracted into positive, and negative mode.
  - Notes: Must be run on a machine with msconvert command-line utility installed
    - Means it must be a Windows machine

### 2. Run 02_LOBSTAHS.R
  - Inputs: .mzxml files from above, custom database (optional, see below note)
  - Outputs: LOBSTAHS peaklist .csv file
  - Notes: Must be run twice, once for each polarity mode

### 3. Run 03_Station_Collation.R
  - Inputs: Data summary file (.xlsx) and nutrient data file (.xlsx) (see above)
  - Outputs: Clean_Stations.csv file, a combination of the two above.

### 4. Run 04_Data_Cleaning.R
 - Inputs: Clean_Stations.csv file, both negative and positive LOBSTAHS peaklists (.csv)
 - Outputs: .csv file in long format, a collation of all the data gathered.

## Custom database:

By default, step 2 uses the database that comes with the LOBSTAHS package. However, this database is customizable - compounds can be added or removed. There's a detailed process for this in the LOBSTAHS documentation, but Will wrote a wrapper for most of the functions and ported it out as a Shiny Application hosted on his personal Shiny website. Check it out [here](https://dubukay.shinyapps.io/DatabaseConstructor/). You can upload a previously created database as a .csv file and append compounds to it, or start from scratch and build a database from the ground up by specifying chemical formulas and iterations for them. Send Will an email if you're curious about how to use it.
