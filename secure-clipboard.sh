#!/bin/bash

################################################################################
# SECURE COPY-PASTE COMMAND FOR LINUX TERMINAL
# Maximum Security Implementation
# Usage: source secure-clipboard.sh
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# 1. SECURE COPY FUNCTION (scopy)
################################################################################
scopy() {
    local usage="Usage: scopy [OPTIONS] [file_or_text]
Options:
    -f, --file      Copy file contents securely
    -t, --text      Copy plain text (default)
    -c, --clear     Clear clipboard after N seconds
    -p, --primary   Use primary selection instead of clipboard
    -h, --help      Show this help message"

    if [[ $# -eq 0 ]]; then
        echo -e "${RED}Error: No input provided${NC}"
        echo "$usage"
        return 1
    fi

    local clear_time=0
    local use_primary=false
    local input_type="text"
    local input_data=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                input_type="file"
                shift
                input_data="$1"
                shift
                ;;
            -t|--text)
                input_type="text"
                shift
                input_data="$1"
                shift
                ;;
            -c|--clear)
                clear_time="$2"
                shift 2
                ;;
            -p|--primary)
                use_primary=true
                shift
                ;;
            -h|--help)
                echo "$usage"
                return 0
                ;;
            *)
                input_data="$1"
                shift
                ;;
        esac
    done

    # Check if xclip or xsel is available
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo -e "${RED}Error: Neither xclip nor xsel found. Install with:${NC}"
        echo "  sudo apt install xclip  # Debian/Ubuntu"
        echo "  sudo dnf install xclip  # Fedora"
        return 1
    fi

    # Process input
    if [[ "$input_type" == "file" ]]; then
        if [[ ! -f "$input_data" ]]; then
            echo -e "${RED}Error: File not found: $input_data${NC}"
            return 1
        fi
        
        # Check file permissions before reading
        if [[ ! -r "$input_data" ]]; then
            echo -e "${RED}Error: No read permission for file: $input_data${NC}"
            return 1
        fi
        
        # Use cat to read file (safer than redirection)
        local file_content
        file_content=$(cat "$input_data") || {
            echo -e "${RED}Error: Failed to read file${NC}"
            return 1
        }
        
        # Copy to clipboard securely
        if command -v xclip &> /dev/null; then
            if $use_primary; then
                echo -n "$file_content" | xclip -selection primary
            else
                echo -n "$file_content" | xclip -selection clipboard
            fi
        else
            if $use_primary; then
                echo -n "$file_content" | xsel -b -p
            else
                echo -n "$file_content" | xsel -b
            fi
        fi
        
        echo -e "${GREEN}✓ File copied securely to clipboard${NC}"
        echo -e "${BLUE}File: $input_data ($(wc -c < "$input_data") bytes)${NC}"
        
    else
        # Copy text to clipboard
        if command -v xclip &> /dev/null; then
            if $use_primary; then
                echo -n "$input_data" | xclip -selection primary
            else
                echo -n "$input_data" | xclip -selection clipboard
            fi
        else
            if $use_primary; then
                echo -n "$input_data" | xsel -b -p
            else
                echo -n "$input_data" | xsel -b
            fi
        fi
        
        echo -e "${GREEN}✓ Text copied to clipboard (${#input_data} characters)${NC}"
    fi

    # Auto-clear clipboard after specified seconds
    if [[ $clear_time -gt 0 ]]; then
        echo -e "${YELLOW}⏱ Clipboard will be cleared in $clear_time seconds${NC}"
        sleep "$clear_time"
        
        if command -v xclip &> /dev/null; then
            echo -n "" | xclip -selection clipboard
            $use_primary && echo -n "" | xclip -selection primary
        else
            echo -n "" | xsel -b
            $use_primary && echo -n "" | xsel -b -p
        fi
        
        echo -e "${GREEN}✓ Clipboard cleared${NC}"
    fi
}

