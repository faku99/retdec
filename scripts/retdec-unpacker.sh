#!/usr/bin/env bash
#
# The script tries to unpack the given executable file by using any
# of the supported unpackers, which are at present:
#    * generic unpacker
#    * upx
#
# Required argument:
#    * (packed) binary file
#
# Optional arguments:
#    * desired name of unpacked file
#    * use extended exit codes
#
# Returns:
#  0 successfully unpacked
RET_UNPACK_OK=0
#  1 generic unpacker - nothing to do; upx succeeded (--extended-exit-codes only)
RET_UNPACKER_NOTHING_TO_DO_OTHERS_OK=1
#  2 not packed or unknown packer
RET_NOTHING_TO_DO=2
#  3 generic unpacker failed; upx succeeded (--extended-exit-codes only)
RET_UNPACKER_FAILED_OTHERS_OK=3
#  4 generic unpacker failed; upx not succeeded
RET_UNPACKER_FAILED=4
# 10 other errors
#RET_OTHER_ERRORS=10

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

#
# Print help.
#
print_help()
{
	echo "Unpacking of the given executable file."
	echo ""
	echo "Usage:"
	echo "    $0 [ options ] file"
	echo ""
	echo "Options:"
	echo "    -h,        --help                 Print this help message."
	echo "    -e,        --extended-exit-codes  Use more granular exit codes than just 0/1."
	echo "    -o FILE,   --output FILE          Output file (default: file-unpacked)."
	echo "               --max-memory N         Limit the maximal memory of retdec-unpacker to N bytes."
	echo "               --max-memory-half-ram  Limit the maximal memory of retdec-unpacker to half of system RAM."
}

#
# Check proper combination of input arguments.
#
check_arguments()
{
	# Check whether the input file was specified.
	if [ -z "$IN" ]; then
		print_error_and_die "No input file was specified"
	fi

	# Conditional initialization.
	OUT=${OUT:="$IN"-unpacked}

	# Convert to absolute paths.
	IN="$(get_realpath "$IN")"
	OUT="$(get_realpath "$OUT")"
}

