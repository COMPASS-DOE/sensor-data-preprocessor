# Main preprocessor script

library(rdrop2refreshtoken)

message("Welcome to preprocessor.R")

writeLines(as.character(Sys.time()), "processed_data/my-data.txt")

if(file.exists("tokenfile.RDS")) {
    message("Dropbox token file exists!")
} else {
    stop("No Dropbox token file :(")
}

rdrop2refreshtoken::drop_auth(new_user = FALSE, rdstoken = "tokenfile.RDS")

SOURCE <- "COMPASS_PNNL_Data/current_data"
files <- drop_dir(path = SOURCE)

SITE <- "DLG"
sitefiles <- files[grep(paste0("^", SITE), files$name),]

# Don't download conflicted or backup files
sitefiles <- sitefiles[grep("conflicted", sitefiles$name, invert = TRUE),]
sitefiles <- sitefiles[grep("backup", sitefiles$name, invert = TRUE),]

message("Downloading ", nrow(sitefiles), " ", SITE, 
        " files from ", SOURCE, "...")
for(f in sitefiles$path_display) {
  drop_download(f, local_path = "raw_data/", overwrite = TRUE)
}

# Read the design table from the sensor data pipeline repo
dt <- readr::read_csv("https://raw.githubusercontent.com/COMPASS-DOE/sensor-data-pipeline/refs/heads/main/pipeline/metadata/design_table.csv",
                      col_types = "cccccccccDcc")
dt$note <- NULL
dt <- dt[!is.na(dt$Logger),] # remove empty rows
dt <- dt[!is.na(dt$valid_through),] # anything with a valid_through entry probably isn't needed
# For compactness, the design table may have expansions. For example,
# "DiffVoltA_Avg({1:8})" -> "DiffVoltA_Avg(1)", "DiffVoltA_Avg(2)", etc.
# Expand these rows into their individual entries
# For this we need the expand_df() function
# TODO: maybe move this back into compasstools?
source("https://raw.githubusercontent.com/COMPASS-DOE/sensor-data-pipeline/refs/heads/main/pipeline/L1_normalize-utils.R")
dt_ex <- expand_df(dt)

# Read the data

library(compasstools)

message("All done")
