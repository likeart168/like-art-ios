#!/bin/bash
set -euo pipefail
{
  echo "Run: https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
  echo "SHA: $GITHUB_SHA"
  echo "Build number: ${BUILD_NUMBER:-NOT_BUILT}"
  echo "Build status before evidence publication: $BUILD_STATUS"
  echo "ASC step outcome: $ASC_OUTCOME"
  if [ -f build-b2/evidence/asc-upload-status.txt ]; then cat build-b2/evidence/asc-upload-status.txt; fi
} | tee build-b2/evidence/summary.txt
cat build-b2/evidence/summary.txt >> "$GITHUB_STEP_SUMMARY"
