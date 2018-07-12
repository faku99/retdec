#!/usr/bin/env bash
#
# Decompiler's configuration. This file should be included in every decompilation script.
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

##
## Paths (everything has to be without the ending slash '/').
##

# Paths relative from script path.
INSTALL_BIN_DIR="$SCRIPT_DIR"
UNIT_TESTS_DIR="$INSTALL_BIN_DIR"
INSTALL_SHARE_DIR="$INSTALL_BIN_DIR/../share/retdec"
INSTALL_SUPPORT_DIR="$INSTALL_SHARE_DIR/support"
INSTALL_SHARE_YARA_DIR="$INSTALL_SUPPORT_DIR/generic/yara_patterns"

## generic configuration
GENERIC_TYPES_DIR="$INSTALL_SUPPORT_DIR/generic/types"
GENERIC_SIGNATURES_DIR="$INSTALL_SHARE_YARA_DIR/static-code"

## ARM-specific configuration
ARM_ORDS_DIR="$INSTALL_SUPPORT_DIR/arm/ords"

## X86-specific configuration
X86_ORDS_DIR="$INSTALL_SUPPORT_DIR/x86/ords"

## BIN2LLVMIR parameters
#
# The following list of passes is -O3
#   * with -disable-inlining -disable-simplify-libcalls -constprop -die -dce -ipconstprop -instnamer
#   * without -internalize -inline -inline-cost -notti -deadargelim -argpromotion -simplify-libcalls -loop-unroll -loop-unswitch -sroa -tailcallelim -functionattrs -memcpyopt -prune-eh
#
# The following options are useful during debugging of bin2llvmirl optimizations.
#   * -print-after-all -debug-only=idioms -print-before=idioms -print-after=idioms
#
# -unreachable-funcs is automatically removed in decompilation script when the
# -k/--keep-unreachable-funcs parameter is used.
#
# - Optimization -phi2seq is needed to be run at the end and not to run two
# times. This is the reason why it is placed at the very end.
#
BIN2LLVMIR_PARAMS_DISABLES="-disable-inlining -disable-simplify-libcalls"
BIN2LLVMIR_LLVM_PASSES_ONLY="-instcombine -tbaa -targetlibinfo -basicaa -domtree -simplifycfg -domtree -early-cse -lower-expect -targetlibinfo -tbaa -basicaa -globalopt -mem2reg -instcombine -simplifycfg -basiccg -domtree -early-cse -lazy-value-info -jump-threading -correlated-propagation -simplifycfg -instcombine -simplifycfg -reassociate -domtree -loops -loop-simplify -lcssa -loop-rotate -licm -lcssa -instcombine -scalar-evolution -loop-simplifycfg -loop-simplify -aa -loop-accesses -loop-load-elim -lcssa -indvars -loop-idiom -loop-deletion -memdep -gvn -memdep -sccp -instcombine -lazy-value-info -jump-threading -correlated-propagation -domtree -memdep -dse -dce -bdce -adce -die -simplifycfg -instcombine -strip-dead-prototypes -globaldce -constmerge -constprop -instnamer -domtree -instcombine"

BIN2LLVMIR_PARAMS="-provider-init -decoder -verify -main-detection -idioms-libgcc -inst-opt -register -cond-branch-opt -syscalls -stack -constants -param-return -local-vars -inst-opt -simple-types -generate-dsm -remove-asm-instrs -class-hierarchy -select-fncs -unreachable-funcs -inst-opt -value-protect $BIN2LLVMIR_LLVM_PASSES_ONLY $BIN2LLVMIR_LLVM_PASSES_ONLY -simple-types -stack-ptr-op-remove -inst-opt -idioms -global-to-local -dead-global-assign -instcombine -phi2seq -value-protect $BIN2LLVMIR_PARAMS_DISABLES"

# -never-returning-funcs

## Paths to tools.
#
FILEINFO="$INSTALL_BIN_DIR/retdec-fileinfo"
FILEINFO_EXTERNAL_YARA_PRIMARY_CRYPTO_DATABASES=(
	"$INSTALL_SHARE_YARA_DIR/signsrch/signsrch.yara"
)
FILEINFO_EXTERNAL_YARA_EXTRA_CRYPTO_DATABASES=(
	"$INSTALL_SHARE_YARA_DIR/signsrch/signsrch_regex.yara"
)
AR="$INSTALL_BIN_DIR/retdec-ar-extractor"
BIN2PAT="$INSTALL_BIN_DIR/retdec-bin2pat"
PAT2YARA="$INSTALL_BIN_DIR/retdec-pat2yara"
CONFIGTOOL="$INSTALL_BIN_DIR/retdec-config"
EXTRACT="$INSTALL_BIN_DIR/retdec-macho-extractor"
DECOMPILER_SH="$INSTALL_BIN_DIR/retdec-decompiler.sh"
ARCHIVE_DECOMPILER_SH="$INSTALL_BIN_DIR/retdec-archive-decompiler.sh"
SIG_FROM_LIB_SH="$INSTALL_BIN_DIR/retdec-signature-from-library-creator.sh"
UNPACK_SH="$INSTALL_BIN_DIR/retdec-unpacker.sh"
LLVMIR2HLL="$INSTALL_BIN_DIR/retdec-llvmir2hll"
BIN2LLVMIR="$INSTALL_BIN_DIR/retdec-bin2llvmir"
IDA_COLORIZER="$INSTALL_BIN_DIR/retdec-color-c.py"
UNPACKER="$INSTALL_BIN_DIR/retdec-unpacker"

DEV_NULL="/dev/null"
