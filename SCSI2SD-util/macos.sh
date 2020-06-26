#!/bin/sh

echo "Resetting..."

FILE=./SCSI2SD-util/Modules/hid.c
ORIG=${FILE}.orig
MACFILE=./macos/hid.c

echo "Copying Mac file..."
cp $MACFILE $FILE

echo "Done..."
