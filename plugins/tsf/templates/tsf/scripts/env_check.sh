#!/bin/bash

# tsf environment contract: env_check (optional)
#
# Usage: env_check.sh
#
# A fast health probe run before implementation: are the services this project
# needs reachable? A failure parks the ticket for a human instead of letting an
# agent flail against a broken stack. Keep it to a few seconds.
#
# This skeleton was copied by /tsf:init and is now yours.
# Exit 0 when the environment is healthy; non-zero otherwise.

set -e

# TODO: probe the services, e.g. a database ping or a health endpoint.

exit 0
