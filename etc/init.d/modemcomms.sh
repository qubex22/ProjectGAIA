#!/bin/bash
### BEGIN INIT INFO
# Provides:          modemcomms.sh
# Required-Start:    $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: servicio del modem
# Description:       inicia la conexion 4g/3g/2g
### END INIT INFO

#
# QMI Modem Comms Script  - embeddedpi.com
#
# Release : 09/04/2018  RAW IP VERSION
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# dms = modem device details
# nas = cellular network details
# wds = cellular data connection details
#
# required files :
#
# /usr/local/bin/modemRegState.pl modemSigLevel.pl  modemSoftReset.pl qmi-network-raw-raw
# Additional Packages : 
#
# apt-get install libqmi-utils udhcp
#
#
#
# /etc/network/interfaces.d/wwan0 :
#iface wwan0 inet manual
#    pre-up ifconfig wwan0 down
#    pre-up ifconfig wwan1 down
#    pre-up for _ in $(seq 1 10); do /usr/bin/test -c /dev/cdc-wdm0 && break; /bin/sleep 1; done
#    pre-up for _ in $(seq 1 10); do /usr/bin/qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength && break; /bin/sleep 1; done
#    pre-up /usr/local/bin/qmi-network-raw /dev/cdc-wdm0 start
#    pre-up udhcpc -i wwan0
#    post-down /usr/local/bin/qmi-network-raw /dev/cdc-wdm0 stop
#
#/etc/sim.conf :
#SIMPIN=1234
#
#/etc/qmi-network.conf :
#APN=pp.vodafone.co.uk
#
#
estado=`qmicli -d /dev/cdc-wdm0 --dms-get-operating-mode | grep -o online`

while [ "$estado" != online ]
do 
	qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode=online
	estado=`qmicli -d /dev/cdc-wdm0 --dms-get-operating-mode | grep -o online`
	sleep 5
done

function checkRegState
{
        # Can we dial out yet?
        while true
        do

                # this is a cut down version of the modemstatus perl script
                # to just run the signal quality parts and return the
                # signal level as an exit code

                estado=`qmicli -d /dev/cdc-wdm0 --dms-get-operating-mode | grep -o online`

		while [ "$estado" != online ]
		do 
			qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode=online
			estado=`qmicli -d /dev/cdc-wdm0 --dms-get-operating-mode | grep -o online`
			sleep 5
		done

		 /usr/local/bin/modemSigLevel.pl
                returnCode=$?

                if (( $returnCode >= 10 ))
                then
                        echo "Modem communications: Signal strength - $returnCode/32"
                fi

                if (( $returnCode <= 10  && $returnCode > 5 ))
                then
                        echo "Modem communications: Signal strength low, re-orient or upgrade antenna  - $returnCode/32"
                fi

                if (( $returnCode <= 5 ))
                then
                        echo "Modem communications: Signal strength very low, expect problems obtaining a connection, re-orient or upgrade antenna  - $returnCode/32"
                fi

                if (( $returnCode == 99 ))
                then
                        echo "Modem communications: No signal detected - Check antenna pigtail & antenna. "
                fi



                # this is a cut down version of the modemstatus perl script
                # to just run the registration state parts and return the
                # registration state as an exit code
                /usr/local/bin/modemRegState.pl
                returnCode=$?

                # Exit code 1 or 5 is good to go (registered or roaming)
                if (( $returnCode == 1 || $returnCode == 5  ))
                then
                        echo "Modem communications: Registered OK on network ($returnCode)"
                        return 0
                fi

                if (( $returnCode == 0 || $returnCode == 3 ))
                        then
                                        echo "Modem communications: Failed to register on network"
                                        # we're in "Not Registered, Not searching" or "Registration denied" state
                                        # hard reset the modem and try again
                                        echo "Modem communications: Resetting Modem..."
                                        /usr/local/bin/modemSoftReset.pl
                                        sleep 30
                                        return 1
                fi
                echo "Modem communications: Searching for network..."
                # We're still waiting for the modem to connect to the network
                sleep 6
        done
}



function checkSimPin
{
        # Check for SIM PIN details
        if [ -e /etc/sim.conf ]
        then
                . /etc/sim.conf
                if [ "$SIMPIN" != "" ]
                then
                        echo "Modem communications: PIN Unlock Running"
                        qmicli -d /dev/cdc-wdm0 --dms-uim-verify-pin=PIN,$SIMPIN
                        simRetCode=$?
                        if (( $simRetCode != 0 ))
                        then
                                echo "Modem communications: PIN Unlock FAILED "
                                return 1
                        fi
                fi
        fi

        return 0
}
function networkConnect
{
        # At this point we're registered on the network so make an attempt to get connected

        counter=0
        while true
        do
                ifup wwan0
                sleep 5
                qmicli -d /dev/cdc-wdm0 --wds-get-packet-service-status | grep -q "disconnected"
                if (( $? == 1 ))
                then
                                echo "Modem communications: Modem Connected"
                                return 0
                fi

                # Failed to connect?
                echo "Modem communications: Modem Connect FAILED ($counter/3)"
                ifdown wwan0
                qmi-network-raw  /dev/cdc-wdm0 stop

                if [ $counter -eq 3 ]
                then
                        echo "Modem communications: Resetting Modem..."
                        # If this fails you could also toggle the modem hardware reset line via LK12+GPIO23
                        /usr/local/bin/modemSoftReset.pl
                        sleep 30
                        return 1
                fi

                ((counter++))
        done
}

