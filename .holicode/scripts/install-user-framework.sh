#!/bin/bash
# Install HoliCode framework for user

set -e

HOLICODE_VERSION="v0.0.1"
INSTALL_DIR="$HOME/.holicode"
WORKFLOWS_DIR="$HOME/.clinerules/workflows"  # Adjust based on agent
GLOBAL_RULES_DIR="$HOME/Documents/Cline/Rules"  # Adjust based on agent

echo "🚀 Installing HoliCode Framework ${HOLICODE_VERSION} for user..."

# Create directories
mkdir -p "$INSTALL_DIR" "$WORKFLOWS_DIR" "$GLOBAL_RULES_DIR"

# Copy workflows (assuming we're in framework repo)
if [ -d "workflows" ]; then
    cp -r workflows/* "$WORKFLOWS_DIR/"
    echo "✅ Workflows installed to $WORKFLOWS_DIR"
else
    echo "❌ No workflows directory found. Are you in the framework repository?"
    exit 1
fi

# Copy templates (they go with workflows)
if [ -d "templates" ]; then
    cp -r templates "$WORKFLOWS_DIR/"
    echo "✅ Templates installed to $WORKFLOWS_DIR/templates"
fi

# Install global rules
if [ -f "holicode.md" ]; then
    cp holicode.md "$GLOBAL_RULES_DIR/"
    echo "✅ Global instructions installed to $GLOBAL_RULES_DIR/holicode.md"
fi

# Create environment setup
echo "export HOLICODE_WORKFLOWS_PATH=\"$WORKFLOWS_DIR\"" >> "$HOME/.bashrc"

echo "✅ HoliCode Framework installed successfully!"
echo ""
echo "📝 Workflows available at: $WORKFLOWS_DIR"
echo "📖 Global instructions at: $GLOBAL_RULES_DIR/holicode.md"
echo ""
echo "Next steps:"
echo "1. Restart your terminal or run: source ~/.bashrc"
echo "2. Initialize a project: /state-init"
echo "3. Test installation: /state-health-check"
