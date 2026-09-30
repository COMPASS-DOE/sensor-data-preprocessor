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

files <- drop_dir(path = "COMPASS_PNNL_Data/current_data")

site <- "DLG"
sitefiles <- files[grep(paste0("^", site), files$name),]

# Don't download conflicted or backup files
sitefiles <- sitefiles[grep("conflicted", sitefiles$name, invert = TRUE),]
sitefiles <- sitefiles[grep("backup", sitefiles$name, invert = TRUE),]

message("Downloading ", nrow(sitefiles), " files...")
for(f in sitefiles$path_display) {
  drop_download(f, local_path = "raw_data/", overwrite = TRUE)
}

message("All done")
