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

    $modem->atsend("AT+CSQ\r");
    $answer = $modem->answer();
    if ($answer =~ /^\+CSQ:\s(\d{1,2}),(\d{1,2}).*$/ms)
    {
        my($signal)=$1;
        my($quality)=$2;

	exit $signal

        #print $signal."/32 ";

        #if ($quality == 99) { print "   (Bit error rate cannot be determined)\n"}
        #if ($quality < 99)  { print "   (Bit error rate = ".$quality.")\n"}
    }
    else
    {
        print " ** Infomation Not Available **\n"
    }


}

sub disconnect {
    $modem->disconnect();
}

