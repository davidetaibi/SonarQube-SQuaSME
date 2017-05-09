# This script runs analysis on all revisions up to the current one
#
# if repository is not at its current revision, run: git pull origin master
# 
# check if it has execute permission: ls -l analyze-history.sh
# if not, add it with: chmod a+x analyze-history.sh
#
# !!!to run this script in background, call: nohup bash ./analyze-history.sh >../SASAbus.log 2>&1 &
# to see if it is running, call: ps aux | grep analyze-history
# to see last log entries, call:  tail -100000 nohup.out | grep 'EXECUTION\|Total time\|Analyzing revision'
#
# side note: when creating a script from windows - better make the file in linux
# and edit using WinSCP/FileZilla. I spent an hour of debbuging to realize the problem was linux/windows line endings.

# git clone https://github.com/SASAbus/SASAbus.git 
# cd SASAbus
# make analyze-history.sh
# make sonar.properties
# run script

settingsFile="sonar.properties"
startFromSha=""
#changeSettingsAt="eb0ab3d392a42c1835f79bcd7f5404bcc50c8e4c"
analyzeEvery=1

start=false
if [[ $startFromSha == "" ]]; then
  start=true
fi
#get all revisions ordered by commit date ascending
git log --pretty=format:"%cd %H" --date=iso-strict-local --reverse | {
counter=0
while IFS= read -r line
  do
    stringarray=($line)
    dateTimeStr=${stringarray[0]}
    offsetminutes=${dateTimeStr:(-2)}
    dateTimeStr=${dateTimeStr::-3}
    dateTimeStr+=$offsetminutes
    sha=${stringarray[1]}
    if ! $start; then
      if [ $sha == $startFromSha ]; then
        start=true
      fi
    fi
    if $start; then
      if ! ((counter % analyzeEvery)); then 
        git stash save
        git checkout -f $sha
        git stash pop
        echo "Analyzing revision:" $dateTimeStr $sha
#        if [ $sha == $changeSettingsAt ]; then
#          settingsFile="lucene2012.properties"
#        fi
        sonar-scanner -D project.settings=$settingsFile -D sonar.projectDate=$dateTimeStr
      fi
      let "counter++"
    fi
  done
}
