#!/bin/bash
#
# This is a short script to extract the Memory Monitor lines from an appserver
#   log and turn all of the useful metrics into comma separated columns.  This
#   is handy for feeding analysis spreadsheets.
#
#  TODO: recognize config vs. job server logs and adjust columns so there are 
#    blank columns in config logs where WIT entries are in job server logs, so
#    same analysis tables can be used for both in Excel.
#
# 7/21/2020, Sean Berry
#
for file in $*
do
  echo "Processing $file"
  cat "$file" | grep "Memory Monitor" | sed 's:,...]:,:' | sed 's: \[.*\] ::' | tr '/' ',' | tr ':' ',' > "$file.csv"
done

