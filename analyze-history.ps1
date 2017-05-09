# needs git in command line
# needs sonar-scanner directory to be in path variable (otherwise change line 34 to <path to sonar scanner>\sonar-scanner.bat)

# IMPORTANT: after stopping script delete ALL untracked project files: git clean -df
# before running "git status" should show ONLY script/sonar files!!!
# to run on the latest revision, call: git reset --hard origin/master

$settingsFile="sonar.properties"
$startFromSha=""
#$changeSettingsAt="eb0ab3d392a42c1835f79bcd7f5404bcc50c8e4c" #Tue Feb 7 19:59:05 2012 
$analyzeEvery=1

$start=0
if ($startFromSha.Equals("")) {
  $start=1
}
#get all revisions ordered by commit date ascending
$fullLog = git log --pretty=format:"%cd %H" --date=iso-strict-local --reverse
$counter = 0
foreach($entry in $fullLog) {
  $log = $entry.Split(" ")
  $date = $log[0]
  $sha = $log[1]
  if (!$start) {
    if($sha.Equals($startFromSha)) {
      $start = 1
    }
  }
  if ($start) {
    if (($counter % $analyzeEvery) -eq 0) {
      git stash save -u >$null 2>&1
      git checkout -f $sha >$null 2>&1
      git stash pop >$null 2>&1
#	  if ($sha.Equals($changeSettingsAt)) {
#        $settingsFile="lucene2012.properties"
#      }
	  $logFile = "sonar_log\$($date.Split("T")[0])-$($sha).txt"
	  New-Item -ItemType "file" -Path $logFile -force
      sonar-scanner.bat -D project.settings=$settingsFile -D sonar.projectDate=$date >$logFile 2>&1
    }
  }
  $counter = $counter + 1
}
