#!/bin/bash
set -euo pipefail

# Download the unreal-engine.version file from the GDK repo so we can run the example project builds on the same versions the GDK was run against
# This is not the pinnacle of engineering, as we rely on GitHub's web interface to download the file, but it seems like GitHub disallows git archive
# which would be our other option for downloading a single file
GDK_BRANCH_LOCAL="${GDK_BRANCH:-master}"
NUMBER_OF_TRIES=0
while [ $NUMBER_OF_TRIES -lt 5 ]; do
    CURL_TIMEOUT=$((10<<NUMBER_OF_TRIES))
    NUMBER_OF_TRIES=$((NUMBER_OF_TRIES+1))
    echo "Trying to download unreal-engine.version from GitHub's UnrealGDK repository, try: $NUMBER_OF_TRIES, timeout: $CURL_TIMEOUT seconds ..."
    curl -L -m $CURL_TIMEOUT https://raw.githubusercontent.com/spatialos/UnrealGDK/$GDK_BRANCH_LOCAL/ci/unreal-engine.version -o ci/unreal-engine.version
    if [ $? -eq 0 ]; then
        break
    fi
done

# This script generates BuildKite steps for each engine version we want to test against.
# We retrieve these engine versions from the unreal-engine.version file in the UnrealGDK repository.
# The steps are based on the template in nightly.template.steps.yaml.

# Default to only testing the first version listed in the unreal-engine.version file
MAXIMUM_ENGINE_VERSION_COUNT_LOCAL="${MAXIMUM_ENGINE_VERSION_COUNT:-1}"
if [ -z "${ENGINE_VERSION}" ]; then 
    echo "Generating build steps for the first ${MAXIMUM_ENGINE_VERSION_COUNT_LOCAL} engine versions listed in unreal-engine.version"
    STEP_NUMBER=1
    IFS=$'\n'
    for commit_hash in $(cat < ci/unreal-engine.version); do
        if ((STEP_NUMBER > MAXIMUM_ENGINE_VERSION_COUNT_LOCAL)); then
            break
        fi
        REPLACE_STRING="s|ENGINE_COMMIT_HASH_PLACEHOLDER|$commit_hash|g; s|STEP_NUMBER_PLACEHOLDER|$STEP_NUMBER|g"
        sed $REPLACE_STRING ci/nightly.template.steps.yaml | buildkite-agent pipeline upload
        STEP_NUMBER=$((STEP_NUMBER+1))
    done
    # We generate one build step for each engine version, which is one line in the unreal-engine.version file.
    # The number of engine versions we are dealing with is therefore the counting variable from the above loop minus one.
    STEP_NUMBER=$((STEP_NUMBER-1))
    buildkite-agent meta-data set "engine-version-count" "$STEP_NUMBER"
else
    echo "Generating steps for the specified engine version: $ENGINE_VERSION" 
    sed "s|ENGINE_COMMIT_HASH_PLACEHOLDER|$ENGINE_VERSION|g" ci/nightly.template.steps.yaml | buildkite-agent pipeline upload
fi