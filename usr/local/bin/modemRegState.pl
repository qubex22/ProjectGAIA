#!/usr/bin/perl
############################################################################
# checksignal.pl
#
# Runs a series of diagnostic tests on the modem to determine what the
# 
# - Signal strength is
# - Network registration state
# - SIM state (Pin Lock / Blocked / other error )
# - Service level available and used (GPRS/3G/etc..)
# - Modem Type / IMEI / Firmware version
#
# Author:       Andrew O'Connell
############################################################################


use strict;
use warnings;

use Device::Modem;
use Getopt::Std;

$| = 1;

my (%opts, @recipients);
my ($modem, $msg);

my $device = '/dev/ttyUSB2';
my $pin    = '';

main();

sub main {
        init();
        set_opts();
        send_cmds();
        disconnect();
}



sub init {
    $modem = Device::Modem->new(port => $device);

    if ($modem->connect(baudrate => 115200)) {
    } else {
        print "Sorry, no connection with modem possible, tests aborted\n";
    }
}

sub set_opts {
    $modem->is_active();
    $modem->echo(0);
    $modem->verbose(1);
}

sub send_cmds {
    my $answer="";
    $modem->atsend("AT\r");
    $answer = $modem->answer()."\n";


    #print "Registration state                 : ";
    $modem->atsend("AT+CREG?\r");
    $answer = $modem->answer();
    # +CREG: 0,1,8903,00227F8E
    # +CREG: 0,1 
    # +CREG: 0,1,0016,02C1F35D
    if ($answer =~ /^.*,(\d)(,|$)?.*$/ms)
    {
        my($regState)=$1;
	exit $regState

	#if ($regState == 0) { print "Not Registered, Not searching\n"; exit 0 }
	#if ($regState == 1) { print "Registered to home network\n"; exit 1 }
	#if ($regState == 2) { print "Not registered, searching for network\n"; exit 2}
	#if ($regState == 3) { print "Registration denied\n"; exit 3}
	#if ($regState == 5) { print "Registered, roaming\n"; exit 5}
    }
    else
    {
	print " ** Infomation Not Available **\n"
    }


}

sub disconnect {
    $modem->disconnect();
}

