#!/bin/bash

# tsf environment contract: env_reset (mandatory)
#
# Usage: env_reset.sh
#
# Return the environment to a clean baseline for the current branch: reset or
# re-seed the database, re-run migrations from baseline. It runs on ticket
# switch, not every cycle, so consecutive cycles on one ticket keep a warm
# environment.
#
# If your verification suite manages its own state (e.g. every test run builds
# a fresh database), keep this script anyway and let it only record that fact:
# the factory then never has to guess whether a reset is missing or unneeded.
#
# This skeleton was copied by /tsf:init and is now yours.
# Exit 0 when the baseline is restored; non-zero otherwise.

set -e

# TODO: reset the project's state, e.g. drop, migrate and seed the database.
# Suite manages its own state? Replace this comment with one saying so and keep
# the exit 0.

exit 0
