# This script runs analysis on all revisions up to the current one
#
# if repository is not at its current revision, run: git pull origin master
# 
# check if it has execute permission: ls -l analyze-history.sh
# if not, add it with: chmod a+x analyze-history.sh
#
# !!!to run this script in background, call: nohup bash ./analyze-history.sh &
# output will be saved to nohup.out
# to see if it is running, call: ps aux | grep analyze-history
# to see last log entries, call:  tail -100000 nohup.out | grep 'EXECUTION\|Total time\|Analyzing revision'
#
# side note: when creating a script from windows - better make the file in linux
# and edit using WinSCP/FileZilla. I spent an hour of debbuging to realize the problem was linux/windows line endings.

settingsFile="lucene.properties"
startFromSha="02612b7be873d6c39d999aa4e01214a7b8bb517b"
changeSettingsAt="eb0ab3d392a42c1835f79bcd7f5404bcc50c8e4c"
analyzeEvery=50

start=false
if [[ $startFromSha == "" ]]; then
  start=true
fi
#get all revisions ordered by commit date ascending
git log --pretty=format:"%cd %H" --date=short --reverse | {
counter=0
while IFS= read -r line
  do
    stringarray=($line)
    date=${stringarray[0]}
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
        echo "Analyzing revision:" $date $sha
        if [ $sha == $changeSettingsAt ]; then
          settingsFile="lucene2012.properties"
        fi
#        sonar-scanner -D project.settings=$settingsFile -D sonar.projectDate=$date
        ../sonar-scanner-2.8/bin/sonar-scanner -D project.settings=$settingsFile -D sonar.projectDate=$date
      fi
      let "counter++"
    fi
  done
}
