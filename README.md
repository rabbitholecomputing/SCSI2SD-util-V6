# SCSI2SD-util-V6 Native+Universal Mac App (Cocoa)
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

* apt install libudev-dev
* apt install libusb-1.0

In the SCSI2SD-V6-Cocoa/SCSI2SD-util directory do this:

* buildtool clean
* buildtool

This will clean the existing build and rebuild the app.

Also copy the script in udev in the parent directory to /etc/udev/rules.d

To run the app you should be able to open the app wrapper using gopen or invoke it directly ./SCSI2SD-v6-util/build/SCSI2SD-v6-util/Products/SCSI2SD-v6-util.app/SCSI2SD-v6-util

# SCSI2SD-util-v6, a Native macOS application
SCSI2SD-util-v6 is an adaptation and native Cocoa reimplimentation of the SCSI2SD V6 configuration utility, as a native Mac application. Funded by Rabbit Hole Computing, this port includes a new command-line tool, for loading and saving configurations to SCSI2SD V6 boards, via USB, as well as firmware updates, via an integrated Device Firmware Update Utility.

