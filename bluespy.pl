#! /usr/bin/perl
#
#  $Id$
#
# Copyright (C) 2009 by Eivind Mork <eivindm@ifi.uio.no>
#



use Net::Bluetooth;
use strict;

my $report_after = 4;
my $leavelimit = 60*5;



my $num_checked = 0;
my $found = {};
my $name_mapping = {};
my $found_when = {};




read_names();
while (1) {
    scan();
    sleep 5;
}



sub read_names {
    open(FIL, $ENV{'HOME'}."/.bluespy") || return;

    print "Reading config file\n";
    while (<FIL>) {
        chomp;
        if (m/^UNIT\s+([A-F0-9:]+)\s+(\w.*)$/) {
            $name_mapping->{$1} = $2;
        }

        if (m/^FIRSTREPORT\s+(\d+)\s*$/) {
            $report_after = $1;
            print "Will report after $report_after scans\n";
        }
        if (m/^LEAVELIMIT\s+(\d+)\s*$/) {
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
            $found->{$addr} = 1;
            add_unit($addr, $device_ref->{$addr});
            push(@found_now, get_name($addr)) unless (get_name($addr) =~ /unknown/i);
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
            push(@left_now, get_name($addr)) unless (get_name($addr) =~ /unknown/i);  
            delete $found_when->{$addr};
        }
    }

    if (scalar @left_now > 0) {        
        print "We have new devices: \n";
        $msg .= "Left: ". join(", ",@left_now);
    } 

    if ($msg ne "" && $num_checked >= $report_after) {
        show_event($msg);
    } else {
        print "Not reached reporting limit for message: "
          .$msg."\n";
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




