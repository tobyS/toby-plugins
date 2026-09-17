#!/bin/bash

# tsf environment contract: env_up (mandatory)
#
# Usage: env_up.sh
#
# Bring the environment up for the current checkout. For the factory's checkout
# this is typically services only (database, cache), not the application
# servers, unless a step needs a running app. It runs in every
# implementation-flavored cycle, so it must be idempotent: an environment that
# is already up is a no-op.
#
# If the factory's checkout shares a machine with your own working copy, fixed
# service ports collide: allocate ports per checkout here (or run the factory
# only while your own environment is down).
#
# This skeleton was copied by /tsf:init and is now yours.
# Exit 0 when the environment is up; non-zero otherwise.

set -e

# TODO: start the project's services, e.g. your compose / devenv / service
# manager command. A project without services keeps the plain exit 0.

exit 0
