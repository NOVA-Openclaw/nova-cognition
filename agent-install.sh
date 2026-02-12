#!/bin/bash
# nova-cognition agent installer
# Idempotent - safe to run multiple times

set -e

VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use current OS user for both DB user and name
DB_USER="${PGUSER:-$(whoami)}"
DB_NAME="${DB_USER//-/_}_memory"  # Replace hyphens with underscores (nova-staging → nova_staging_memory)
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace-claude-code}"
OPENCLAW_DIR="$HOME/.openclaw"
OPENCLAW_PROJECTS="$OPENCLAW_DIR/projects"
EXTENSIONS_DIR="$OPENCLAW_DIR/extensions"

# Parse arguments
VERIFY_ONLY=0
FORCE_INSTALL=0
DB_NAME_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verify-only)
            VERIFY_ONLY=1
            shift
            ;;
        --force)
            FORCE_INSTALL=1
            shift
            ;;
        --database|-d)
            DB_NAME_OVERRIDE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verify-only         Check installation without modifying anything"
            echo "  --force               Force overwrite existing files"
            echo "  --database, -d NAME   Override database name (default: \${USER}_memory)"
            echo "  --help                Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Use default database name"
            echo "  $0 --database nova_memory       # Use specific database"
            echo "  $0 -d nova_memory               # Short form"
            echo "  $0 --verify-only                # Check installation status"
            echo "  $0 --force                      # Force reinstall"
            echo ""
            echo "Prerequisites:"
            echo "  - Node.js 18+ and npm"
            echo "  - TypeScript (npm install -g typescript)"
            echo "  - PostgreSQL with nova_memory database"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Apply database name override if provided
if [ -n "$DB_NAME_OVERRIDE" ]; then
    DB_NAME="$DB_NAME_OVERRIDE"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status indicators
CHECK_MARK="${GREEN}✅${NC}"
CROSS_MARK="${RED}❌${NC}"
WARNING="${YELLOW}⚠️${NC}"
INFO="${BLUE}ℹ️${NC}"

# Verification results
VERIFICATION_PASSED=0
VERIFICATION_WARNINGS=0
VERIFICATION_ERRORS=0

echo ""
echo "═══════════════════════════════════════════"
if [ $VERIFY_ONLY -eq 1 ]; then
    echo "  nova-cognition verification v${VERSION}"
else
    echo "  nova-cognition installer v${VERSION}"
fi
echo "═══════════════════════════════════════════"
echo ""

# ============================================
# Verification Functions
# ============================================

