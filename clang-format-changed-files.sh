#!/usr/bin/env bash

# This script runs clang_format on all .h, .m, and .mm files that have changes from develop branch.
# Before running this, ensure that your local develop branch is up to date.
git fetch
i=0
for modified_file in $(git diff origin/develop --name-only *.h *.m *.mm)
do 
  clang-format -i -style=file $modified_file
  exit_code=$?
  if [ $exit_code -ne 0 ]
  then
    echo "Failed to format file: "$modified_file
  else
    ((i++))
  fi
done
echo "Formatted "$i" file(s)."
