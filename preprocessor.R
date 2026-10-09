# Main preprocessor script
# BBL 2026

# -------- Setup

message("Welcome to preprocessor.R")

# Packages
library(rdrop2refreshtoken)
library(compasstools)
library(arrow)
library(dplyr)
library(tidyr)
library(lubridate)
library(readr)

# File locations
RAW_DATA <- "raw_data/"
PROCESSED_DATA <- "processed_data/"

# Data settings
WINDOW <- "3 days"
WINDOW_PERIOD <- as.period(WINDOW)

# Check Dropbox token
if(file.exists("tokenfile.RDS")) {
    message("Dropbox token file exists!")
} else {
    stop("No Dropbox token file :(")
}

drop_auth(new_user = FALSE, rdstoken = "tokenfile.RDS")


# -------- Download site data 

download_site_data <- function(site, dropbox_source, 
                               raw_data = RAW_DATA) {
  message("Getting file list...")
  files <- drop_dir(path = dropbox_source)
  sitefiles <- files[grep(paste0("^", site), files$name),]
  
  # Don't download conflicted or backup files
  sitefiles <- sitefiles[grep("conflicted", sitefiles$name, invert = TRUE),]
  sitefiles <- sitefiles[grep("backup", sitefiles$name, invert = TRUE),]
  
  message("Downloading ", nrow(sitefiles), " ", site, 
          " files from ", dropbox_source, "...")
  for(f in sitefiles$path_display) {
    drop_download(f, local_path = raw_data, overwrite = TRUE)
  }
}

download_site_data("DLG", "COMPASS_PNNL_Data/current_data")
download_site_data("Compass_CRC", "COMPASS_PNNL_Data/current_data")


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
dt_ex <- compasstools::expand_df(dt)


# -------- Process data for one site and sensor

process_data <- function(site, sensor_regex, sensor_output_name,
                         window_period = WINDOW_PERIOD, 
                         raw_data = RAW_DATA,
                         processed_data = PROCESSED_DATA) {
  
  # Synoptic site filenames are prefixed by "Compass_"
  regex <- paste0("^(Compass_)?", site, ".*", sensor_regex)
  files <- list.files(raw_data, regex, full.names = TRUE)
  message("I see ", length(files), " files to process for ", 
          site, " ", sensor_output_name)
  
  dat_list <- list()
  for(f in files) {
    message("\tReading ", basename(f))
    compasstools::read_datalogger_file(f) |> 
      # drop columns and filter for window period
      select(-starts_with("PB")) |>  # this may or may not exist
      select(-starts_with("BattV")) |>  # inconsistent naming; may be BattV_Avg
      select(-matches("_ID.\\(")) |> # AquaTROLL IDs are strings, not helpful
      select(-matches("_Dev.\\(")) |> # AquaTROLL IDs are strings, not helpful
      #select(-contains("00_DV(")) |> # what is this
      select(-Format, -RECORD, -Statname) |> 
      mutate(TIMESTAMP = ymd_hms(TIMESTAMP, tz = "EST")) |> 
      filter(Sys.time() - TIMESTAMP < window_period) |> 
      # ...before reshaping and saving
      pivot_longer(c(-Logger, -Table, -TIMESTAMP), names_to = "loggernet_variable") -> 
      dat_list[[f]]
  }
  
  bind_rows(dat_list) |> 
    left_join(dt_ex, 
              by = c("Logger", "Table", "loggernet_variable"),
              relationship = "many-to-one") |> 
    select(-Table, -loggernet_variable) ->
    x
  
  outfile <- paste0(site, "_", sensor_output_name, ".parquet")
  message("Writing ", nrow(x), " data rows to ", outfile)
  write_parquet(x, file.path(processed_data, outfile))
  return(list(nrow(x), max(x$TIMESTAMP), Sys.time()))
}

# Create a data frame to track what to process and results
tribble(
  ~Site, ~sensor_regex,   ~Sensor,
  "DLG", "[0-9]_Teros12", "TEROS12",
  "DLG", "Teros21",       "TEROS21",
  "DLG", "Level_Troll",   "LEVELTROLL",
  "DLG", "WaterLevel600", "AQUATROLL600",
  "CRC", "WaterLevel600", "AQUATROLL600"
) |> 
  mutate(Window = WINDOW, 
         N = NA_integer_,
         Latest_EST = NA_character_,
         Written_EST = NA_character_) ->
  data_to_process

for(i in seq_len(nrow(data_to_process))) {
  nums <- process_data(data_to_process$Site[i], 
                 data_to_process$sensor_regex[i],
                 data_to_process$Sensor[i])
  # process_data returns a list with N, latest timestamp, and current time
  data_to_process$N[i] <- nums[[1]]
  data_to_process$Latest_EST[i] <- as.character(nums[[2]])
  data_to_process$Written_EST[i] <- as.character(with_tz(nums[[3]], "EST"))
}

# Write manifest: list of files
data_to_process |> 
  select(-sensor_regex) |> 
  write_csv(file.path(PROCESSED_DATA, "manifest.csv"))

message("All done")


# -------- Examples for dashboards

# Check latest Git commit online
try(
  commit <- system("git ls-remote https://github.com/COMPASS-DOE/sensor-data-preprocessor.git | head -n 1 | cut -c 1-7",
                   intern = TRUE)
)
if(is.character(commit)) {
  message("Latest commit is ", commit)
} else {
  warning("Couldn't contact GitHub")
}

# If the latest commit is newer than anything we have seen, 
# fetch data. For example:
# read_parquet("https://github.com/COMPASS-DOE/sensor-data-preprocessor/raw/refs/heads/main/processed_data/DLG_TEROS12.parquet")
