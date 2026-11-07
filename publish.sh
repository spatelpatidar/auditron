#!/bin/sh
# -----------------------------------------------------------------------------
# publish.sh — Publish pipeline for Auditron (Mac / Linux / Git Bash)
# Usage: sh publish.sh
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Colors (printf is used instead of `echo -e` so this also works under dash)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

say() { printf '%b\n' "$1"; }

say "${BLUE}============================================================${NC}"
say "${BLUE}   Starting Automated Publish Pipeline for Auditron${NC}"
say "${BLUE}============================================================${NC}"

# 1. Clean old builds
say "\n${BLUE}Step 1: Cleaning old gem files...${NC}"
bundle exec rake publish:clean

# 2. RuboCop
say "\n${BLUE}Step 2: Running RuboCop...${NC}"
if bundle exec rake publish:lint; then
  say "${GREEN}✅ RuboCop passed!${NC}"
else
  say "${RED}❌ RuboCop failed. Aborting.${NC}"
  exit 1
fi

# 3. Run Specs
say "\n${BLUE}Step 3: Running RSpec suite...${NC}"
if bundle exec rake publish:spec; then
  say "${GREEN}✅ Specs passed!${NC}"
else
  say "${RED}❌ Specs failed. Aborting.${NC}"
  exit 1
fi

# 4. Build Gem
say "\n${BLUE}Step 4: Building Gem...${NC}"
bundle exec rake publish:build

# 5. Push to RubyGems (you will be asked for your MFA/OTP code)
say "\n${BLUE}Step 5: Pushing to RubyGems...${NC}"
# Only push if the gem file was actually created
if ls ./*.gem >/dev/null 2>&1; then
  bundle exec rake publish:push
else
  say "${RED}❌ Gem file not found. Build might have failed.${NC}"
  exit 1
fi

say "\n${GREEN}============================================================${NC}"
say "${GREEN}🎉 Automation Complete! Auditron is now live on RubyGems.org${NC}"
say "${GREEN}============================================================${NC}"