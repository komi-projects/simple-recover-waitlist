#!/usr/bin/env bash
# SimpleRecover Waitlist — Deployment Script
# Works with: GitHub Pages, Netlify, Vercel, Railway, Render, VPS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="simplerecover-waitlist"

# ───────────────────────────────────────────────
# Colors
# ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ───────────────────────────────────────────────
# Helpers
# ───────────────────────────────────────────────
log() { echo -e "${BLUE}[deploy]${NC} $1"; }
success() { echo -e "${GREEN}[deploy]${NC} $1"; }
warn() { echo -e "${YELLOW}[deploy]${NC} $1"; }
error() { echo -e "${RED}[deploy]${NC} $1"; }

# ───────────────────────────────────────────────
# Menu
# ───────────────────────────────────────────────
show_menu() {
  echo ""
  echo "SimpleRecover Waitlist — Deploy"
  echo "==============================="
  echo ""
  echo "1) GitHub Pages (static frontend only)"
  echo "2) Netlify (static frontend only)"
  echo "3) Vercel (static frontend only)"
  echo "4) Railway / Render / VPS (fullstack + API)"
  echo "5) Local preview"
  echo "6) Exit"
  echo ""
}

# ───────────────────────────────────────────────
# GitHub Pages
# ───────────────────────────────────────────────
deploy_github_pages() {
  log "Preparing GitHub Pages deployment..."

  if ! command -v git &> /dev/null; then
    error "Git not found. Install it first."
    exit 1
  fi

  cd "$SCRIPT_DIR"

  # Check if already a git repo
  if [ ! -d .git ]; then
    warn "Not a git repo. Initialize? (y/n)"
    read -r ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      git init
      git branch -M main
    else
      error "Git repo required for GitHub Pages."
      exit 1
    fi
  fi

  # The backend won't work on GitHub Pages (static only)
  # For API, use a separate hosted backend or serverless function
  warn "GitHub Pages only serves static files."
  warn "The waitlist API needs a separate backend host (Railway/Render)."
  warn "Update API_URL in index.html before deploying."

  # Stage everything
  git add index.html waitlist.json README.md 2>/dev/null || true

  # Check for remote
  if ! git remote get-url origin &> /dev/null; then
    warn "No remote configured. Add one:"
    echo "  git remote add origin https://github.com/YOURNAME/simplerecover-waitlist.git"
    exit 1
  fi

  git commit -m "Deploy waitlist $(date +%Y-%m-%d)" || true
  git push origin main

  success "Pushed to GitHub. Enable Pages in repo settings → Pages → main branch."
  success "Live URL will be: https://YOURNAME.github.io/simplerecover-waitlist"
}

# ───────────────────────────────────────────────
# Netlify
# ───────────────────────────────────────────────
deploy_netlify() {
  log "Preparing Netlify deployment..."

  if ! command -v netlify &> /dev/null; then
    warn "Netlify CLI not found. Install: npm install -g netlify-cli"
    exit 1
  fi

  cd "$SCRIPT_DIR"

  # Netlify also static-only on free tier without functions
  warn "For full API on Netlify, use Netlify Functions (serverless)."
  warn "The current setup is static frontend only."

  netlify deploy --prod --dir .

  success "Deployed to Netlify!"
}

# ───────────────────────────────────────────────
# Vercel
# ───────────────────────────────────────────────
deploy_vercel() {
  log "Preparing Vercel deployment..."

  if ! command -v vercel &> /dev/null; then
    warn "Vercel CLI not found. Install: npm install -g vercel"
    exit 1
  fi

  cd "$SCRIPT_DIR"

  # Vercel supports serverless via api/ directory
  warn "For API routes, add Express as Vercel serverless functions."

  vercel --prod

  success "Deployed to Vercel!"
}

# ───────────────────────────────────────────────
# Railway / Render / VPS (Fullstack)
# ───────────────────────────────────────────────
deploy_fullstack() {
  log "Fullstack deployment options:"
  echo ""
  echo "A) Railway (easiest)"
  echo "   1. Push to GitHub"
  echo "   2. Import repo at railway.app"
  echo "   3. Add environment variable: PORT=3000"
  echo "   4. Deploy"
  echo ""
  echo "B) Render"
  echo "   1. Push to GitHub"
  echo "   2. New Web Service at render.com"
  echo "   3. Build: npm install && node waitlist-backend.js"
  echo "   4. Deploy"
  echo ""
  echo "C) VPS / Server"
  echo "   1. SCP files to server"
  echo "   2. Install Node.js, run: node waitlist-backend.js"
  echo "   3. Use PM2 or systemd for persistence"
  echo "   4. Nginx reverse proxy + SSL (Let's Encrypt)"
  echo ""

  # Generate a simple Dockerfile for convenience
  cat > "$SCRIPT_DIR/Dockerfile" << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY waitlist-backend.js package.json waitlist.json ./
RUN npm install express cors
EXPOSE 3000
CMD ["node", "waitlist-backend.js"]
EOF

  success "Generated Dockerfile for containerized deployment."
  warn "Don't forget to update API_URL in index.html to point to your backend!"
}

# ───────────────────────────────────────────────
# Local Preview
# ───────────────────────────────────────────────
run_local() {
  log "Starting local server..."

  cd "$SCRIPT_DIR"

  # Check if node_modules exists
  if [ ! -d node_modules ]; then
    log "Installing dependencies..."
    npm init -y &>/dev/null || true
    npm install express cors &>/dev/null || true
  fi

  # Quick check for modules
  if [ ! -d node_modules/express ]; then
    npm install express cors
  fi

  success "Server starting at http://localhost:3000"
  node waitlist-backend.js
}

# ───────────────────────────────────────────────
# Package.json (if not exists)
# ───────────────────────────────────────────────
generate_package_json() {
  if [ ! -f "$SCRIPT_DIR/package.json" ]; then
    cat > "$SCRIPT_DIR/package.json" << 'EOF'
{
  "name": "simplerecover-waitlist",
  "version": "1.0.0",
  "description": "Waitlist capture for SimpleRecover",
  "main": "waitlist-backend.js",
  "scripts": {
    "start": "node waitlist-backend.js",
    "dev": "node waitlist-backend.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  }
}
EOF
    log "Generated package.json"
  fi
}

# ───────────────────────────────────────────────
# Main
# ───────────────────────────────────────────────
main() {
  generate_package_json

  if [ "$1" == "local" ]; then
    run_local
    exit 0
  fi

  show_menu

  read -rp "Choose option [1-6]: " choice

  case $choice in
    1) deploy_github_pages ;;
    2) deploy_netlify ;;
    3) deploy_vercel ;;
    4) deploy_fullstack ;;
    5) run_local ;;
    6) exit 0 ;;
    *) error "Invalid option." ;;
  esac
}

main "$@"
