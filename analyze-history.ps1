# needs git in command line
# needs sonar-scanner directory to be in path variable (otherwise change line 34 to <path to sonar scanner>\sonar-scanner.bat)

$settingsFile="lucene.properties"
$startFromSha=""
$changeSettingsAt="eb0ab3d392a42c1835f79bcd7f5404bcc50c8e4c"
$analyzeEvery=50

$start=0
if ($startFromSha.Equals("")) {
  $start=1
}
#get all revisions ordered by commit date ascending
$fullLog = git log --pretty=format:"%cd %H" --date=short --reverse
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
      git stash save
      git checkout -f $sha
      git stash pop
      echo "Analyzing revision: $($date) $($sha)"
	  if ($sha.Equals($changeSettingsAt)) {
        $settingsFile="lucene2012.properties"
      }
      sonar-scanner.bat -D project.settings=$settingsFile -D sonar.projectDate=$date
    }
  }
  $counter = $counter + 1
}
