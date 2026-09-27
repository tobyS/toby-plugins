#!/bin/bash

# tsf environment contract: verify (mandatory)
#
# Usage: verify.sh
#
# Run the project's verification suite -- lint, types, tests -- exactly as CI
# runs it. The exit code is the verdict: it is the precondition for every
# verification gate, and what the factory's verification fix step makes green.
#
# "Exactly as CI runs it" is load-bearing, not advice: when a required check is
# already green on the commit the branch is on, the factory takes that as this
# script's answer instead of running it again. If this script and CI verify
# different things, that shortcut makes the factory trust the wrong one.
#
# This skeleton was copied by /tsf:init and is now yours. Until you replace the
# body it fails on purpose: a skeleton must never report green.

set -e

# TODO: run the same command your CI runs, e.g. `exec <your verify command>`.

echo "verify: not configured -- edit $0" >&2
exit 1
