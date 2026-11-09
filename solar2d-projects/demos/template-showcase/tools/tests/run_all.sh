#!/usr/bin/env bash
# Runs every regression test, the harness selftests, every sample and every Weaver story under the Solar2D stub.
# Usage: tools/tests/run_all.sh (from any directory). Prints one line per failure and a count; exit code 1 on any failure.

set -u

cd "$(dirname "$0")/../.." || exit 2

CHILD_TIMEOUT=120
CHILD_MEMORY_KB=1048576
OUTPUT_LIMIT=1000000

runCount=0
failureCount=0

# Runs one bounded child. expectedStatus 0 means it must pass, 1 that it must fail on purpose.
runCheck() {
	local label=$1
	local expectedStatus=$2
	shift 2

	local output
	local status
	output=$(set -o pipefail; timeout "$CHILD_TIMEOUT" bash -c "ulimit -v $CHILD_MEMORY_KB; exec \"\$@\"" runCheck "$@" 2>&1 | tail -c "$OUTPUT_LIMIT")
	status=$?
	runCount=$((runCount + 1))

	if [ "$status" -eq "$expectedStatus" ]; then
		return
	fi

	failureCount=$((failureCount + 1))

	local reason="exit $status"

	if [ "$status" -eq 124 ]; then
		reason="timed out after ${CHILD_TIMEOUT} s"

	elif [ "$status" -gt 128 ]; then
		reason="killed by signal $((status - 128))"
	fi

	local detail
	detail=$(printf "%s\n" "$output" | grep -m 1 -E "^(FAIL|ERROR)" || printf "%s\n" "$output" | grep -v "^$" | tail -n 1)
	echo "FAIL $label ($reason)${detail:+: $detail}"
}

# Harness selftests: the API scene passes, the leaking and throwing scenes and the broken story must fail.
runCheck "selftest apiScene" 0 lua5.1 tools/harness/run_sample.lua tools.harness.selftest.apiScene
runCheck "selftest leakScene" 1 lua5.1 tools/harness/run_sample.lua tools.harness.selftest.leakScene
runCheck "selftest throwScene" 1 lua5.1 tools/harness/run_sample.lua tools.harness.selftest.throwScene
runCheck "selftest brokenStory" 1 lua5.1 tools/harness/walk_story.lua tools/harness/selftest/brokenStory.json selftest

for sampleDirectory in samples/*/; do
	sampleName=$(basename "$sampleDirectory")
	runCheck "run_sample $sampleName" 0 lua5.1 tools/harness/run_sample.lua "samples.$sampleName.demo"

	if [ -f "samples/$sampleName/data/story.json" ]; then
		runCheck "walk_story $sampleName" 0 lua5.1 tools/harness/walk_story.lua "samples/$sampleName/data/story.json" "$sampleName"
	fi
done

for testFile in tools/tests/*.lua; do
	testName=$(basename "$testFile" .lua)

	case "$testName" in
		platformer-story)
			runCheck "$testName pie" 0 lua5.1 "$testFile" pie
			runCheck "$testName nopie" 0 lua5.1 "$testFile" nopie
			;;

		all-samples-resize)
			for sampleName in $(timeout "$CHILD_TIMEOUT" lua5.1 "$testFile" --list); do
				runCheck "$testName $sampleName" 0 lua5.1 "$testFile" "$sampleName"
			done
			;;

		*)
			runCheck "$testName" 0 lua5.1 "$testFile"
			;;
	esac
done

echo "$((runCount - failureCount))/$runCount checks passed, $failureCount failed"

if [ "$failureCount" -gt 0 ]; then
	exit 1
fi
