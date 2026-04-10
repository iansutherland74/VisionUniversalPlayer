#!/bin/bash
# GitHub Repository Setup & Push Script
# This script helps you create a GitHub remote and push the VisionUniversalPlayer repository

set -e

echo "🚀 VisionUniversalPlayer - GitHub Setup"
echo "========================================"
echo ""

# Step 1: Check prerequisites
echo "✅ Step 1: Check Prerequisites"
if ! command -v git &> /dev/null; then
  echo "❌ Git is not installed"
  exit 1
fi
echo "✅ Git found: $(git --version)"
echo ""

# Step 2: Configure git (optional)
echo "✅ Step 2: Configure Git User (optional)"
read -p "Enter your GitHub username (leave blank to skip): " github_user
read -p "Enter your GitHub email (leave blank to skip): " github_email

if [[ -n "$github_user" ]]; then
  git config user.name "$github_user"
  echo "   ✓ Git user name: $github_user"
fi

if [[ -n "$github_email" ]]; then
  git config user.email "$github_email"
  echo "   ✓ Git user email: $github_email"
fi
echo ""

# Step 3: Verify git status
echo "✅ Step 3: Verify Repository Status"
git_status=$(git status --short | wc -l)
if [ "$git_status" -eq 0 ]; then
  echo "   ✓ Working directory is clean"
else
  echo "   ⚠️  Warning: You have uncommitted changes ($git_status files)"
  echo "      Consider running: git status"
fi
echo ""

# Step 4: Display current git state
echo "✅ Current Repository State:"
echo "   Remote(s): $(git remote -v | wc -l) configured"
git log --oneline -3 | sed 's/^/   - /'
echo ""

# Step 5: Guide for GitHub remote setup
echo "📝 Next Steps to Push to GitHub:"
echo ""
echo "1. Create a new repository on GitHub:"
echo "   → Go to https://github.com/new"
echo "   → Repository name: VisionUniversalPlayer"
echo "   → Description: visionOS spatial media player with hardware decoding"
echo "   → Set to Private or Public as desired"
echo "   → DO NOT initialize with README (we have one)"
echo "   → Click 'Create repository'"
echo ""

echo "2. Add GitHub remote (replace YOUR_USERNAME and REPO_NAME):"
echo "   git remote add origin https://github.com/YOUR_USERNAME/VisionUniversalPlayer.git"
echo "   (or for SSH: git@github.com:YOUR_USERNAME/VisionUniversalPlayer.git)"
echo ""

echo "3. Push to GitHub:"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""

echo "4. GitHub Setting Recommendations:"
echo "   - Settings → General → Default branch: main"
echo "   - Settings → Branch protection rules → Protect main branch"
echo "   - Settings → Code security → Enable Dependabot alerts"
echo ""

# Optional: Interactive setup
read -p "Would you like to add the GitHub remote now? (y/n): " add_remote
if [[ "$add_remote" == "y" ]]; then
  read -p "Enter your GitHub username: " username
  
  git remote add origin "https://github.com/$username/VisionUniversalPlayer.git"
  echo "✅ Remote added: origin → github.com/$username/VisionUniversalPlayer.git"
  
  read -p "Push to GitHub now? (y/n): " do_push
  if [[ "$do_push" == "y" ]]; then
    git branch -M main
    git push -u origin main
    echo "✅ Successfully pushed to GitHub!"
    echo "📍 Repository: https://github.com/$username/VisionUniversalPlayer"
  fi
fi

echo ""
echo "📚 Documentation:"
echo "  - README.md - Project overview and features"
echo "  - BUILD_CONFIGURATION.md - Build setup and configuration"
echo "  - DEBUGGING.md - Troubleshooting guide"
echo "  - FILE_REFERENCE.md - Code API reference"
echo "  - Project repository: git log --oneline"
echo ""
echo "✅ Setup complete!"
