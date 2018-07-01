#!/bin/bash
set -e

pwd
remote=$(git config remote.origin.url)

git config --global user.name "$GH_NAME"
git config --global user.email "$GH_EMAIL"
git checkout "$TARGET_BRANCH"
git merge "$SOURCE_BRANCH" -m "CircleCI merging \'$SOURCE_BRANCH\' into \'$TARGET_BRANCH\'"
bundle install
bundle exec jekyll build
git add --force -A
git push origin "$TARGET_BRANCH"

echo "Deployment complete!"