function monitorConnection
{
        # Keep an eye on the state of the cellular connection
        while true
        do
                # echo "Modem communications: Checking connection status"

                qmicli -d /dev/cdc-wdm0  --wds-get-packet-service-status | grep -q "disconnected"
                if (( $? == 0 ))
                then
                        echo "Modem communications: Connection disconnected, restarting..."
                        # We've disconnected for some reason
                        ifdown wwan0
                        qmi-network-raw  /dev/cdc-wdm0 stop
                        return 1
                fi

                # For reasons unknown  qmi-network  /dev/cdc-wdm0 status will still
                # report 'connected' even if you remove the antenna (as does the front led!) so let's check the network too

                # A search for 'not-registered' should catch all, once the antenna was replaced modem required registration AOK

                # Stage 2/3 disconnect
                # qmicli -d /dev/cdc-wdm0  --nas-get-serving-system
                # [/dev/cdc-wdm0] Successfully got serving system:
                #       Registration state: 'not-registered'
                #       CS: 'detached'
                #       PS: 'detached'
                #
                # modemstat
                # SIM status                     : SIM unlocked and ready
                # Signal Quality                     : 99/32    (Bit error rate cannot be determined)
                # Network Registration         :  ** Information Not Available **
                # Registration state             : Not registered, searching for network
                #qmicli -d /dev/cdc-wdm0  --nas-get-serving-system |  grep -q "detached"
                #if (( $? == 0 ))
                #then
                #       # We've disconnected for some reason
                #       ifdown wwan0
                #       qmi-network-raw  /dev/cdc-wdm0 stop
                #       break
                #fi

                # Stage 1 disconnect
                # qmicli -d /dev/cdc-wdm0  --nas-get-serving-system
                #[/dev/cdc-wdm0] Successfully got serving system:
                #       Registration state: 'not-registered-searching'
                #       CS: 'attached'
                #       PS: 'attached'
                #
                # modemstat
                # SIM status                     : SIM unlocked and ready
                # Signal Quality                     : 99/32    (Bit error rate cannot be determined)
                # Network Registration         :  ** Information Not Available **
                # Registration state             : Not registered, searching for network

                qmicli -d /dev/cdc-wdm0  --nas-get-serving-system |  grep -q "not-registered"
                if (( $? == 0 ))
                then
                        # We've disconnected for some reason
                        echo "Modem communications: network disconnected, restarting..."
                        ifdown wwan0
                        qmi-network-raw /dev/cdc-wdm0 stop
                        return 1
                fi

                # Ideally we should periodically check the end-to-end connection works by running a http curl
                # "headers only" check against a tame target server. (this check uses cellular data)
                #
		# ** Only do check when flag file /tmp/doNetworkCheck exists **
                
                counter=0
                returnCode=0

                while true && [ -e /tmp/doNetworkCheck ]
                do
			rm /tmp/doNetworkCheck
                        echo "Modem communications: Running Curl end-to-end check ($counter/2)"
                        # This is the standard MS Windows network connectivity check server,
                        # ideally should be YOUR server.
                        websiteToCheck="http://www.msftncsi.com/ncsi.txt"
                        curl -I -s --connect-timeout 5 --max-time 10 $websiteToCheck | grep "HTTP/1.1 200 OK"
                        returnCode=$?
                        if (( $returnCode == 0 || $counter == 2 ))
                        then
                                # Got a positive result or run out of tries
                                break
                        fi
                        ((counter++))
                        echo "Modem communications: Trying again in 20 seconds..."
                        sleep 20
                done

                if (( $returnCode != 0 ))
                then
                        # Can't communicate with remote server
                        echo "Modem communications: Can't communicate with remote server, restarting..."

                        # Print diag info so it ends up in syslog file
                        echo "Modem communications: Result of website check"
                        curl -I -s --connect-timeout 5 --max-time 10 $websiteToCheck
                        echo "Modem communications: --nas-get-system-info"
                        qmicli --nas-get-system-info -d /dev/cdc-wdm0
                        echo "Modem communications: --nas-get-serving-system"
                        qmicli  --nas-get-serving-system -d /dev/cdc-wdm0
                        echo "Modem communications: --nas-get-cell-location-info "
                        qmicli --nas-get-cell-location-info -d /dev/cdc-wdm0
                        echo "Modem communications: --nas-get-signal-strength "
                        qmicli  --nas-get-signal-strength  -d /dev/cdc-wdm0
                        echo "Modem communications: --wds-get-current-data-bearer-technology"
                        qmicli   --wds-get-current-data-bearer-technology -d /dev/cdc-wdm0
                        echo "Modem communications: --wds-get-packet-service-status"
                        qmicli -d /dev/cdc-wdm0  --wds-get-packet-service-status

                        echo "Modem communications: ifdown wwan0"
                        ifdown wwan0
                        echo "Modem communications: qmi-network-raw stop"
                        qmi-network-raw  /dev/cdc-wdm0 stop

                        # Restart dial out sequence
                        return 1
                fi

                echo "Modem Communications: Network check AOK"
                # Running these checks every 1-5mins is usually sufficient.
                sleep 60
        done
}
###############################################################################

# Start from a clean slate
ifdown wwan0
qmi-network-raw  /dev/cdc-wdm0 stop

while true
do
        checkRegState
        if (( $? == 0 ))
        then
                checkSimPin
                if (( $? == 0 ))
                then
                        networkConnect
                        if (( $? == 0 ))
                        then
                                monitorConnection
                        fi
                fi
        fi
done

