# sensor-data-preprocessor

Sensor data preprocessor for downstream dashboards, etc.

## How it works

## How to create a Dropbox token secret

1. Generate a token using `token <- rdrop2refreshtoken::drop_auth()` (this is the `rdrop2` package with modifications to support long-lasting tokens; see https://github.com/karthik/rdrop2/issues/201)
2. Save then token as an RDS file: `saveRDS(token, file = "token.RDS")`
3. Generate a base64 encoding: `base64enc::base64encode("token.RDS")`
4. Copy the resulting string into a repository secret named `DROPBOX`

On an Actions runner, the `.github/workflows/preprocess.yml` file will save
this secret as a token file accessible to the R script. 

See also [this workflow](https://github.com/wilsonsj100/serc-lateral-flux/blob/dashboard/.github/workflows/update_data.yml) by [@abbylewis](https://github.com/abbylewis)
