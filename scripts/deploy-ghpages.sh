#!/bin/bash
set -e

pwd
remote=$(git config remote.origin.url)

git config --global user.email "$GH_EMAIL"
git config --global user.name "$GH_NAME"
git checkout "$TARGET_BRANCH"
git merge "$SOURCE_BRANCH"
git add -A
git commit -m "CircleCI Deployment" > /dev/null 2>&1
git push origin "$TARGET_BRANCH"

echo "Deployment complete!"
