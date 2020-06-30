# SCSI2SD-V6-Cocoa
New repo for Xcode based SCSI2SD application for V6 boards.

Building for Mac OS 10.6:
-
* You must open up the MainMenu.xib AS SOURCE CODE and do the following:
	* replace translatesAutoresizingMaskIntoConstraints="NO" with
	translatesAutoresizingMaskIntoConstraints="YES" everywhere
	* replace useAutoLayout="NO" to useAutoLayout="YES"
	* disableAutolayout.sh does this for you.  
	    * You need to invoke it as "./disableAutolayout.sh SCSI2SD-util"

for some reason, if you open up the file as an interface builder file, it gets re-written and there is no way through the GUI to turn those flags off anymore.

Building for Linux and other UNIX's
-
* Install GNUstep
* Install both the Xcode lib in libs-xcode and
* the buildtool in tools-buildtool
* invoke the buildtool in the same directory that contains the .xcodeproj

make sure you installed the following packages as well:

apt install libudev-dev
apt install libusb-1.0

