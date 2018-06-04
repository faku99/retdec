#!/usr/bin/env bash
#
# Runs the decompilation script with the given arguments over all files in the
# given static library.
#

# On macOS, we want the GNU version of 'readlink', which is available under
# 'greadlink':
gnureadlink()
{
	if hash greadlink 2> /dev/null; then
		greadlink "$@"
	else
		readlink "$@"
	fi
}

SCRIPT_DIR="$(dirname "$(gnureadlink -e "$0")")"

if [ -z "$DECOMPILER_UTILS" ]; then
	DECOMPILER_UTILS="$SCRIPT_DIR/retdec-utils.sh"
fi

. "$DECOMPILER_UTILS"

##
## Configuration.
##
TIMEOUT=300 # Timeout for the decompilation script.

##
## Prints help to stream $1.
##
print_help() {
	echo "Runs the decompilation script with the given optional arguments over all files" > "$1"
	echo "in the given static library or prints list of files in plain text" > "$1"
	echo "with --plain argument or in JSON format with --json argument. You" > "$1"
	echo "can pass arguments for decompilation after double-dash '--' argument." > "$1"
	echo "" > "$1"
	echo "Usage:" > "$1"
	echo "    $0 ARCHIVE [-- ARGS]" > "$1"
	echo "    $0 ARCHIVE --plain|--json" > "$1"
	echo "" > "$1"
}

##
## Prints error in either plain text or JSON format.
## One argument required: error message.
##
print_error_plain_or_json() {
	if [ "$JSON_FORMAT" ]; then
		M=$(echo "$1" | sed 's,\\,\\\\,g')
		M=$(echo "$M" | sed 's,\",\\",g')
		echo "{"
		echo "    \"error\" : \"$M\""
		echo "}"
		exit 1
	else
		# Otherwise print in plain text.
		print_error_and_die "$1"
	fi
}

##
## Cleans up all temporary files.
## No arguments accepted.
##
cleanup() {
	rm -f "$TMP_ARCHIVE"
}

##
## Parse script arguments.
##
while [[ $# -gt 0 ]]
do
	case $1 in
		-h|--help)
			print_help /dev/stdout
			exit 0;;
		--list)
			LIST_MODE=1
			shift;;
		--plain)
			[ "$JSON_FORMAT" ] && print_error_and_die "Arguments --plain and --json are mutually exclusive."
			LIST_MODE=1
			PLAIN_FORMAT=1
			shift;;
		--json)
			[ "$PLAIN_FORMAT" ] && print_error_and_die "Arguments --plain and --json are mutually exclusive."
			LIST_MODE=1
			JSON_FORMAT=1
			shift;;
		--)
			# Skip -- and store arguments for decompilation.
			shift
			DECOMPILER_SH_ARGS=$*
			break;;
		*)
			! [ -f "$1" ] && print_error_and_die "Input '$1' is not a valid file."
			LIBRARY_PATH="$1"
			shift;;
	esac
done

# Check arguments
[ ! "$LIBRARY_PATH" ] && print_error_plain_or_json "No input file."

# Check for archives packed in Mach-O Universal Binaries.
if is_macho_archive "$LIBRARY_PATH"; then
	if [ "$LIST_MODE" ]; then
		if [ "$JSON_FORMAT" ]; then
			"$EXTRACT" --objects --json "$LIBRARY_PATH"
		else
			# Otherwise print in plain text.
			"$EXTRACT" --objects "$LIBRARY_PATH"
		fi

		# Not sure why failure is used there.
		exit 1
	fi

	TMP_ARCHIVE="$LIBRARY_PATH.a"
	"$EXTRACT" --best --out "$TMP_ARCHIVE" "$LIBRARY_PATH"
	LIBRARY_PATH="$TMP_ARCHIVE"
fi

# Check for thin archives.
if has_thin_archive_signature "$LIBRARY_PATH"; then
	print_error_plain_or_json "File is a thin archive and cannot be decompiled."
fi

# Check if file is archive
if ! is_valid_archive "$LIBRARY_PATH"; then
	print_error_plain_or_json "File is not supported archive or is not readable."
fi

# Check number of files.
FILE_COUNT=$(archive_object_count "$LIBRARY_PATH")
if [ "$FILE_COUNT" -le 0 ]; then
	print_error_plain_or_json "No files found in archive."
fi

##
## List only mode.
##
if [ "$LIST_MODE" ]; then
	if [ "$JSON_FORMAT" ]; then
		archive_list_numbered_content_json "$LIBRARY_PATH"
	else
		# Otherwise print in plain text.
		archive_list_numbered_content "$LIBRARY_PATH"
	fi

	cleanup
	exit 0
fi

##
## Run the decompilation script over all the found files.
##
echo -n "Running \`$DECOMPILER_SH"
if [ "$DECOMPILER_SH_ARGS" != "" ]; then
	echo -n "$DECOMPILER_SH_ARGS"
fi
echo "\` over $FILE_COUNT files with timeout ${TIMEOUT}s" \
	"(run \`kill $$\` to terminate this script)..." >&2
echo "" >&2
for ((INDEX=0; INDEX<FILE_COUNT; INDEX++)); do
	FILE_INDEX=$((INDEX + 1))
	echo -ne "$FILE_INDEX/$FILE_COUNT\t\t"

	# We have to use indexes instead of names because archives can contain multiple files with same name.
	LOG_FILE="$LIBRARY_PATH.file_$FILE_INDEX.log.verbose"                                                    # Do not escape!
	gnutimeout $TIMEOUT "$DECOMPILER_SH" --ar-index="$INDEX" -o "$LIBRARY_PATH.file_$FILE_INDEX.c" "$LIBRARY_PATH" $DECOMPILER_SH_ARGS > "$LOG_FILE" 2>&1
	RC=$?

	# Print status.
	case $RC in
		0)   echo "[OK]" ;;
		124) echo "[TIMEOUT]" ;;
		*)   echo "[FAIL]" ;;
	esac
done

# Cleanup
cleanup

# Success!
exit 0
