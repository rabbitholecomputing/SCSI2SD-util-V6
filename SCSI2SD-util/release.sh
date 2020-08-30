#!/bin/sh

echo "Building..."
xcodebuild clean
xcodebuild -target SCSI2SD-util-v6
xcodebuild -target scsi2sd-util-cli

DATE=`date +%Y%m%d_%H%M%S`
cd build/Release
tar zcvf ~/Desktop/SCSI2SD-util-v6-release-${DATE}.tgz SCSI2SD-util-v6.app scsi2sd-util-v6-cli

open "http://drive.google.com"

echo "Done."

