#!/bin/bash

# update.sh
#
# A script to sync workflows, skills, templates, config, and helper scripts from the
# central HoliCode framework repository into the current project's structure.
#
# Workflows are synced to .clinerules/workflows/ for Cline execution.
# Skills are synced to .clinerules/skills/ and linked into supported agent paths.
# Templates and helper scripts are synced to .holicode/ for project context.
# Existing .holicode/state/WORK_SPEC.md is preserved when present.

# --- Configuration ---
# The name of the directory for contextual/data parts of the framework.
HOLICODE_DATA_DIR=".holicode"
# The name of the directory for executable workflows.
WORKFLOW_TARGET_DIR=".clinerules/workflows"
# The name of the directory for reusable agent skills.
SKILLS_TARGET_DIR=".clinerules/skills"
# The name of the directory for framework-level config.
CONFIG_TARGET_DIR=".clinerules/config"
# Target for skills symlinks from agent-specific directories.
SKILLS_LINK_TARGET="../.clinerules/skills"
# Agent skill discovery symlink paths.
SKILLS_LINK_PATHS=(
  ".claude/skills"
  ".agents/skills"
  ".opencode/skills"
  ".gemini/skills"
)

# --- Pre-flight Checks ---

# Check if a source path was provided
if [ -z "$1" ]; then
  echo "❌ ERROR: You must provide the path to your source HoliCode framework repository."
  echo "   Usage: ./scripts/update.sh /path/to/your/holicode-framework-repo"
  exit 1
fi

FRAMEWORK_SOURCE_PATH=$1

# Check if the source directory exists
if [ ! -d "$FRAMEWORK_SOURCE_PATH" ]; then
  echo "❌ ERROR: Source directory not found at '$FRAMEWORK_SOURCE_PATH'"
  exit 1
fi

# --- Main Sync Logic ---

echo "🚀 Starting HoliCode framework sync..."
echo "   Source: $FRAMEWORK_SOURCE_PATH"
echo "   Target Directories: $(pwd)/$WORKFLOW_TARGET_DIR, $(pwd)/$SKILLS_TARGET_DIR, $(pwd)/$CONFIG_TARGET_DIR and $(pwd)/$HOLICODE_DATA_DIR"

if [ -f ".clinerules" ]; then
  echo "❌ ERROR: '.clinerules' exists as a file in this project."
  echo "   This script requires '.clinerules/' directory layout."
  echo "   Please rename or remove '.clinerules' file and re-run update.sh."
  exit 1
fi

# Create target directories if they don't exist
mkdir -p "$WORKFLOW_TARGET_DIR"
mkdir -p "$SKILLS_TARGET_DIR"
mkdir -p "$CONFIG_TARGET_DIR"
mkdir -p "$HOLICODE_DATA_DIR/templates"
mkdir -p "$HOLICODE_DATA_DIR/specs"
mkdir -p "$HOLICODE_DATA_DIR/scripts"

# Use rsync to efficiently sync directories.
# -a: archive mode (preserves permissions, etc.)
# -v: verbose (shows what's being copied)
# --delete: removes files from the target that are no longer in the source

echo "\n🔄 Syncing claude-code/opencode files to project"
rsync -av "$FRAMEWORK_SOURCE_PATH/agent-boot/" "$WORKFLOW_TARGET_DIR/../../"

echo "\n🔄 Syncing workflows to $WORKFLOW_TARGET_DIR..."
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/workflows/" "$WORKFLOW_TARGET_DIR/"
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/holicode.md" "$WORKFLOW_TARGET_DIR/../"

echo "\n🔄 Syncing skills to $SKILLS_TARGET_DIR..."
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/skills/" "$SKILLS_TARGET_DIR/"

echo "\n🔄 Syncing framework config to $CONFIG_TARGET_DIR..."
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/config/" "$CONFIG_TARGET_DIR/"

echo "\n🔗 Linking skills into agent discovery paths..."
for link_path in "${SKILLS_LINK_PATHS[@]}"; do
  mkdir -p "$(dirname "$link_path")"

  if [ -L "$link_path" ]; then
    rm "$link_path"
  fi

  if [ -e "$link_path" ]; then
    echo "⚠️  Skipping symlink: $link_path exists and is not a symlink."
    echo "   Move/remove it manually, then run update.sh again to create the link."
    continue
  fi

  ln -s "$SKILLS_LINK_TARGET" "$link_path"
done

echo "\n🔄 Syncing templates to $HOLICODE_DATA_DIR/templates..."
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/templates/" "$HOLICODE_DATA_DIR/templates/"

echo "\n🔄 Syncing templates to $HOLICODE_DATA_DIR/specs..."
rsync -av --exclude "WORK_SPEC.md" "$FRAMEWORK_SOURCE_PATH/specs/" "$HOLICODE_DATA_DIR/specs/"

SOURCE_WORK_SPEC="$FRAMEWORK_SOURCE_PATH/specs/WORK_SPEC.md"
TARGET_WORK_SPEC="$HOLICODE_DATA_DIR/state/WORK_SPEC.md"
TARGET_WORK_SPEC_UPDATED_TEMPLATE="$HOLICODE_DATA_DIR/state/WORK_SPEC_UPDATED_TEMPLATE.md"

if [ -f "$SOURCE_WORK_SPEC" ]; then
  if [ -f "$TARGET_WORK_SPEC" ]; then
    echo "\n🛡️  Preserving existing $TARGET_WORK_SPEC"
    echo "🔄 Writing updated framework template to $TARGET_WORK_SPEC_UPDATED_TEMPLATE"
    rsync -av "$SOURCE_WORK_SPEC" "$TARGET_WORK_SPEC_UPDATED_TEMPLATE"
  else
    echo "\n🆕 No existing $TARGET_WORK_SPEC found. Installing framework WORK_SPEC.md"
    rsync -av "$SOURCE_WORK_SPEC" "$TARGET_WORK_SPEC"
  fi
fi

echo "\n🔄 Syncing scripts to $HOLICODE_DATA_DIR/scripts..."
rsync -av --delete "$FRAMEWORK_SOURCE_PATH/scripts/" "$HOLICODE_DATA_DIR/scripts/"

echo "\n🔄 Syncing documentation templates to docs/..."
if [ -d "$FRAMEWORK_SOURCE_PATH/docs-templates" ]; then
    rsync -av --delete "$FRAMEWORK_SOURCE_PATH/docs-templates/" "docs/"
fi

echo "\n✅ Sync complete. Your project's HoliCode framework is up to date."
