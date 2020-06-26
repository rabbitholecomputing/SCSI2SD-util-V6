#!/bin/sh

echo "Configuring..."

FILE=./SCSI2SD-util/Modules/hid.c
LINUXFILE=./linux/hid.c

echo "Copying Linux file..."
cp $LINUXFILE $FILE

echo "Done..."
