#!/bin/sh

echo "Resetting..."

FILE=./SCSI2SD-util/CPPModules/hid.c
ORIG=${FILE}.orig
MACFILE=./macos/hid.c

if [ -f "$FILE" ]; then
    echo "Copying Mac file..."
    cp ${FILE} ${ORIG}
    cp $MACFILE $FILE
else
    echo "No file to reset."
fi

echo "Done..."
