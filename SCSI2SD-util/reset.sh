#!/bin/sh

echo "Resetting..."

FILE=./SCSI2SD-util/CPPModules/hid.c
ORIG=${FILE}.orig
LINUXFILE=./linux/hid.c

if [ -f "$ORIG" ]; then
    echo "Resetting file..."
    cp ${ORIG} ${FILE}
    cp $LINUXFILE $FILE
else
    echo "No file to reset."
fi

echo "Done..."
