#!/bin/bash

# -----------------------------------------------------------------------------
# @file scratch-org-create-scratch-from-definition-file.sh
# @brief Create a Salesforce scratch org from a definition file.
#
# This script creates a Salesforce scratch org using a specified definition file,
# duration, Dev Hub alias, and optional namespace. It supports JSON error output.
#
# @usage
#   ./scratch-org-create-scratch-from-definition-file.sh -d <definition-file> -a <alias> -t <duration-days> -h <dev-hub-alias> [-n] [-f <output-file>] [--json]
#   ./scratch-org-create-scratch-from-definition-file.sh --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--file <output-file>] [--json]
#
# @options
#   -d, --definition-file     Path to the scratch org definition file.
#   -a, --alias              Alias for the new scratch org.
#   -t, --duration-days      Duration in days for the scratch org.
#   -h, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation.
#   -n, --no-namespace       Do not use a namespace.
#   -f, --file               Path to output file for org info (JSON, single line).
#   --json                   Output errors in JSON format.
#   --help                   Show this help message and exit.
#
# @example
#   ./scratch-org-create-scratch-from-definition-file.sh -d config/scratch-orgs/dev-def.json -a my-scratch -t 30 -h DevHub -n -f ./scratchOrgInfo.json --json
#
# @exitcodes
#   0  Success
#   1  Missing required arguments or invalid usage
# -----------------------------------------------------------------------------

set -euo pipefail

OUTPUT_FILE=""
DEFINITION_FILE=""
SCRATCH_ALIAS=""
DURATION_DAYS=""
SF_DEV_HUB_ALIAS=""
JSON_OUTPUT=false
NO_NAMESPACE=false

print_json_error() {
	local code="$1"
	local message="$2"
	local details="$3"
	echo -n '{'
	echo -n "\"success\": false, \"error\": {\"code\": \"$code\", \"message\": \"$message\""
	if [ -n "$details" ]; then
		echo -n ", \"details\": \"$details\""
	fi
	echo '}}'
}

show_usage() {
    echo "Usage:"
    echo "  $0 -d <definition-file> -a <alias> -t <duration-days> -h <dev-hub-alias> [-n] [-f <output-file>] [--json]"
    echo "  $0 --definition-file <definition-file> --alias <alias> --duration-days <duration-days> --target-dev-hub <dev-hub-alias> [--no-namespace] [--file <output-file>] [--json]"
    echo
    echo "Options:"
    echo "  -d, --definition-file     Path to the scratch org definition file."
    echo "  -a, --alias              Alias for the new scratch org."
    echo "  -t, --duration-days      Duration in days for the scratch org."
    echo "  -h, --target-dev-hub     Alias for the Dev Hub org to use for scratch org creation."
    echo "  -n, --no-namespace       Do not use a namespace."
    echo "  -f, --file               Path to output file for org info (JSON, single line)."
    echo "  --json                   Output errors in JSON format."
    echo "  --help                   Show this help message and exit."
}

validate_args() {
	if [ -z "$DEFINITION_FILE" ] || [ -z "$SCRATCH_ALIAS" ] || [ -z "$DURATION_DAYS" ] || [ -z "$SF_DEV_HUB_ALIAS" ]; then
		local msg="Error: definition file, alias, duration days, and dev hub alias must be specified"
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_ARGUMENTS" "$msg" "Use -d/--definition-file, -a/--alias, -t/--duration-days, and -h/--target-dev-hub"
		else
			echo "$msg"
		fi
		exit 1
	fi
}

parse_args() {
	JSON_OUTPUT=false
	NO_NAMESPACE=false
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-d | --definition-file)
				DEFINITION_FILE="$2"
				shift 2
				;;
			-a | --alias)
				SCRATCH_ALIAS="$2"
				shift 2
				;;
			-t | --duration-days)
				DURATION_DAYS="$2"
				shift 2
				;;
			-h | --target-dev-hub)
				SF_DEV_HUB_ALIAS="$2"
				shift 2
				;;
			-n | --no-namespace)
				NO_NAMESPACE=true
				shift
				;;
			-f | --file)
				OUTPUT_FILE="$2"
				shift 2
				;;
			--json)
				JSON_OUTPUT=true
				shift
				;;
			--help)
				show_usage
				exit 0
				;;
			*)
				show_usage
				exit 1
				;;
		esac
	done
}

check_dependencies() {
	if ! command -v sf > /dev/null 2>&1; then
		local msg="Error: Salesforce CLI (sf) is not installed."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install Salesforce CLI to continue."
		else
			echo "$msg"
		fi
		exit 1
	fi
	if ! command -v jq > /dev/null 2>&1; then
		local msg="Error: jq is required but not installed."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "MISSING_DEPENDENCY" "$msg" "Install jq to continue."
		else
			echo "$msg"
		fi
		exit 1
	fi
}

run_sf_create_scratch_command() {
	sf org create scratch \
		--definition-file "$DEFINITION_FILE" \
		--alias "$SCRATCH_ALIAS" \
		--duration-days "$DURATION_DAYS" \
		--target-dev-hub "$SF_DEV_HUB_ALIAS" \
		${NO_NAMESPACE:+--no-namespace} \
		--set-default \
		--async \
		--json
}

start_scratch_org_creation() {
	if ! CREATE_OUTPUT=$(run_sf_create_scratch_command); then
		local msg="Error: Failed to start scratch org creation."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "SCRATCH_ORG_CREATION_FAILED" "$msg" "$CREATE_OUTPUT"
		else
			echo "$msg"
			echo "$CREATE_OUTPUT"
		fi
		exit 1
	fi
}

extract_job_id() {
	JOB_ID=$(echo "$CREATE_OUTPUT" | jq -r '.result.scratchOrgInfo.Id')
	if [ -z "$JOB_ID" ] || [ "$JOB_ID" = "null" ]; then
		local msg="Error: Could not extract job ID from scratch org creation output."
		if [ "$JSON_OUTPUT" = true ]; then
			print_json_error "NO_JOB_ID" "$msg" "$CREATE_OUTPUT"
		else
			echo "$msg"
			echo "$CREATE_OUTPUT"
		fi
		exit 1
	fi
}

show_progress() {
    echo "Scratch org creation started. Job ID: $JOB_ID" >&2
    echo "Showing progress (human readable):" >&2
    sf org resume scratch --job-id "$JOB_ID" >&2
}

get_final_json_output() {
    if ! FINAL_JSON=$(sf org resume scratch --job-id "$JOB_ID" --json 2> /dev/null); then
        # If resume fails, try to use CREATE_OUTPUT if it's valid JSON
        if echo "$CREATE_OUTPUT" | jq empty 2>/dev/null; then
            FINAL_JSON="$CREATE_OUTPUT"
        else
            local msg="Neither resume nor CREATE_OUTPUT returned valid JSON."
            if [ "$JSON_OUTPUT" = true ]; then
                print_json_error "INVALID_JSON" "$msg" "$CREATE_OUTPUT"
            else
                echo "$msg"
                echo "$CREATE_OUTPUT"
            fi
            exit 1
        fi
    fi
}

output_final_json() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$FINAL_JSON" > "$OUTPUT_FILE"
    else
        echo "$FINAL_JSON"
    fi
}

run_scratch_org_creation() {
	start_scratch_org_creation
	extract_job_id
	show_progress
	get_final_json_output
	output_final_json
}

main() {
	parse_args "$@"
	validate_args
	check_dependencies
	run_scratch_org_creation
}

main "$@"
