# sensor-data-preprocessor

Sensor data preprocessor for downstream dashboards, etc.

## How it works

This repository has a script (`preprocessor.R`) that
* Downloads data files in the `current_data/` folder on Dropbox for requested sites
* Reads in the downloaded data, attaches metadata, restructures into long format
* Saves the data as one or more high-performance [Apache parquet](https://parquet.apache.org) files for use by real-time dashbaords

This script is triggered by an auto-running GitHub Action that is controlled
by a YAML configuration file in `.github/workflows/`.

## How to create a Dropbox token secret

To get access to the COMPASS Dropbox, the script needs an [OAuth token](https://oauth.net/2/access-tokens/).

1. Generate a token using `token <- rdrop2refreshtoken::drop_auth()` (this is the `rdrop2` package with modifications to support long-lasting tokens; see https://github.com/karthik/rdrop2/issues/201)
2. Save the token as an RDS file: `saveRDS(token, file = "token.RDS")`
3. Generate a base64 encoding: `base64enc::base64encode("token.RDS")`
4. Copy the resulting string into a repository secret named `DROPBOX`

On an Actions runner, the `.github/workflows/preprocess.yml` file will save
this secret as a token file accessible to the R script. 

See also [this workflow](https://github.com/wilsonsj100/serc-lateral-flux/blob/dashboard/.github/workflows/update_data.yml) by [@abbylewis](https://github.com/abbylewis)
