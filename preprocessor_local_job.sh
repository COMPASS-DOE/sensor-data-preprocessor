# Local (NOT GitHub Actions) script, normally called by cron
# Runs the preprocessor and commits and pushes any changed files
# BBL 2026

echo "------------------------------------------------------------"
date

cd /Users/d3x290/Code/sensor-data-preprocessor/
/usr/local/bin/Rscript ./preprocessor.R >> ~/Desktop/preprocessor.log

git add .
git commit -m "Automated update (local)" || echo "No changes to commit"
git push
