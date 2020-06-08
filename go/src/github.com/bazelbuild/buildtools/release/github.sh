#!/usr/bin/env bash

set -e

if [ -z "$GITHUB_ACCESS_TOKEN" ]
then
    echo "Create a Github auth token at https://github.com/settings/tokens and set it as \$GITHUB_ACCESS_TOKEN"
    exit 1
fi

TAG="$(git describe --abbrev=0 --tags | sed 's/* //')"
DATE="$(date +"%Y-%m-%d")"
NAME="Release $TAG ($DATE)"

GH_REPO="repos/bazelbuild/buildtools"
GH_AUTH_HEADER="Authorization: token $GITHUB_ACCESS_TOKEN"

bazel build --config=release //buildifier:all //buildozer:all //unused_deps:all

echo "Creating a draft release"
API_JSON="{\"tag_name\": \"$TAG\", \"target_commitish\": \"master\", \"name\": \"$NAME\", \"draft\": true}"
RESPONSE=$(curl -s --show-error -H "$GH_AUTH_HEADER" --data "$API_JSON" "https://api.github.com/$GH_REPO/releases")
RELEASE_ID=$(echo $RESPONSE | jq -r '.id')
RELEASE_URL=$(echo $RESPONSE | jq -r '.html_url')

upload_file() {
    echo "Uploading $2"
    ASSET="https://uploads.github.com/$GH_REPO/releases/$RELEASE_ID/assets?name=$2"
    curl --data-binary @"$1" -s --show-error -o /dev/null -H "$GH_AUTH_HEADER" -H "Content-Type: application/octet-stream" $ASSET
}

for tool in "buildifier" "buildozer" "unused_deps"; do
  upload_file "bazel-bin/$tool/$tool-linux_amd64" "$tool"
  upload_file "bazel-bin/$tool/$tool-windows_amd64.exe" "$tool.exe"
  upload_file "bazel-bin/$tool/$tool-darwin_amd64" "$tool.mac"
done

echo "The draft release is available at $RELEASE_URL"