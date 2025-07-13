#!/bin/bash

echo "🚀 Setting up GitHub for automatic builds..."
echo ""
echo "Steps:"
echo "1. Create a new GitHub repository"
echo "2. Push this code:"
echo ""
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/YOUR_USERNAME/microverse.git"
echo "   git push -u origin main"
echo ""
echo "3. GitHub Actions will automatically build the app"
echo "4. Download the build from Actions > Latest workflow > Artifacts"
echo ""
echo "The .github/workflows/build.yml is already configured!"
echo ""
echo "Would you like me to create a git repository now? (y/n)"
read -p "> " answer

if [ "$answer" = "y" ]; then
    git init
    git add .
    git commit -m "Initial commit - Microverse Battery Manager"
    echo ""
    echo "✅ Repository created!"
    echo ""
    echo "Next: Create a repo on GitHub and run:"
    echo "git remote add origin YOUR_GITHUB_URL"
    echo "git push -u origin main"
fi