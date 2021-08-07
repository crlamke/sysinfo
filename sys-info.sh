#!/bin/bash
#
#Script Name : sys-info.sh
#Description : This script provides the system resources and configuration
#              including RAM,CPUs, disk, last update date, uptime, ...
#Author      : Chris Lamke
#Copyright   : 2021 Christopher R Lamke
#License     : MIT - See https://opensource.org/licenses/MIT
#Last Update : 2021-06-26
#Version     : 0.2
#Usage       : sys-info.sh
#Notes       : 
#

# Report header and data display formats
reportLabelDivider="********************"
subReportHeader="****************"
subReportFooter="****************"
headerFormat="%-10s %-13s %-13s %-24s %-8s"
dataFormat="%-10s %-13s %-13s %-24s %-8s"
NL=$'\n'

# Paths to external tools if needed

# Constants to define function behavior
topProcessCount=5
HTMLOutput=1
TextOutput=1

cores=$(getconf _NPROCESSORS_ONLN)
ram=$(grep 'MemTotal:' /proc/meminfo | awk '{print int($2 / 1024)}')
hostName=$(hostname)
hostIP=$(hostname -I)
runDTG=$(date +"%Y-%m-%d-%H:%M %Z")
reportName="StatusReport-"
reportName+=$(date +"%Y-%m-%d-%H-%M-%Z")

# Report Variables - used to build report after gathering sys info
hwBasicsHTML=""
hwBasicsText=""
topProcsByCPUHTML=""
topProcsByRAMText=""
topProcsByRAMHTML=""
topProcsByCPUText=""
diskStatsHTML=""
diskStatsText=""
dockerStatsHTML=""
dockerStatsText=""
packageChangeStatsHTML=""
packageChangeStatsText=""
recentUserStatsHTML=""
recentUserStatsText=""
anomalousStatsHTML=""
anomalousStatsText=""
syslogStatsHTML=""
syslogStatsText=""
#suggestionsHTML=""
#suggestionsText=""


# Name: reportHWBasicStats
# Parameters: none
# Description: Print report header with machine type and resource info
function reportHWBasicStats
{
  htmlOut="<table>"
  hwBasicsText="Report Run Time: ${runDTG}${NL}"
  htmlOut+="<tr><th>Report Run Time</th><td>${runDTG}</td></tr>"
  hwBasicsText+="Hardware Resources: ${cores} CPU cores | ${ram} MB RAM ${NL}"
  htmlOut+="<tr><th>CPU Cores</th><td>${cores}</td></tr>"
  htmlOut+="<tr><th>RAM (MB)</th><td>${ram}</td></tr>"
  vmtype=$(systemd-detect-virt)
  if [[ $? -eq 0 ]]; then
    hwBasicsText+="Virtualization: Machine is a VM with \"${vmtype}\" type virtualization.${NL}"
    htmlOut+="<tr><th>Virtualization</th><td>Machine is a VM with \"${vmtype}\" type virtualization.</td></tr>"
  else
    hwBasicsText+="Virtualization: No virtualization detected.${NL}"
    htmlOut+="<tr><td>Virtualization: Machine is a VM with \"${vmtype}\" type virtualization.</td></tr>"
  fi
  hwBasicsText+="Hostname: ${hostName}${NL}"
  htmlOut+="<tr><th>Hostname</th><td>${hostName}</td></tr>"
  hwBasicsText+="Host IPs: ${hostIP}${NL}"
  htmlOut+="<tr><th>Host IPs</th><td>${hostIP}</td></tr>"
  # TODO make cmd below support more platforms
  osText=$(cat /etc/redhat-release)
  hwBasicsText+="OS Name and Version: ${osText}${NL}"
  htmlOut+="<tr><th>OS Name and Version</th><td>${osText}</td></tr>"
  htmlOut+="</table>"
  hwBasicsHTML=$htmlOut
}


