#!/bin/sh
#
# Get RetDec share directory.
#

# Check arguments.
if [ "$#" -ne 1 ]; then
	echo "ERROR: Unexpected number of arguments."
	exit 1
fi

###############################################################################

VERSION_FILE_NAME="version.txt"
ARCH_SUFFIX="tar.xz"

SHA256HASH_REF="b54ba07e2f28143c9afe34a9d5b4114fb61f3c1175b9807caced471fec82001e"
VERSION="2018-02-08"

###############################################################################

ARCH_NAME="retdec-support"_"$VERSION.$ARCH_SUFFIX"

# Get install path from script options.
INSTALL_PATH="$1"
# Convert from Windows to Unix path on Windows.
case "$(uname -s)" in
	*Windows*|*CYGWIN*|*MINGW*|*MSYS*)
		INSTALL_PATH="$(echo "/$INSTALL_PATH" | sed -e 's/\\/\//g' -e 's/://')"
		;;
esac

SHARE_DIR="$INSTALL_PATH/share"
SHARE_RETDEC_DIR="$SHARE_DIR/retdec"
SUPPORT_DIR="$SHARE_RETDEC_DIR/support"

###############################################################################

cleanup()
{
	rm -rf "$SUPPORT_DIR"
}

# Share directory exists.
if [ -d "$SUPPORT_DIR" ]; then
	# Version file exists.
	if [ -f "$SUPPORT_DIR/$VERSION_FILE_NAME" ]; then
		VERSION_FROM_FILE=$(cat "$SUPPORT_DIR/$VERSION_FILE_NAME")
		# Version is ok.
		if [ "$VERSION" = "$VERSION_FROM_FILE" ]; then
			echo "$SUPPORT_DIR already exists, version is ok"
			exit
		else
			echo "versions is not as expected -> replace with expected version"
		fi
	fi

	cleanup
fi

# Make sure destination directory exists.
mkdir -p "$SUPPORT_DIR"

# Get archive using wget.
ARCH_URL="https://github.com/avast-tl/retdec-support/releases/download/$VERSION/$ARCH_NAME"
echo "Downloading archive from $ARCH_URL ..."
wget --no-verbose --read-timeout=10 "$ARCH_URL" -O "$SUPPORT_DIR/$ARCH_NAME"
WGET_RC=$?
if [ "$WGET_RC" -ne 0 ]; then
	echo "ERROR: wget failed"
	cleanup
	exit 1
fi

sha256hash()
{
	# To compute the SHA-256 hash, try several alternatives, based on what
	# command is available on the system.
	if command -v gsha256sum >/dev/null 2>&1; then
		gsha256sum "$@"
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$@"
	else
		sha256sum "$@"
	fi
}

# Compute hash of the downloaded archive.
echo "Verfifying archive's checksum ..."
SHA256HASH=$(sha256hash "$SUPPORT_DIR/$ARCH_NAME" | cut -d' ' -f1)
SHA256HASH_RC=$?
if [ "$SHA256HASH_RC" -ne 0 ]; then
	echo "ERROR: failed to compute the SHA-256 hash of the archive"
	cleanup
	exit 1
fi

# Check that hash is ok.
if [ "$SHA256HASH" != "$SHA256HASH_REF" ]; then
	echo "ERROR: downloaded archive is invalid (SHA-256 hash check failed)"
	cleanup
	exit 1
fi

# Unpack archive.
echo "Unpacking archive ..."
tar xf "$SUPPORT_DIR/$ARCH_NAME" "--directory=$SUPPORT_DIR" > /dev/null 2>&1
UNPACK_RC=$?
if [ "$UNPACK_RC" -ne 0 ]; then
	echo "ERROR: failed to unpack the archive"
	cleanup
	exit 1
fi

# Remove archive.
rm -f "$SUPPORT_DIR/$ARCH_NAME"

echo "RetDec support directory downloaded OK"
exit
