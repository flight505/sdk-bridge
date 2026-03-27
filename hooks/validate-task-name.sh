#!/bin/bash
# TaskCreated hook — validates task naming follows [US-XXX]: format
# Exit 0: allow creation
# Exit 2: block creation, stderr sent as feedback
set -e

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')

# Skip validation if no subject
if [ -z "$TASK_SUBJECT" ]; then
  exit 0
fi

# Validate [US-XXX]: format
if [[ ! "$TASK_SUBJECT" =~ ^\[US-[0-9]+\]:\ .+ ]]; then
  echo "Task subject must follow format: [US-XXX]: Story Title (e.g., '[US-001]: Add status field')" >&2
  exit 2
fi

exit 0