# Name: reportTopProcessesByCPU
# Parameters: none
# Description: Report on processes consuming the most RAM and CPU
function reportTopProcessesByCPU()
{
  # Add one to topProcessCount to account for showing the header line.
  processLinesToShow=$(($topProcessCount+1))

  textOut="${subReportHeader}Top Processes By CPU${subReportHeader}${NL}"

  mkfifo tpPipe0
  IFS=" "
  htmlOut="<table><tr><th>% CPU</th><th>PID</th><th>User</th><th>% Mem</th><th>Process Details</th></tr>"
  ps -Ao pcpu,pid,user,pmem,cmd --sort=-pcpu --noheaders | \
    head -n 10 > tpPipe0 &
  while read -r cpu pid user mem cmd
  do
    htmlOut+="<tr><td>${cpu}</td><td>${pid}</td>"
    htmlOut+="<td>${user}</td><td>${mem}</td><td>${cmd}</td></tr>"
    textOut+="${cpu} | ${pid} | ${user} | ${mem} | ${cmd}${NL}"
  done < tpPipe0
  htmlOut+="</table>"
  rm tpPipe0

  topProcsByCPUText=$textOut
  topProcsByCPUHTML=$htmlOut
}


# Name: reportTopProcessesByRAM
# Parameters: none
# Description: Report on processes consuming the most RAM and CPU
function reportTopProcessesByRAM()
{
  # Add one to topProcessCount to account for showing the header line.
  processLinesToShow=$(($topProcessCount+1))

  textOut="${subReportHeader}Top Processes By RAM${subReportHeader}${NL}"

  mkfifo tpPipe0
  IFS=" "
  htmlOut="<table><tr><th>% Mem</th><th>% CPU</th><th>PID</th><th>User</th><th>Process Details</th></tr>"
  ps -Ao pmem,pcpu,pid,user,cmd --sort=-pmem --noheaders | \
    head -n 10 > tpPipe0 &
  while read -r mem cpu pid user cmd
  do
    htmlOut+="<tr><td>${mem}</td><td>${cpu}</td>"
    htmlOut+="<td>${pid}</td><td>${user}</td><td>${cmd}</td></tr>"
    textOut+="${mem} | ${cpu} | ${pid} | ${user} | ${cmd}${NL}"
  done < tpPipe0
  htmlOut+="</table>"
  rm tpPipe0

  topProcsByRAMText=$textOut
  topProcsByRAMHTML=$htmlOut
}


# Name: reportDiskStats
# Parameters: none
# Description: Report on disk status, usage and mounts
function reportDiskStats()
{
  htmlOut="<table><tr><th>% Used</th><th>Size</th><th>Mounted On</th><th>Filesystem</th></tr>"
  textOut="***Disk Space***\n"
  IFS=" "
  while read -r fileSystem size used avail percentUsed mountedOn
  do
    printf "%s\n" "$fileSystem | $size | $used | $avail | $percentUsed | $mountedOn"
    htmlOut+="<tr><td>${percentUsed}</td><td>${size}</td><td>${mountedOn}</td>"
    htmlOut+="<td>${fileSystem}</td></tr>"
    textOut+="${percentUsed} | ${size} | ${mountedOn} | ${fileSystem}${NL}"
  done <<< $(df -khP | sed '1d')

  htmlOut+="</table>"
  diskStatsText=$textOut
  diskStatsHTML=$htmlOut
  #printf "%s\n\n" "$diskStatsText"
  #printf "HTML is %s\n\n" "$diskStatsHTML"
}


