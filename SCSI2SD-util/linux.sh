#!/bin/sh

echo "Configuring..."

FILE=./SCSI2SD-util/CPPModules/hid.c
ORIG=${FILE}.orig
LINUXFILE=./linux/hid.c

if [ -f "$FILE" ]; then
    echo "Copying Linux file..."
    cp $FILE ${ORIG}
    cp $LINUXFILE $FILE
fi

echo "Done..."
