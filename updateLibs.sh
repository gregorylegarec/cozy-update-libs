# #!/bin/bash

# Yarn does not handle well version ranges before 1.0.0.
# As we need it to update well both cozy-konnector-libs v2 and v3 we need to
# check for the correct yarn version.
yarnVersion=($(yarn --version))
if [[ "$yarnVersion" < "1.0.0" ]]; then
    echo "Yarn version must be 1.0.0 or higher"
    exit 1
fi

rm -rf ./konnectors_updates/* && rmdir konnectors_updates && mkdir konnectors_updates

function getGitRepository {
    # Get something like git://github.com/cozy/cozy-konnector-lambda and build
    IFS='#' read -r -a repoAndBranch <<< "$1"
    # Get something like git and github.com and then cozy and then cozy-konnector-lambda
    IFS='://' read -r -a protocolAndSegments <<< "${repoAndBranch[0]}"
    # Get something like git and gitlab.cozycloud.cc or just github.com
    IFS='@' read -r -a userAndDomain <<< "${protocolAndSegments[3]}"

    # Wait, do we have a user at first index, so two indexes ?
    domainSegmentIndex=0
    if [ "${#userAndDomain[@]}" = 2 ]; then
      # Ok give the segment ad index 1 instead.
      domainSegmentIndex=1
    fi

    # OK let specify our user
    gitRepo="git@${userAndDomain[$domainSegmentIndex]}:"

    # And reconstruct the whole URL.
    for i in "${!protocolAndSegments[@]}"; do
      if [ "$i" -ge 4 ]; then
        gitRepo="$gitRepo${protocolAndSegments[$i]}/"
      fi
    done

    # Don't forget to strip last slash of course.
    gitRepo=${gitRepo%?}

    echo "$gitRepo"
}

function updateAndPush() {
    # Specifiy version in yarn upgrade command otherwise package.json is not updated (New from yarn 1.0.0)
    targetVersion=($(yarn outdated --json cozy-konnector-libs | jq -r '. | .data.body[] | .[2]'))

    if [ "${targetVersion}" = "" ]; then
        echo "⬆️ UpdateLibs: Error for konnector $1, cannot read version."
        # Log skipped konnector
        echo " ❌ $1 (cannot read version)" >&3
    else
        echo "⬆️ UpdateLibs: Target version for $1 is ${targetVersion}, upgrading."

        yarn upgrade cozy-konnector-libs@^${targetVersion}
        echo "⬆️ UpdateLibs: Commiting and pushing changes for konnector $1."
        git add -A && git commit -m "chore: update cozy-konnector-libs to $targetVersion :arrow_up:"
        git push origin && echo " ✅ $1 (v${targetVersion})" >&3 || echo " ❌ $1 (error while pushing to origin)" >&3
    fi
}

# Logging konnectors which may be skipped
exec 3<> konnector-libs-update.log
while read -r konnector ; do
    source=($(echo ${konnector} | jq -r '. | .source'))
    slug=($(echo ${konnector} | jq -r '. | .slug'))
    name="$(echo ${konnector} | jq -r '. | .name')"

    # Clean our repo
    repo=$(getGitRepository $source)

    # Clone them
    echo "⬆️ UpdateLibs: cloning $repo"
    git clone $repo konnectors_updates/$slug

    (cd konnectors_updates/$slug && updateAndPush "${name}")
done < <(jq -rc '.[] | {slug: .slug, source: .source, name: .name}' $1)

# Close file descriptor for skipped konnectors
exec 3>&-

rm -rf ./konnectors_updates/* && rmdir ./konnectors_updates
echo "⬆️ UpdateLibs: Done."

if [ -e konnector-libs-update.log ] && [ -s konnector-libs-update.log ]; then
    echo "⬆️ UpdateLibs: Results:"
    cat konnector-libs-update.log
    rm konnector-libs-update.log
    echo "Be sure to update skipped konnectors manually."
    echo ""
fi