################################################################################
# 2. SECURE PASTE FUNCTION (spaste)
################################################################################
spaste() {
    local usage="Usage: spaste [OPTIONS]
Options:
    -f, --file FILE     Save pasted content to file
    -v, --verify        Show clipboard content with hash for verification
    -p, --primary       Paste from primary selection
    -c, --clear         Clear clipboard after pasting
    -h, --help          Show this help message"

    if [[ $# -eq 0 ]]; then
        # Simple paste
        if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
            echo -e "${RED}Error: Neither xclip nor xsel found${NC}"
            return 1
        fi

        local clipboard_content
        if command -v xclip &> /dev/null; then
            clipboard_content=$(xclip -selection clipboard -o)
        else
            clipboard_content=$(xsel -b)
        fi

        echo "$clipboard_content"
        return 0
    fi

    local output_file=""
    local verify=false
    local use_primary=false
    local clear_after=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                output_file="$2"
                shift 2
                ;;
            -v|--verify)
                verify=true
                shift
                ;;
            -p|--primary)
                use_primary=true
                shift
                ;;
            -c|--clear)
                clear_after=true
                shift
                ;;
            -h|--help)
                echo "$usage"
                return 0
                ;;
            *)
                shift
                ;;
        esac
    done

    # Get clipboard content
    local clipboard_content
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo -e "${RED}Error: Neither xclip nor xsel found${NC}"
        return 1
    fi

    if command -v xclip &> /dev/null; then
        if $use_primary; then
            clipboard_content=$(xclip -selection primary -o)
        else
            clipboard_content=$(xclip -selection clipboard -o)
        fi
    else
        if $use_primary; then
            clipboard_content=$(xsel -p)
        else
            clipboard_content=$(xsel -b)
        fi
    fi

    # Verify mode - show hash
    if $verify; then
        echo -e "${BLUE}Clipboard Content:${NC}"
        echo "---"
        echo "$clipboard_content" | head -c 200
        if [[ ${#clipboard_content} -gt 200 ]]; then
            echo "... ($(( ${#clipboard_content} - 200 )) more characters)"
        fi
        echo ""
        echo "---"
        
        local sha256_hash
        sha256_hash=$(echo -n "$clipboard_content" | sha256sum | awk '{print $1}')
        echo -e "${BLUE}SHA256: $sha256_hash${NC}"
        echo -e "${BLUE}Size: ${#clipboard_content} bytes${NC}"
        
        return 0
    fi

    # Save to file
    if [[ -n "$output_file" ]]; then
        # Secure file creation with restricted permissions
        touch "$output_file" || {
            echo -e "${RED}Error: Cannot create file: $output_file${NC}"
            return 1
        }
        chmod 600 "$output_file"
        
        echo -n "$clipboard_content" > "$output_file" || {
            echo -e "${RED}Error: Failed to write to file${NC}"
            return 1
        }
        
        echo -e "${GREEN}✓ Clipboard content saved to file${NC}"
        echo -e "${BLUE}File: $output_file (600 permissions)${NC}"
    else
        echo "$clipboard_content"
    fi

    # Clear clipboard after pasting
    if $clear_after; then
        if command -v xclip &> /dev/null; then
            echo -n "" | xclip -selection clipboard
            $use_primary && echo -n "" | xclip -selection primary
        else
            echo -n "" | xsel -b
            $use_primary && echo -n "" | xsel -b -p
        fi
        echo -e "${GREEN}✓ Clipboard cleared${NC}"
    fi
}

################################################################################
# 3. SECURE CLIPBOARD CLEAR FUNCTION (sclear)
################################################################################
sclear() {
    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo -e "${RED}Error: Neither xclip nor xsel found${NC}"
        return 1
    fi

    if command -v xclip &> /dev/null; then
        echo -n "" | xclip -selection clipboard
        echo -n "" | xclip -selection primary
    else
        echo -n "" | xsel -b
        echo -n "" | xsel -b -p
    fi

    echo -e "${GREEN}✓ Clipboard cleared securely${NC}"
}

################################################################################
# 4. SECURE HASH FUNCTION (shash)
################################################################################
shash() {
    local usage="Usage: shash [OPTIONS] [input]
Options:
    -a, --algorithm ALG  Hash algorithm (md5, sha1, sha256, sha512) - default: sha256
    -f, --file FILE      Hash a file
    -t, --text TEXT      Hash plain text
    -v, --verify HASH    Verify against known hash
    -h, --help           Show this help message"

    if [[ $# -eq 0 ]]; then
        echo -e "${RED}Error: No input provided${NC}"
        echo "$usage"
        return 1
    fi

    local algorithm="sha256"
    local input_type="text"
    local input_data=""
    local verify_hash=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--algorithm)
                algorithm="$2"
                shift 2
                ;;
            -f|--file)
                input_type="file"
                input_data="$2"
                shift 2
                ;;
            -t|--text)
                input_type="text"
                input_data="$2"
                shift 2
                ;;
            -v|--verify)
                verify_hash="$2"
                shift 2
                ;;
            -h|--help)
                echo "$usage"
                return 0
                ;;
            *)
                input_data="$1"
                shift
                ;;
        esac
    done

    local hash_cmd
    case $algorithm in
        md5)
            hash_cmd="md5sum"
            ;;
        sha1)
            hash_cmd="sha1sum"
            ;;
        sha256)
            hash_cmd="sha256sum"
            ;;
        sha512)
            hash_cmd="sha512sum"
            ;;
        *)
            echo -e "${RED}Error: Unknown algorithm: $algorithm${NC}"
            return 1
            ;;
    esac

    local computed_hash
    
    if [[ "$input_type" == "file" ]]; then
        if [[ ! -f "$input_data" ]]; then
            echo -e "${RED}Error: File not found: $input_data${NC}"
            return 1
        fi
        
        computed_hash=$($hash_cmd "$input_data" | awk '{print $1}')
        echo -e "${BLUE}File: $input_data${NC}"
    else
        computed_hash=$(echo -n "$input_data" | $hash_cmd | awk '{print $1}')
    fi

    echo -e "${BLUE}Algorithm: $algorithm (uppercase)${NC}"
    echo -e "${GREEN}$computed_hash${NC}"

    # Verify if hash provided
    if [[ -n "$verify_hash" ]]; then
        verify_hash=$(echo "$verify_hash" | tr '[:lower:]' '[:upper:]')
        computed_hash_upper=$(echo "$computed_hash" | tr '[:lower:]' '[:upper:]')
        
        if [[ "$computed_hash_upper" == "$verify_hash" ]]; then
            echo -e "${GREEN}✓ Hash verification PASSED${NC}"
            return 0
        else
            echo -e "${RED}✗ Hash verification FAILED${NC}"
            echo -e "${RED}Expected: $verify_hash${NC}"
            echo -e "${RED}Got:      $computed_hash_upper${NC}"
            return 1
        fi
    fi
}

