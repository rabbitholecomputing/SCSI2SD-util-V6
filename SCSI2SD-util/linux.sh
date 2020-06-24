#!/bin/sh

echo "Configuring..."

FILE=./SCSI2SD-util/CPPModules/hid.c
ORIG=${FILE}.orig
LINUXFILE=./linux/hid.c

if [ -f "$ORIG" ]; then
    echo "Already configured for Linux build."
else
    echo "Copying file..."
    cp $FILE ${ORIG}
    cp $LINUXFILE $FILE
fi

echo "Done..."