# Name: reportDockerStatus
# Parameters: none
# Description: Report on Docker status
function reportDockerStatus()
{
  # Start with check if docker enabled and then docker ps and images
  if [ "x$(which docker)" == "x" ]; then
    dockerStatsText="Docker not installed"
    dockerStatsHTML="Docker not installed"
    return -1
  fi
return 0
  htmlOut="<table>"
  textOut="${subReportHeader}Docker Stats${subReportHeader}${NL}"
  mkfifo psPipe
  IFS=$'\n'
  textOut+="\"docker ps\" Output${NL}"
  #docker ps -a pcpu,comm,pid,user,uid,pmem,cmd --sort=-pcpu | \
  #  head -n $processLinesToShow > tpPipe &
  while read -r line;
  do
    htmlOut+="<tr><td>$line</td></tr>"
    textOut+="${line}${NL}"
  done < psPipe
  htmlOut+="</table>"
  #printf "\nhtml out: %s\n" "$htmlOut"
  #printf "\ntext out: %s\n" "$textOut"
  rm psPipe
  mkfifo tpPipe
  htmlOut+="<table>"
  textOut+="Top ${topProcessCount} processes by RAM${NL}"
  ps -Ao pmem,pcpu,comm,pid,user,uid,cmd --sort=-pmem | \
    head -n $processLinesToShow > tpPipe &
  while read -r line;
  do
    htmlOut+="<tr><td>$line</td></tr>"
    textOut+="${line}${NL}"
  done < tpPipe
  htmlOut+="</table>"
  #printf "\nhtml out: %s\n" "$htmlOut"
  #printf "\ntext out: %s\n" "$textOut"
  rm tpPipe
  dockerStatsText=$textOut
  dockerStatsHTML=$htmlOut
}


# Name: reportAnomalousProcesses
# Parameters: none
# Description: Report zombie, orphan, and other potentially anomalous processes
function reportAnomalousProcesses()
{
  printf "\n%s %s %s\n" "$subReportHeader" "Anomalous Processes" "$subReportHeader" 
  printf "Checking for zombie processes using \"ps axo pid=,stat= | awk '$2~/^Z/ { print $1 }'\"\n"
  ps axo pid=,stat= | awk '$2~/^Z/ { print $1 }'
  printf "Checking for orphan processes - not yet implemented\n"
}


# Name: reportRecentUsers
# Parameters: none
# Description: Report recently logged in users
function reportRecentUsers()
{
  printf "\n%s %s %s\n" "$subReportHeader" "Recent Users" "$subReportHeader" 
  printf "Current users and their activities using \"w\"\n"
  w
  printf "\nRecently logged in users using \"last\"\n"
  last -F -n 10
}


# Name: reportRecentPackageChanges
# Parameters: none
# Description: Report recent system changes via yum
function reportRecentPackageChanges()
{
  printf "\n%s %s %s\n" "$subReportHeader" "Recent Package Changes" "$subReportHeader" 
  printf "yum history\n"
  yum history
}


# Name: reportRecentEvents
# Parameters: none
# Description: Report current system status
function reportRecentEvents
{
  printf "\n%s %s %s\n" "$reportLabelDivider" "Recent System Events" "$reportLabelDivider"

}


# Name: reportSuggestions
# Parameters: none
# Description: Report current system status
function reportSuggestions
{
  #printf "\n%s %s %s\n" $reportLabelDivider "Troubleshooting Suggestions" $reportLabelDivider"
  printf "\nSuggestions not yet implemented\n"

}


# Name: gatherInfo
# Parameters: 
# Description: Run functions that gather the sys info
function gatherInfo
{
  reportHWBasicStats
  reportDiskStats
  reportTopProcessesByCPU
  reportTopProcessesByRAM
  reportDockerStatus
  #reportAnomalousProcesses
  reportRecentUsers
  reportRecentPackageChanges
  #reportRecentEvents
  #reportSuggestions
}


