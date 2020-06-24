#!/bin/sh

echo "Configuring..."

FILE=./SCSI2SD-util/CPPModules/hid.c.orig
LINUXFILE=./linux/hid.c

if [ -f "$FILE" ]; then
    echo "Already configured for Linux build."
else
    echo "Copying file..."
    cp $FILE ${FILE}.orig
    cp $LINUXFILE $FILE
fi

echo "Done..."
