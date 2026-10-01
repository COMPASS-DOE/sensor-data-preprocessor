# Main preprocessor script

# -------- Setup and confirm Dropbox token

# Packages
library(rdrop2refreshtoken)
library(compasstools)
library(arrow)
library(dplyr)
library(tidyr)
library(lubridate)

# File locations
RAW_DATA <- "raw_data/"
PROCESSED_DATA <- "processed_data/"

message("Welcome to preprocessor.R")

if(file.exists("tokenfile.RDS")) {
    message("Dropbox token file exists!")
} else {
    stop("No Dropbox token file :(")
}

rdrop2refreshtoken::drop_auth(new_user = FALSE, rdstoken = "tokenfile.RDS")


# -------- Download site data 

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
  drop_download(f, local_path = RAW_DATA, overwrite = TRUE)
}

# -------- Read and prep the design table 

# Read the design table from the sensor data pipeline repo
dt <- readr::read_csv("https://raw.githubusercontent.com/COMPASS-DOE/sensor-data-pipeline/refs/heads/main/pipeline/metadata/design_table.csv",
                      col_types = "cccccccccDcc")
dt <- dt[!is.na(dt$Logger),] # remove empty rows
dt <- dt[!is.na(dt$research_name),] # remove empty rows
dt <- dt[is.na(dt$valid_through),] # anything with a valid_through entry probably isn't needed
dt$note <- dt$valid_through <- NULL
# For compactness, the design table may have expansions. For example,
# "DiffVoltA_Avg({1:8})" -> "DiffVoltA_Avg(1)", "DiffVoltA_Avg(2)", etc.
# Expand these rows into their individual entries
# For this we need the expand_df() function
# TODO: maybe move this back into compasstools?
source("https://raw.githubusercontent.com/COMPASS-DOE/sensor-data-pipeline/refs/heads/main/pipeline/L1_normalize-utils.R")
dt_ex <- expand_df(dt)

# Read the data


# -------- Process data for one site and sensor 

SENSOR <- "[0-9]_Teros12" # ground TEROS, not stem
SENSOR_OUTPUT_NAME <- "Teros12"

regex <- paste0("^", SITE, ".*", SENSOR)
files <- list.files(RAW_DATA, regex, full.names = TRUE)
dat_list <- list()
for(f in files) {
  message("\tReading ", basename(f))
  compasstools::read_datalogger_file(f) |> 
    select(-Format, -RECORD, -PB, -Statname, -BattV_Avg) |> 
    mutate(TIMESTAMP = ymd_hms(TIMESTAMP, tz = "EST")) |> 
    pivot_longer(c(-Logger, -Table, -TIMESTAMP), names_to = "loggernet_variable") -> 
    dat_list[[f]]
}

bind_rows(dat_list) |> 
  left_join(dt_ex, 
            by = c("Logger", "Table", "loggernet_variable"),
            relationship = "many-to-one") ->
  x

outfile <- paste0(SITE, "_", SENSOR_OUTPUT_NAME, ".parquet")
message("Writing ", outfile)
write_parquet(x, file.path(PROCESSED_DATA, outfile))

message("All done")