#
# Try to unpack the given file.
#
try_to_unpack()
{
	if [ $# -ne 2 ] || [ ! -s "$1" ] || [ -z "$2" ]; then
		echo "UNPACKER: wrong arguments" >&2
		return "$RET_NOTHING_TO_DO"
	fi

	local IN="$1"
	local OUT="$2"

	# Try to unpack via inhouse generic unpacker.
	# Create parameters.

	# Generic unpacker exit codes:
	# 0 Unpacker ended successfully.
	local UNPACKER_EXIT_CODE_OK=0
	# 1 There was not found matching plugin.
	local UNPACKER_EXIT_CODE_NOTHING_TO_DO=1
	# 2 At least one plugin failed at the unpacking of the file.
	local UNPACKER_EXIT_CODE_UNPACKING_FAILED=2
	# 3 Error with preprocessing of input file before unpacking.
	local UNPACKER_EXIT_CODE_PREPROCESSING_ERROR=3

	UNPACKER_PARAMS=("$IN" -o "$OUT")
	if [ ! -z "$MAX_MEMORY" ]; then
		UNPACKER_PARAMS+=(--max-memory "$MAX_MEMORY")
	elif [ ! -z "$MAX_MEMORY_HALF_RAM" ]; then
		UNPACKER_PARAMS+=(--max-memory-half-ram)
	fi
	echo ""
	echo "##### Trying to unpack $IN into $OUT by using generic unpacker..."
	echo "RUN: $UNPACKER ${UNPACKER_PARAMS[@]}"
	"$UNPACKER" "${UNPACKER_PARAMS[@]}"
	UNPACKER_RETCODE="$?"
	if [ "$UNPACKER_RETCODE" = "$UNPACKER_EXIT_CODE_OK" ]; then
		echo "##### Unpacking by using generic unpacker: successfully unpacked"
		return "$RET_UNPACK_OK"
	elif [ "$UNPACKER_RETCODE" = "$UNPACKER_EXIT_CODE_NOTHING_TO_DO" ]; then
		echo "##### Unpacking by using generic unpacker: nothing to do"
		# Do not return -> try the next unpacker
	else
		# UNPACKER_EXIT_CODE_UNPACKING_FAILED
		# UNPACKER_EXIT_CODE_PREPROCESSING_ERROR
		echo "##### Unpacking by using generic unpacker: failed"
		# Do not return -> try the next unpacker
	fi

	# Try to unpack via UPX
	echo ""
	echo "##### Trying to unpack $IN into $OUT by using UPX..."
	echo "RUN: upx -d $IN -o $OUT"
	upx -d "$IN" -o "$OUT" >"$DEV_NULL"
	if [ "$?" = "0" ]; then
		echo "##### Unpacking by using UPX: successfully unpacked"
		if [ "$EXTENDED" = "yes" ]; then
			if [ "$UNPACKER_RETCODE" = "$UNPACKER_EXIT_CODE_NOTHING_TO_DO" ]; then
				return "$RET_UNPACKER_NOTHING_TO_DO_OTHERS_OK"
			elif [ "$UNPACKER_RETCODE" -ge "$UNPACKER_EXIT_CODE_UNPACKING_FAILED" ]; then
				return "$RET_UNPACKER_FAILED_OTHERS_OK"
			fi
		else
			return "$RET_UNPACK_OK"
		fi
	else
		# We cannot distinguish whether upx failed or the input file was
		# not upx-packed
		echo "##### Unpacking by using UPX: nothing to do"
		# Do not return -> try the next unpacker
	fi

	# Return.
	if [ "$UNPACKER_RETCODE" -ge "$UNPACKER_EXIT_CODE_UNPACKING_FAILED" ]; then
		return "$RET_UNPACKER_FAILED"
	else
		return "$RET_NOTHING_TO_DO"
	fi
}

SCRIPT_NAME=$0
GETOPT_SHORTOPT="eho:"
GETOPT_LONGOPT="extended-exit-codes,help,output:,max-memory:,max-memory-half-ram"

# Check script arguments.
PARSED_OPTIONS=$(getopt -o "$GETOPT_SHORTOPT" -l "$GETOPT_LONGOPT" -n "$SCRIPT_NAME" -- "$@")

# Bad arguments.
[ $? -ne 0 ] && print_error_and_die "Getopt - parsing parameters failed"

eval set -- "$PARSED_OPTIONS"

while true; do
	case "$1" in
	-e|--extended-exit-codes)		# Use extented exit codes.
		[ "$EXTENDED" ] && print_error_and_die "Duplicate option: -e|--extended-exit-codes"
		EXTENDED="yes"
		shift;;
	-h|--help) 						# Help.
		print_help
		exit "$RET_UNPACK_OK";;
	-o|--output)					# Output file.
		[ "$OUT" ] && print_error_and_die "Duplicate option: -o|--output"
		OUT="$2"
		shift 2;;
	--max-memory-half-ram)
		[ "$MAX_MEMORY_HALF_RAM" ] && print_error_and_die "Duplicate option: --max-memory-half-ram"
		[ "$MAX_MEMORY" ] && print_error_and_die "Clashing options: --max-memory-half-ram and --max-memory"
		MAX_MEMORY_HALF_RAM="1"
		shift;;
	--max-memory)
		[ "$MAX_MEMORY" ] && print_error_and_die "Duplicate option: --max-memory"
		[ "$MAX_MEMORY_HALF_RAM" ] && print_error_and_die "Clashing options: --max-memory and --max-memory-half-ram"
		MAX_MEMORY="$2"
		if [[ ! "$MAX_MEMORY" =~ ^[0-9]+$ ]]; then
			print_error_and_die "Invalid value for --max-memory: $MAX_MEMORY (expected a positive integer)"
		fi
		shift 2;;
	--)								# Input file.
		if [ $# -eq 2 ]; then
			IN="$2"
			[ ! -r "$IN" ] && print_error_and_die "The input file '$IN' does not exist or is not readable"
		elif [ $# -gt 2 ]; then		# Invalid options.
			print_error_and_die "Invalid options: '$2', '$3' ..."
		fi
		break;;
	esac
done

# Check arguments and set default values for unset options.
check_arguments

CONTINUE=1
FINAL_RC=-1
while [  "$CONTINUE" = "1" ]; do
	try_to_unpack "$IN" "$OUT.tmp"
	RC="$?"
	if [ "$RC" = "$RET_UNPACK_OK" ] || [ "$RC" = "$RET_UNPACKER_NOTHING_TO_DO_OTHERS_OK" ] || [ "$RC" = "$RET_UNPACKER_FAILED_OTHERS_OK" ]; then
		FINAL_RC="$RC"
		mv "$OUT.tmp" "$OUT"
		IN="$OUT"
	else
		# Remove the temporary file, just in case some of the unpackers crashed
		# during unpacking and left it on the disk (e.g. upx).
		rm -f "$OUT.tmp"
		CONTINUE=0
	fi
done

if [ "$FINAL_RC" = "-1" ]; then
	exit "$RC"
else
	exit "$FINAL_RC"
fi