################################################################################
# 5. SETUP FUNCTION
################################################################################
setup_secure_clipboard() {
    echo -e "${BLUE}Setting up secure clipboard tools...${NC}"

    if ! command -v xclip &> /dev/null && ! command -v xsel &> /dev/null; then
        echo -e "${YELLOW}⚠ Neither xclip nor xsel found${NC}"
        echo "Install xclip with:"
        echo "  sudo apt install xclip    # Debian/Ubuntu"
        echo "  sudo dnf install xclip    # Fedora/RHEL"
        echo "  sudo pacman -S xclip      # Arch"
        echo "  brew install xclip        # macOS"
        return 1
    fi

    echo -e "${GREEN}✓ Clipboard tools available${NC}"
    
    if command -v xclip &> /dev/null; then
        echo "  Using: xclip"
    fi
    if command -v xsel &> /dev/null; then
        echo "  Using: xsel"
    fi

    echo -e "${GREEN}✓ Secure clipboard functions loaded:${NC}"
    echo "  scopy   - Secure copy with options"
    echo "  spaste  - Secure paste with verification"
    echo "  sclear  - Secure clipboard clear"
    echo "  shash   - Secure hash calculator"
    echo ""
    echo "Type 'scopy --help' for more information"
}

# Auto-setup on source
setup_secure_clipboard