verify_files() {
    echo "File verification..."
    
    # Check home symlink
    if [ -L "$HOME/nova-cognition" ]; then
        TARGET=$(readlink -f "$HOME/nova-cognition" 2>/dev/null || readlink "$HOME/nova-cognition")
        if [ "$TARGET" = "$SCRIPT_DIR" ]; then
            echo -e "  ${CHECK_MARK} Home symlink correct: ~/nova-cognition → $SCRIPT_DIR"
        else
            echo -e "  ${WARNING} Home symlink points to wrong location: $TARGET"
            echo "      Expected: $SCRIPT_DIR"
            VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
        fi
    elif [ -d "$HOME/nova-cognition" ]; then
        echo -e "  ${WARNING} ~/nova-cognition exists but is not a symlink"
        VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
    else
        echo -e "  ${CROSS_MARK} Home symlink not found: ~/nova-cognition"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
    fi
    
    # Check project symlink
    if [ -L "$OPENCLAW_PROJECTS/nova-cognition" ]; then
        TARGET=$(readlink -f "$OPENCLAW_PROJECTS/nova-cognition" 2>/dev/null || readlink "$OPENCLAW_PROJECTS/nova-cognition")
        if [ "$TARGET" = "$SCRIPT_DIR" ]; then
            echo -e "  ${CHECK_MARK} Project symlink correct: $OPENCLAW_PROJECTS/nova-cognition → $SCRIPT_DIR"
        else
            echo -e "  ${WARNING} Project symlink points to wrong location: $TARGET"
            echo "      Expected: $SCRIPT_DIR"
            VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
        fi
    elif [ -d "$OPENCLAW_PROJECTS/nova-cognition" ]; then
        echo -e "  ${WARNING} $OPENCLAW_PROJECTS/nova-cognition exists but is not a symlink"
        VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
    else
        echo -e "  ${CROSS_MARK} Project not linked to $OPENCLAW_PROJECTS/"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
    fi
    
    # Check agent_chat extension
    if [ -d "$EXTENSIONS_DIR/agent_chat" ]; then
        echo -e "  ${CHECK_MARK} agent_chat extension directory exists"
        
        # Check if TypeScript source files exist
        if [ -f "$EXTENSIONS_DIR/agent_chat/index.ts" ]; then
            echo -e "  ${CHECK_MARK} agent_chat TypeScript source present"
        else
            echo -e "  ${WARNING} agent_chat TypeScript source missing"
            VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
        fi
        
        # Check if build output exists
        if [ -f "$EXTENSIONS_DIR/agent_chat/dist/index.js" ]; then
            echo -e "  ${CHECK_MARK} agent_chat compiled (dist/index.js exists)"
        else
            echo -e "  ${CROSS_MARK} agent_chat not compiled"
            VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
        fi
        
        # Check openclaw.plugin.json
        if [ -f "$EXTENSIONS_DIR/agent_chat/openclaw.plugin.json" ]; then
            if grep -q '"main": "./dist/index.js"' "$EXTENSIONS_DIR/agent_chat/openclaw.plugin.json"; then
                echo -e "  ${CHECK_MARK} openclaw.plugin.json configured correctly"
            else
                echo -e "  ${WARNING} openclaw.plugin.json may need 'main' field update"
                VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
            fi
        else
            echo -e "  ${CROSS_MARK} openclaw.plugin.json not found"
            VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
        fi
        
        # Check node_modules
        if [ -d "$EXTENSIONS_DIR/agent_chat/node_modules" ]; then
            echo -e "  ${CHECK_MARK} agent_chat npm dependencies installed"
        else
            echo -e "  ${WARNING} agent_chat npm dependencies not installed"
            VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
        fi
    else
        echo -e "  ${CROSS_MARK} agent_chat extension not installed"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
    fi
    
    # Check skills
    local skills=("agent-chat" "agent-spawn")
    for skill in "${skills[@]}"; do
        if [ -L "$WORKSPACE/skills/$skill" ]; then
            TARGET=$(readlink -f "$WORKSPACE/skills/$skill" 2>/dev/null || readlink "$WORKSPACE/skills/$skill")
            EXPECTED="$SCRIPT_DIR/focus/skills/$skill"
            if [ "$TARGET" = "$EXPECTED" ]; then
                echo -e "  ${CHECK_MARK} Skill symlink correct: $skill"
            else
                echo -e "  ${WARNING} Skill symlink points to wrong location: $TARGET"
                VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
            fi
        elif [ -d "$WORKSPACE/skills/$skill" ]; then
            echo -e "  ${WARNING} $skill exists but is not a symlink"
            VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
        else
            echo -e "  ${CROSS_MARK} Skill not linked: $skill"
            VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
        fi
    done
    
    # Check bootstrap-context installation
    if [ -d "$OPENCLAW_DIR/hooks/db-bootstrap-context" ]; then
        echo -e "  ${CHECK_MARK} Bootstrap context hook installed"
    else
        echo -e "  ${CROSS_MARK} Bootstrap context hook not installed"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
    fi
    
    return 0
}

