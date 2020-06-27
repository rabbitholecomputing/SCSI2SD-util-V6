#!/bin/sh

PROJECT_DIR=$1
XIB_NAME=${3:-MainMenu.xib}
LANG_NAME=${2:-Base}
FULL_XIB_NAME=${PROJECT_DIR}/${LANG_NAME}.lproj/${XIB_NAME}

echo "Replacing usesAutolayout and translatesAutoresizingMaskIntoConstraints"
echo "INFO: For some reason recent versions of Xcode do not allow this to be turned off..."
echo "      This script will need to be run after you visit the xib again in Xcode as it will"
echo "      automatically regenerate the xib and turn autolayout back on automatically."
echo " "
cat ${FULL_XIB_NAME} | sed 's/useAutolayout="YES"/useAutolayout="NO"/g' | sed 's/translatesAutoresizingMaskIntoConstraints="YES"/translatesAutoresizingMaskIntoConstraints="YES"/g' > ${FULL_XIB_NAME}.new
mv ${FULL_XIB_NAME} ${FULL_XIB_NAME}.old
echo "Saved old xib as ${XIB_NAME}.old"
mv ${FULL_XIB_NAME}.new ${FULL_XIB_NAME}
echo "Replaced original xib with modified one."
echo "Done."

exit 0