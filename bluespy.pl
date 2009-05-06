#! /usr/bin/perl
#
#
#      Copyright (C) 2009 by Eivind Mork <eivindm@ifi.uio.no>
#
#
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; version 2 of the License.
#    
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.



# ubuntu packages:
#    libqt-perl
#    libnet-bluetooth-perl

use Net::Bluetooth;
use strict;

my $report_after = 4;
my $leavelimit = 60*5;



my $num_checked = 0;
my $found = {};
my $name_mapping = {};
my $found_when = {};
my $ignore = {};



read_config();
while (1) {
    scan();
    sleep 5;
}



sub read_config {
    open(FIL, $ENV{'HOME'}."/.bluespy") || return;

    print "Reading config file\n";
    while (<FIL>) {
        chomp;
        if (m/^UNIT\s+([A-F0-9:]+)\s+(\w.*)$/i) {
            $name_mapping->{$1} = $2;
        }

        if (m/^IGNORE\s+([A-F0-9:]+)/i) {
            $ignore->{$1} = 1;
            print "Ignoring address $1\n";
        }

        if (m/^FIRSTREPORT\s+(\d+)\s*$/i) {
            $report_after = $1;
            print "Will report after $report_after scans\n";
        }
        if (m/^LEAVELIMIT\s+(\d+)\s*$/i) {
            $leavelimit = $1;
            print "Will report leaves after $leavelimit seconds abscense\n";
        }
    }
    close FIL;
}

sub scan {
    $num_checked++;

    print"$num_checked scan\n";
    my @found_now;
    my @left_now;
    my $device_ref = get_remote_devices();
    foreach my $addr (keys %$device_ref) {
        print "Address: $addr Name: $device_ref->{$addr}\n";
        $found_when->{$addr} = time();
        unless ($found->{$addr}) {
            if ($ignore->{$addr}) {
                print "Ignoring $addr ($device_ref->{$addr})\n";
            } else {
                $found->{$addr} = 1;
                add_unit($addr, $device_ref->{$addr});
                push(@found_now, get_name($addr)) unless (get_name($addr) =~ /unknown/i);
            }
        } else {
            print "\tNo message, found before: $device_ref->{$addr} (".
              get_name($addr).")\n";
        }
    }
    my $msg = "";
    if (scalar @found_now > 0) {        
        print "We have new devices: \n";
        $msg = "Arrived ". join(", ",@found_now)."  ";
    } 
    
    foreach my $addr (keys %$found_when) {
        if (time() - $found_when->{$addr} > $leavelimit) {
            if ($ignore->{$addr}) {
                print "Ignoring $addr's leaving ($device_ref->{$addr})\n";
            } else {
                push(@left_now, get_name($addr)) unless (get_name($addr) =~ /unknown/i);  
            }
            delete $found_when->{$addr};
        }
    }

    if (scalar @left_now > 0) {        
        print "Someone left: \n";
        $msg .= "Left: ". join(", ",@left_now);
    } 

    if ($msg ne "") {
        if ($num_checked >= $report_after) {
            show_event($msg);        
        } else {
            print "Not reached reporting limit for message: "
              .$msg."\n";
        }
    }


    print "------------\n";
    
}

sub show_event{
    my ($msg) = @_;
    
    $msg =~ s/[^a-zA-Z0-9-_ :\(\),]//g;

    print "message: $msg\n";
    system("kdialog --title \"Notification from Bluespy\" --passivepopup \"$msg\" 10");
    #system("kdialog --msgbox \"$msg\"");
    
}

sub get_name {
    my ($addr) = @_;
    if ($name_mapping->{$addr}) {
        return $name_mapping->{$addr};
    }
    return "Unknown";
}

sub add_unit {
    my ($addr, $name) = @_;
 
    if ($name =~ /unknown/i) { # skip writing
        return;
    }
    unless ($name_mapping->{$addr}) {
        $name_mapping->{$addr} = $name;

        open(FIL, ">>".$ENV{'HOME'}."/.bluespy") || die("error adding new units to .bluespy");
        print FIL "UNIT $addr $name\n";
        close FIL;                                                   
    }
    
}