verify_database() {
    echo ""
    echo "Database verification..."
    
    # Check if database exists
    if ! psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo -e "  ${CROSS_MARK} Database '$DB_NAME' does not exist"
        echo "      nova-cognition requires nova-memory to be installed first"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
        return 1
    fi
    
    echo -e "  ${CHECK_MARK} Database '$DB_NAME' exists"
    
    # Check database connection
    if psql -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        echo -e "  ${CHECK_MARK} Database connection works"
    else
        echo -e "  ${CROSS_MARK} Database connection failed"
        VERIFICATION_ERRORS=$((VERIFICATION_ERRORS + 1))
        return 1
    fi
    
    # Check required tables for agent_chat
    local required_tables=("agent_messages" "agent_conversations")
    local missing_tables=()
    
    for table in "${required_tables[@]}"; do
        TABLE_EXISTS=$(psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$table'" | tr -d '[:space:]')
        
        if [ "$TABLE_EXISTS" -eq 0 ]; then
            missing_tables+=("$table")
        else
            echo -e "  ${CHECK_MARK} Table '$table' exists"
        fi
    done
    
    if [ ${#missing_tables[@]} -gt 0 ]; then
        echo -e "  ${WARNING} Missing optional agent_chat tables:"
        for table in "${missing_tables[@]}"; do
            echo "      • $table (will be created by extension)"
        done
        VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + ${#missing_tables[@]}))
    fi
    
    # Check bootstrap_context tables
    BOOTSTRAP_TABLES=$(psql -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'bootstrap_context%'" | tr -d '[:space:]')
    
    if [ "$BOOTSTRAP_TABLES" -ge 4 ]; then
        echo -e "  ${CHECK_MARK} Bootstrap context tables installed ($BOOTSTRAP_TABLES/4)"
    else
        echo -e "  ${WARNING} Bootstrap context tables incomplete ($BOOTSTRAP_TABLES/4)"
        VERIFICATION_WARNINGS=$((VERIFICATION_WARNINGS + 1))
    fi
    
    return 0
}

# ============================================
# Part 1: Prerequisites Check
# ============================================
echo "Checking prerequisites..."

# Check Node.js installed
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge 18 ]; then
        echo -e "  ${CHECK_MARK} Node.js installed ($NODE_VERSION)"
    else
        echo -e "  ${WARNING} Node.js version $NODE_VERSION (recommend 18+)"
    fi
else
    echo -e "  ${CROSS_MARK} Node.js not found"
    echo ""
    echo "Please install Node.js 18+ first:"
    echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt install -y nodejs"
    echo "  macOS: brew install node"
    exit 1
fi

# Check npm installed
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo -e "  ${CHECK_MARK} npm installed ($NPM_VERSION)"
else
    echo -e "  ${CROSS_MARK} npm not found"
    exit 1
fi

# Check TypeScript available (can be local or global)
if command -v tsc &> /dev/null; then
    TSC_VERSION=$(tsc --version)
    echo -e "  ${CHECK_MARK} TypeScript installed ($TSC_VERSION)"
elif npm list -g typescript &> /dev/null; then
    echo -e "  ${CHECK_MARK} TypeScript installed (global)"
else
    echo -e "  ${WARNING} TypeScript not installed globally (will use local)"
fi

# Check PostgreSQL installed
if command -v psql &> /dev/null; then
    PG_VERSION=$(psql --version | awk '{print $3}')
    echo -e "  ${CHECK_MARK} PostgreSQL installed ($PG_VERSION)"
else
    echo -e "  ${CROSS_MARK} PostgreSQL not found"
    echo ""
    echo "Please install PostgreSQL first:"
    echo "  Ubuntu/Debian: sudo apt install postgresql postgresql-contrib"
    echo "  macOS: brew install postgresql"
    exit 1
fi

# Check PostgreSQL service running
if pg_isready -q 2>/dev/null; then
    echo -e "  ${CHECK_MARK} PostgreSQL service running"
else
    echo -e "  ${WARNING} PostgreSQL service not running (required for bootstrap-context)"
fi

# Check createdb command available
if command -v createdb &> /dev/null; then
    echo -e "  ${CHECK_MARK} createdb installed"
else
    echo -e "  ${CROSS_MARK} createdb not found"
    echo ""
    echo "Please install PostgreSQL client tools:"
    echo "  Ubuntu/Debian: sudo apt install postgresql-client"
    echo "  macOS: brew install postgresql"
    exit 1
fi

# Check nova-memory database exists (only if not in verify-only mode)
if [ $VERIFY_ONLY -eq 0 ]; then
    if psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo -e "  ${CHECK_MARK} Database '$DB_NAME' exists"
    else
        echo -e "  ${INFO} Database '$DB_NAME' not found (will create)"
    fi
else
    if psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo -e "  ${CHECK_MARK} nova-memory database exists"
    else
        echo -e "  ${WARNING} Database '$DB_NAME' not found"
        echo "      nova-cognition works best with nova-memory installed first"
    fi
fi

# ============================================
# Database Setup (Before verification)
# ============================================
if [ $VERIFY_ONLY -eq 0 ]; then
    echo ""
    echo "Database setup..."
    
    # Check if database exists
    if ! psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "  Creating database '$DB_NAME'..."
        createdb -U "$DB_USER" "$DB_NAME" || { echo -e "  ${CROSS_MARK} Failed to create database"; exit 1; }
        echo -e "  ${CHECK_MARK} Database '$DB_NAME' created"
    else
        echo -e "  ${CHECK_MARK} Database '$DB_NAME' exists"
    fi
    
    # Verify connection
    if psql -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        echo -e "  ${CHECK_MARK} Database connection verified"
    else
        echo -e "  ${CROSS_MARK} Cannot connect to database '$DB_NAME'"
        exit 1
    fi
    
    # Apply agent_chat schema (idempotent - uses CREATE IF NOT EXISTS)
    SCHEMA_FILE="$SCRIPT_DIR/focus/focus/agent_chat/schema.sql"
    if [ ! -f "$SCHEMA_FILE" ]; then
        echo -e "  ${WARNING} focus/agent_chat/schema.sql not found (will be created by extension)"
    else
        echo "  Applying agent_chat schema..."
        psql -U "$DB_USER" -d "$DB_NAME" -f "$SCHEMA_FILE" > /dev/null 2>&1
        echo -e "  ${CHECK_MARK} Schema applied"
    fi
fi

# ============================================
# Run Verification if --verify-only
# ============================================
if [ $VERIFY_ONLY -eq 1 ]; then
    echo ""
    verify_files
    verify_database
    
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Verification Summary"
    echo "═══════════════════════════════════════════"
    if [ $VERIFICATION_ERRORS -gt 0 ]; then
        echo -e "  ${CROSS_MARK} $VERIFICATION_ERRORS errors found"
        exit 1
    elif [ $VERIFICATION_WARNINGS -gt 0 ]; then
        echo -e "  ${WARNING} $VERIFICATION_WARNINGS warnings found"
        exit 0
    else
        echo -e "  ${CHECK_MARK} All checks passed"
        exit 0
    fi
fi

# ============================================
# Part 2: Home Directory Symlink
# ============================================
echo ""
echo "Home directory symlink setup..."

HOME_LINK="$HOME/nova-cognition"

# Handle existing symlink/directory
if [ -L "$HOME_LINK" ]; then
    CURRENT_TARGET=$(readlink "$HOME_LINK")
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR" ]; then
        echo -e "  ${CHECK_MARK} Home symlink already correct"
    else
        if [ $FORCE_INSTALL -eq 1 ]; then
            rm "$HOME_LINK"
            ln -s "$SCRIPT_DIR" "$HOME_LINK"
            echo -e "  ${CHECK_MARK} Updated home symlink"
        else
            echo -e "  ${WARNING} Home symlink points to different location: $CURRENT_TARGET"
            echo "      Use --force to update"
        fi
    fi
elif [ -e "$HOME_LINK" ]; then
    if [ $FORCE_INSTALL -eq 1 ]; then
        rm -rf "$HOME_LINK"
        ln -s "$SCRIPT_DIR" "$HOME_LINK"
        echo -e "  ${CHECK_MARK} Replaced directory with home symlink"
    else
        echo -e "  ${WARNING} $HOME_LINK exists but is not a symlink"
        echo "      Use --force to replace"
    fi
else
    ln -s "$SCRIPT_DIR" "$HOME_LINK"
    echo -e "  ${CHECK_MARK} Created home symlink: ~/nova-cognition → $SCRIPT_DIR"
fi

# ============================================
# Part 3: OpenClaw Project Symlink
# ============================================
echo ""
echo "OpenClaw project integration..."

# Create projects directory if needed
mkdir -p "$OPENCLAW_PROJECTS"

PROJECT_LINK="$OPENCLAW_PROJECTS/nova-cognition"

# Handle existing symlink/directory
if [ -L "$PROJECT_LINK" ]; then
    CURRENT_TARGET=$(readlink "$PROJECT_LINK")
    if [ "$CURRENT_TARGET" = "$SCRIPT_DIR" ]; then
        echo -e "  ${CHECK_MARK} Project symlink already correct"
    else
        if [ $FORCE_INSTALL -eq 1 ]; then
            rm "$PROJECT_LINK"
            ln -s "$SCRIPT_DIR" "$PROJECT_LINK"
            echo -e "  ${CHECK_MARK} Updated project symlink"
        else
            echo -e "  ${WARNING} Project symlink points to different location: $CURRENT_TARGET"
            echo "      Use --force to update"
        fi
    fi
elif [ -e "$PROJECT_LINK" ]; then
    if [ $FORCE_INSTALL -eq 1 ]; then
        rm -rf "$PROJECT_LINK"
        ln -s "$SCRIPT_DIR" "$PROJECT_LINK"
        echo -e "  ${CHECK_MARK} Replaced directory with symlink"
    else
        echo -e "  ${WARNING} $PROJECT_LINK exists but is not a symlink"
        echo "      Use --force to replace"
    fi
else
    ln -s "$SCRIPT_DIR" "$PROJECT_LINK"
    echo -e "  ${CHECK_MARK} Created project symlink"
fi

# ============================================
# Part 4: Agent Chat Extension
# ============================================
echo ""
echo "Agent Chat extension installation..."

EXTENSION_SOURCE="$SCRIPT_DIR/focus/agent_chat"
EXTENSION_TARGET="$EXTENSIONS_DIR/agent_chat"

# Create extensions directory if needed
mkdir -p "$EXTENSIONS_DIR"

# Check if extension exists
if [ -d "$EXTENSION_TARGET" ] && [ $FORCE_INSTALL -eq 0 ]; then
    echo -e "  ${CHECK_MARK} Extension directory exists (use --force to reinstall)"
else
    echo "  Installing agent_chat extension..."
    
    # Remove existing if force
    if [ $FORCE_INSTALL -eq 1 ] && [ -d "$EXTENSION_TARGET" ]; then
        rm -rf "$EXTENSION_TARGET"
        echo "  Removed existing installation"
    fi
    
    # Create target directory
    mkdir -p "$EXTENSION_TARGET"
    
    # Copy source files (TypeScript)
    echo "  Copying source files..."
    cp -r "$EXTENSION_SOURCE/src" "$EXTENSION_TARGET/"
    cp "$EXTENSION_SOURCE/index.ts" "$EXTENSION_TARGET/"
    cp "$EXTENSION_SOURCE/package.json" "$EXTENSION_TARGET/"
    cp "$EXTENSION_SOURCE/tsconfig.json" "$EXTENSION_TARGET/"
    
    # Copy or update openclaw.plugin.json
    if [ -f "$EXTENSION_SOURCE/openclaw.plugin.json" ]; then
        cp "$EXTENSION_SOURCE/openclaw.plugin.json" "$EXTENSION_TARGET/"
    fi
    
    # Ensure main field is set correctly
    if [ -f "$EXTENSION_TARGET/openclaw.plugin.json" ]; then
        if ! grep -q '"main":' "$EXTENSION_TARGET/openclaw.plugin.json"; then
            # Add main field if missing
            sed -i '/"id":/a\  "main": "./dist/index.js",' "$EXTENSION_TARGET/openclaw.plugin.json"
        elif ! grep -q '"main": "./dist/index.js"' "$EXTENSION_TARGET/openclaw.plugin.json"; then
            # Update main field if incorrect
            sed -i 's|"main": "[^"]*"|"main": "./dist/index.js"|' "$EXTENSION_TARGET/openclaw.plugin.json"
        fi
    fi
    
    echo -e "  ${CHECK_MARK} Source files copied"
fi

# Install npm dependencies
echo ""
echo "  Installing npm dependencies..."
cd "$EXTENSION_TARGET"

if [ -d "node_modules" ] && [ $FORCE_INSTALL -eq 0 ]; then
    echo -e "  ${CHECK_MARK} Dependencies already installed (use --force to reinstall)"
else
    NPM_INSTALL_LOG="${TMPDIR:-/tmp}/npm-install-agent-chat-$$.log"
    echo "    Running npm install..."
    if npm install > "$NPM_INSTALL_LOG" 2>&1; then
        echo -e "  ${CHECK_MARK} npm install completed"
        rm -f "$NPM_INSTALL_LOG"
    else
        echo -e "  ${CROSS_MARK} npm install failed"
        echo "      Log: $NPM_INSTALL_LOG"
        tail -20 "$NPM_INSTALL_LOG"
        exit 1
    fi
fi

# Build TypeScript
echo ""
echo "  Building TypeScript..."

if [ -d "dist" ] && [ -f "dist/index.js" ] && [ $FORCE_INSTALL -eq 0 ]; then
    echo -e "  ${CHECK_MARK} Already built (use --force to rebuild)"
else
    NPM_BUILD_LOG="${TMPDIR:-/tmp}/npm-build-agent-chat-$$.log"
    echo "    Running npm run build..."
    if npm run build > "$NPM_BUILD_LOG" 2>&1; then
        echo -e "  ${CHECK_MARK} Build completed"
        rm -f "$NPM_BUILD_LOG"
    else
        echo -e "  ${CROSS_MARK} Build failed"
        echo "      Log: $NPM_BUILD_LOG"
        tail -20 "$NPM_BUILD_LOG"
        exit 1
    fi
fi

# Verify build output
if [ -f "dist/index.js" ]; then
    echo -e "  ${CHECK_MARK} Build output verified: dist/index.js exists"
else
    echo -e "  ${CROSS_MARK} Build output not found: dist/index.js"
    exit 1
fi

# Verify plugin configuration
if [ -f "openclaw.plugin.json" ]; then
    if grep -q '"main": "./dist/index.js"' openclaw.plugin.json; then
        echo -e "  ${CHECK_MARK} openclaw.plugin.json configured correctly"
    else
        echo -e "  ${WARNING} openclaw.plugin.json 'main' field may need updating"
    fi
else
    echo -e "  ${WARNING} openclaw.plugin.json not found"
fi

cd "$SCRIPT_DIR"

# ============================================
# Part 5: Skills Installation
# ============================================
echo ""
echo "Skills installation..."

SKILLS_DIR="$WORKSPACE/skills"
mkdir -p "$SKILLS_DIR"

# Install skills
SKILLS=("agent-chat" "agent-spawn")

for SKILL_NAME in "${SKILLS[@]}"; do
    SKILL_SOURCE="$SCRIPT_DIR/focus/skills/$SKILL_NAME"
    SKILL_TARGET="$SKILLS_DIR/$SKILL_NAME"
    
    if [ ! -d "$SKILL_SOURCE" ]; then
        echo -e "  ${WARNING} Skill not found: $SKILL_NAME (skipping)"
        continue
    fi
    
    if [ -L "$SKILL_TARGET" ]; then
        CURRENT_TARGET=$(readlink "$SKILL_TARGET")
        if [ "$CURRENT_TARGET" = "$SKILL_SOURCE" ]; then
            echo -e "  ${CHECK_MARK} $SKILL_NAME already linked"
        else
            if [ $FORCE_INSTALL -eq 1 ]; then
                rm "$SKILL_TARGET"
                ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
                echo -e "  ${CHECK_MARK} Updated $SKILL_NAME symlink"
            else
                echo -e "  ${WARNING} $SKILL_NAME symlink points elsewhere"
                echo "      Use --force to update"
            fi
        fi
    elif [ -e "$SKILL_TARGET" ]; then
        if [ $FORCE_INSTALL -eq 1 ]; then
            rm -rf "$SKILL_TARGET"
            ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
            echo -e "  ${CHECK_MARK} Replaced $SKILL_NAME with symlink"
        else
            echo -e "  ${WARNING} $SKILL_NAME exists but is not a symlink"
            echo "      Use --force to replace"
        fi
    else
        ln -s "$SKILL_SOURCE" "$SKILL_TARGET"
        echo -e "  ${CHECK_MARK} Linked skill: $SKILL_NAME"
    fi
done

# ============================================
# Part 6: Bootstrap Context System
# ============================================
echo ""
echo "Bootstrap context system installation..."

BOOTSTRAP_INSTALLER="$SCRIPT_DIR/focus/bootstrap-context/install.sh"

if [ -f "$BOOTSTRAP_INSTALLER" ]; then
    # Check if already installed
    if [ -d "$OPENCLAW_DIR/hooks/db-bootstrap-context" ] && [ $FORCE_INSTALL -eq 0 ]; then
        echo -e "  ${CHECK_MARK} Bootstrap context already installed (use --force to reinstall)"
    else
        echo "  Running bootstrap-context installer..."
        cd "$SCRIPT_DIR/focus/bootstrap-context"
        
        # Export database settings
        export DB_NAME="$DB_NAME"
        
        BOOTSTRAP_LOG="${TMPDIR:-/tmp}/bootstrap-install-$$.log"
        if bash install.sh > "$BOOTSTRAP_LOG" 2>&1; then
            echo -e "  ${CHECK_MARK} Bootstrap context installed"
            rm -f "$BOOTSTRAP_LOG"
        else
            echo -e "  ${WARNING} Bootstrap context installation had issues"
            echo "      Log: $BOOTSTRAP_LOG"
            tail -10 "$BOOTSTRAP_LOG"
        fi
        
        cd "$SCRIPT_DIR"
    fi
else
    echo -e "  ${WARNING} Bootstrap context installer not found (skipping)"
fi

# ============================================
# Part 7: Verification
# ============================================
echo ""
verify_files
verify_database

# ============================================
# Installation Complete
# ============================================
echo ""
echo "═══════════════════════════════════════════"
if [ $VERIFICATION_ERRORS -gt 0 ]; then
    echo -e "  ${CROSS_MARK} Installation completed with errors"
elif [ $VERIFICATION_WARNINGS -gt 0 ]; then
    echo -e "  ${WARNING} Installation completed with warnings"
else
    echo -e "  ${GREEN}Installation complete!${NC}"
fi
echo "═══════════════════════════════════════════"
echo ""

echo "Installed components:"
echo "  • agent_chat extension (TypeScript) → $EXTENSIONS_DIR/agent_chat"
echo "  • agent-chat skill → $WORKSPACE/skills/agent-chat"
echo "  • agent-spawn skill → $WORKSPACE/skills/agent-spawn"
echo "  • bootstrap-context system → $OPENCLAW_DIR/hooks/db-bootstrap-context"
echo ""

echo "Project location:"
echo "  • Home: ~/nova-cognition → $SCRIPT_DIR"
echo "  • Projects: $OPENCLAW_PROJECTS/nova-cognition → $SCRIPT_DIR"
echo ""

echo "Usage examples:"
echo ""
echo "1. Configure agent_chat channel in your OpenClaw config:"
echo "   channels:"
echo "     agent_chat:"
echo "       agentName: YourAgentName"
echo "       database: $DB_NAME"
echo "       host: localhost"
echo "       user: $DB_USER"
echo "       password: YOUR_PASSWORD"
echo ""
echo "2. Test agent-chat skill:"
echo "   📊 agent-chat --help"
echo ""
echo "3. Bootstrap context:"
echo "   psql -d $DB_NAME -c \"SELECT * FROM get_agent_bootstrap('test');\""
echo ""
echo "4. Verify installation:"
echo "   $0 --verify-only"
echo ""
echo "5. Restart OpenClaw gateway to load the extension:"
echo "   openclaw gateway restart"
echo ""

if [ $VERIFICATION_WARNINGS -gt 0 ]; then
    echo "⚠️  Warnings detected. Review output above."
    echo ""
fi
