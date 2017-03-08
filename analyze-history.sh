# This script runs analysis on all revisions up to the current one
# 
# check if it has execute permission: ls -l analyze-history.sh
# if not, add it with: chmod a+x analyze-history.sh
#
# to run this script in background, call: nohup bash ./analyze-history.sh &
# output will be saved to nohup.out
# to see if it is running, call: ps aux | grep analyze-history
#
# side note: when creating a script from windows - better make the file in linux
# and edit using WinSCP/FileZilla. I spent an hour of debbuging to realize the problem was linux/windows line endings.

settingsFile="lucene.properties"
startFromSha="8c6911150881d770ca920d0e1b23395fbb993ce9"
changeSettingsAt="eb0ab3d392a42c1835f79bcd7f5404bcc50c8e4c"
start=false
if [[ $startFromSha == "" ]]; then
  start=true
fi
#get all revisions ordered by commit date ascending
git log --pretty=format:"%cd %H" --date=short --reverse | {
while IFS= read -r line
  do
    stringarray=($line)
    date=${stringarray[0]}
    sha=${stringarray[1]}
    if $start; then
      git stash save
      git checkout -f $sha
      git stash pop
      echo "Analyzing revision:" $date $sha
      if [ $sha == $changeSettingsAt ]; then
        settingsFile="lucene2012.properties"
      fi
#      sonar-scanner -D project.settings=$settingsFile -D sonar.projectDate=$date
      ../sonar-scanner-2.8/bin/sonar-scanner -D project.settings=$settingsFile -D sonar.projectDate=$date
    else
      if [ $sha == $startFromSha ]; then
        start=true
      else
#        echo "Skipped revision:" $date $sha
        continue
      fi
    fi
  done
}