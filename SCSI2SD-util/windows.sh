#!/bin/sh

echo "Resetting..."

FILE=./SCSI2SD-util/Modules/hid.c
ORIG=${FILE}.orig
WINFILE=./windows/hid.c

echo "Copying Windows file..."
cp $WINFILE $FILE

echo "Done..."