# Name: createHTMLReport
# Description: Build the HTML report output file
function createHTMLReport
{
  echo "Writing HTML Output to ${reportName}.html"
  htmlPage="<!DOCTYPE html><html><head><title>"
  htmlPage+="Status Report"
  htmlPage+="</title></head>"
  htmlPage+="<style>"
  htmlPage+="#toc { border: 1px solid #aaa; display: table; "
  htmlPage+="margin-bottom: 1em; padding: 20px; width: auto;}"
  htmlPage+="ol, li { list-style: outside none none}"
  htmlPage+="table, th, td { border: 1px solid black; border-collapse: collapse;}"
  htmlPage+="th {text-align: left;}"
  htmlPage+="tr:nth-child(even) {background-color: #dddddd;}"
  htmlPage+="h2, h4 { text-align: center; }"
  htmlPage+=".sectionTitle { border: 5px blue; background-color: lightblue;"
  htmlPage+="text-align: center; font-weight: bold;}"
  htmlPage+="</style>"
  htmlPage+="<body>"
  htmlPage+="<h2><p class=\"pageTitle\">Status Report for ${hostName}</p></h2>"
  htmlPage+="<div id=\"toc\"><h4>Contents</h4>"
  htmlPage+="<ol class=\"tocList\">"
  htmlPage+="<li><a href="#BasicInfo">Basic Machine Info</a></li>"
  htmlPage+="<li><a href="#DiskStats">Disk Stats</a></li>"
  htmlPage+="<li><a href="#TopProcsByCPU">Top Processes By CPU</a></li>"
  htmlPage+="<li><a href="#TopProcsByRAM">Top Processes By RAM</a></li>"
  htmlPage+="<li><a href="#DockerStats">Docker Stats</a></li>"
  htmlPage+="<li><a href="#PackageChanges">Package Changes</a></li>"
  htmlPage+="<li><a href="#RecentUsers">Recent Users</a></li>"
  htmlPage+="<li><a href="#SysLog">Sys Logs</a></li>"
  htmlPage+="</ol></div>"
  htmlPage+="<div id=\"BasicInfo\"><p class=\"sectionTitle\">Basic Hardware Info</p>"
  htmlPage+="$hwBasicsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"DiskStats\"><p class=\"sectionTitle\">Disk Stats</p>"
  htmlPage+="$diskStatsHTML"
  htmlPage+="<p><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"TopProcsByCPU\"><p class=\"sectionTitle\">Top Processes By CPU</p>"
  htmlPage+="$topProcsByCPUHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"TopProcsByRAM\"><p class=\"sectionTitle\">Top Processes By RAM</p>"
  htmlPage+="$topProcsByRAMHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"DockerStats\"><p class=\"sectionTitle\">Docker Stats</p>"
  htmlPage+="$dockerStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"PackageChanges\"><p class=\"sectionTitle\">Package Changes</p>"
  htmlPage+="$packageChangeStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  htmlPage+="<div id=\"RecentUsers\"><p class=\"sectionTitle\">Recent Users</p>"
  htmlPage+="$recentUserStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  #htmlPage+="$anomalousStatsHTML"
  htmlPage+="<div id=\"SysLog\"><p class=\"sectionTitle\">Syslog</p>"
  htmlPage+="$syslogStatsHTML"
  htmlPage+="<p class=\"backToTop\"><a href="#toc">Back to Top</a></p>"
  htmlPage+="</div>"
  #htmlPage+="$suggestionsHTML"
  htmlPage+="</body></html>"
  echo $htmlPage >./${reportName}.html
}

# Name: createTextReport
# Parameters: 
# Description: Build the Text report output file
function createTextReport
{
  echo "Writing Text Output to ${reportName}.txt"
  textOut="${NL}${NL}${reportLabelDivider} ${hostName} Status Report ${reportLabelDivider}${NL}"
#hwBasicsText=""
#topProcStatsText=""
#diskStatsText=""
#dockerStatsText=""
#packageChangeStatsText=""
#recentUserStatsText=""
#anomalousStatsText=""
#syslogStatsText=""
#suggestionsText=""
#footerText=""
  echo $textOut >./${reportName}.txt
}

# Trap ctrl + c 
trap ctrl_c INT
function ctrl_c() 
{
  printf "\n\nctrl-c received. Exiting\n"
  exit
}

#First, check that we have sudo permissions so we can gather the info we need.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root/sudo"
  exit
fi

#Run the sys info gathering functions
gatherInfo

if (( $HTMLOutput != 0 )); then
  createHTMLReport
fi

if (( $TextOutput != 0 )); then
  createTextReport
fi

