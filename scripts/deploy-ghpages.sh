#!/bin/bash

set -e

pwd
remote=$(git config remote.origin.url)

mkdir gh-pages-branch
cd gh-pages-branch

git config --global user.email "$GH_EMAIL"
git config --global user.name "$GH_NAME"
git init
git remote add --fetch origin "$remote"

if git rev-parse --verify origin/gh-pages
then
  git checkout gh-pages
  git rm -rf .
else
  git checkout --orphan gh-pages
fi

git add -A
git commit --allow-empty -m "Deploy to GitHub pages"
git push --force --quiet origin gh-pages
cd ..
rm -rf gh-pages-branch

echo "Finished Deployment!"
