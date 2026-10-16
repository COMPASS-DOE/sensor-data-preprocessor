# Local (NOT GitHub Actions) script, normally called by cron
# Runs the preprocessor and commits and pushes any changed files
# BBL 2026

echo "------------------------------------------------------------"
date

cd /Users/d3x290/Code/sensor-data-preprocessor/

# Pull down any new changes
git pull --ff-only

# Run preprocessor...
/usr/local/bin/Rscript ./preprocessor.R >> ~/Desktop/preprocessor.log

# ...and commit and push updates
git add .
git commit -m "Automated update (local)" || echo "No changes to commit"
git --verbose push
