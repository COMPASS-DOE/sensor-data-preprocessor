# Local script called by cron - run preprocessor and commit


echo "------------------------------------------------------------"
date

cd /Users/d3x290/Code/sensor-data-preprocessor/
/usr/local/bin/Rscript /Users/d3x290/Code/sensor-data-preprocessor/preprocessor.R >> ~/Desktop/preprocessor.log

git add .
git commit -m "Automated update (local)" || echo "No changes to commit"
git push
