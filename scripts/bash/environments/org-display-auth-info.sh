#!/bin/bash

# -----------------------------------------------------------------------------
# @file org-display-auth-info.sh
# @brief Display Salesforce org authentication information in JSON format.
#
# This script retrieves authentication details for a specified Salesforce org
# using the Salesforce CLI and writes the output to a user-specified file.
#
# @usage
#   ./org-display-auth-info.sh -o <target-org> -f <output-file> [--json]
#   ./org-display-auth-info.sh --org <target-org> --file <output-file> [--json]
#
# @options
#   -o, --org     The alias or username of the target Salesforce org.
#   -f, --file    The path to the output file where JSON will be saved.
#   -h, --help    Show this help message and exit.
#   --json        Output errors in JSON format.
#
# @example
#   ./org-display-auth-info.sh -o my-org -f ./authFile.json --json
#
# @exitcodes
#   0  Success
#   1  Missing required arguments or invalid usage
# -----------------------------------------------------------------------------

set -euo pipefail

OUTPUT_FILE=""
TARGET_ORG=""
JSON_OUTPUT=false

print_json_error() {
    local code="$1"
    local message="$2"
    local details="${3:-}"
    echo -n '{'
    echo -n "\"success\": false, \"error\": {\"code\": \"$code\", \"message\": \"$message\""
    if [ -n "$details" ]; then
        echo -n ", \"details\": \"$details\""
    fi
    echo '}}'
}

show_usage() {
    echo "Usage: $0 -o <target-org> -f <output-file> [--json]"
    echo "  -o, --org     The alias or username of the target Salesforce org."
    echo "  -f, --file    The path to the output file where JSON will be saved."
    echo "  -h, --help    Show this help message and exit."
    echo "  --json        Output errors in JSON format."
}

parse_args() {
    JSON_OUTPUT=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o | --org)
                TARGET_ORG="$2"
                shift 2
                ;;
            -f | --file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            -h | --help)
                show_usage
                exit 0
                ;;
            *)
                show_usage >&2
                exit 1
                ;;
        esac
    done
}

check_dependencies() {
    if ! command -v jq > /dev/null 2>&1; then
        local msg="Error: jq is required but not installed."
        if [ "$JSON_OUTPUT" = true ]; then
            print_json_error "MISSING_DEPENDENCY" "$msg" "Install jq to continue."
        else
            echo "$msg" >&2
        fi
        exit 1
    fi

    if ! command -v sf > /dev/null 2>&1; then
        local msg="Error: Salesforce CLI (sf) is not installed."
        if [ "$JSON_OUTPUT" = true ]; then
            print_json_error "MISSING_DEPENDENCY" "$msg" "Install Salesforce CLI to continue."
        else
            echo "$msg" >&2
        fi
        exit 1
    fi
}

validate_args() {
    if [ -z "$TARGET_ORG" ] || [ -z "$OUTPUT_FILE" ]; then
        local msg="Error: target org and output file must be specified with -o/--org and -f/--file"
        if [ "$JSON_OUTPUT" = true ]; then
            print_json_error "MISSING_ARGUMENTS" "$msg" "Use -o/--org and -f/--file"
        else
            echo "$msg" >&2
        fi
        exit 1
    fi
}

run_sf_command() {
    # Ensure output directory exists
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    if ! sf org display --target-org "$TARGET_ORG" --verbose --json | jq -c . > "$OUTPUT_FILE"; then
        local msg="Error: Failed to display org info."
        if [ "$JSON_OUTPUT" = true ]; then
            print_json_error "ORG_DISPLAY_FAILED" "$msg"
        else
            echo "$msg" >&2
        fi
        exit 1
    fi
}

main() {
    parse_args "$@"
    validate_args
    check_dependencies
    run_sf_command
}

main "$@"
