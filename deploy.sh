#!/usr/bin/env bash 
jekyll build

git add .
git commit -m "Update"
git push