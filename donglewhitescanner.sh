#!/bin/bash
#-x for debug -e to exit on error -v to print everything
#Script that execs the rtl dongle scanner

#deattach mod dvb
modprobe -r dvb_usb_rtl28xxu

TIMESTAMP=$(date -I)
ROUTE=/home/pi/whitespacedongle/${TIMESTAMP}

function restart_gps(){
	sudo killall gpsd
        sudo gpsd /dev/ttyUSB0 -F /var/run/gpsd.sock

}


function check_devices(){
	rtl=$(lsusb | grep RTL)
	gps=$(lsusb | grep PL2303)

	if [ "$rtl" ] ; then
		if [ "$gps" ]; then
			echo 0
		else
			echo 1
		fi
	else
		echo 2
	fi
}

#run rtl_power
function run_scanner(){
	local unique_file=$(date +"%T")
	local filename=${3}/${unique_file}
	rtl_power -f ${1}:${2}:1M -1 ${filename}.csv
	python flatten.py ${filename}.csv > ${filename}-F.csv
	echo $?
	if [ $? -eq "0" ]; then
		rm ${filename}.csv
	fi
	sed -i 's/,/\t/' ${filename}-F.csv
	python gps-dws.py >> ${filename}-F.csv
}

#create direcotry to save samples
function create_directory(){
	if [ -d $ROUTE ] ; then
		break
	else
		#there is no directory for this date, it creates a directory for all measures of the same date
		mkdir $ROUTE
		if [ $? -eq "0" ]; then
			echo "Measure directory created"
		else
			echo "Error creating directory"
			exit 1
		fi
	fi
}

#checking avalaible memory
function check_mem_and_start(){

	MEMORY_A=$(df -h | awk 'NR==2{print $5}' | sed s/%/''/g)

	if [ "$MEMORY_A" -lt 95 ] ; then
		measure_loop
	else
		#aplay mem_warning.wav
		echo "Not enough memory avalaible"
		exit 4
	fi
}


function measure_loop(){

	var=$(check_devices)
	case "$var" in
		0 )
			create_directory
				while true
					do
						echo "Starting measures"
						run_scanner 560M 566M $ROUTE
						if [ $? -eq "0" ]; then
							echo "Success"
						else
							echo "Error executing function"
							# exit 2
							break
						fi
					done
			;;
		1)
			echo "GPS not connected"
			;;
		2)
			echo "RTL not connected"
			;;
		*)
			logger -i -t donglewhitescanner "unexpected error"
			echo "unexpected error"
			;;
	esac
}

#############################################

check_mem_and_start

exit 0
