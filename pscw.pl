#!/usr/bin/perl -w

# A scaleway control tool in perl
#
# Copyright 2017 Vincent Sanders
# released under the MIT licence

# commands
# list servers and status
#   ps [OPTIONS]
# start a server
#   start [OPTIONS] SERVER
# stop a server
#   stop [OPTIONS] SERVER
#
# OPTIONS
# -v verbose
# -w <seconds> wait for completion timeout
# -t <token> API token

use strict;

use WebService::Scaleway;
use Data::Dumper;
use Getopt::Std;

my $usage_text = "Usage: $0 ps|start|stop [OPTIONS]\n";

my $operation = shift(@ARGV) or die $usage_text;

my $verbose = 0; # not verbose
my $wait_time = 300; # default wait time 5 minutes
my $apitoken = ""; # Scaleway API token

# process options
my %options=();
getopts("vw:t:", \%options) or die $usage_text;

if (defined $options{v}) {
    $verbose = 1;
}

if (defined $options{w}) {
    $wait_time = $options{w};
}

if (defined $options{t}) {
    $apitoken = $options{t};
}

if ((!defined $apitoken) || ($apitoken eq "")) {
    die "Need API token to access scaleway account\n";
}

# dispatch operation
if ($operation eq "ps") {
    exit command_ps($apitoken);
} elsif ($operation eq "start") {
    my $server_name = shift(@ARGV) or die "Server name not given\nUsage: $0 start [OPTIONS] SERVERNAME\n";
    exit command_start_stop($apitoken, $server_name, "running");
} elsif ($operation eq "stop") {
    my $server_name = shift(@ARGV) or die "Server name not given\nUsage: $0 stop [OPTIONS] SERVERNAME\n";
    exit command_start_stop($apitoken, $server_name, "stopped");
}

die "Unknown operation:" . $operation . "\n";


sub command_ps
{
    my ($apitoken) = @_;

    my $sw = WebService::Scaleway->new($apitoken);

    my @servers = $sw->list_servers();

    printf("%-38s", "SERVER ID");
    printf("%-12s", "STATUS");
    printf("%-16s", "PUBLIC IP");
    printf("%-16s", "NAME");
    print "\n";
    foreach my $server ( @servers ) {
	
	printf("%-38s", $server->{id});
	printf("%-12s", $server->{state});
	if (defined $server->{public_ip}) {
	    my $public_ip = $server->{public_ip};
	    printf("%-16s", $public_ip->{address});
	} else {
	    printf("%-16s", "none");
	}
	printf("%-16s", $server->{name});
	print "\n";
	#print Dumper($server);
    }
    return 0;
}

sub wait_for_state
{
    my ($sw, $nsserver, $tgt_state, $count) =@_;

    while ($count > 0) {
	sleep(1);
	$nsserver = $sw->get_server($nsserver);
	print $count . "s " if $verbose;
	$count--;
	if ($nsserver->{state} eq $tgt_state) {
	    print "\n" if $verbose;
	    return;
	}
    }
    print "\n" if $verbose;
}


# attempts t start or stop a server
#
# Parameters
# apitoken - The token necessary to access the API
# tgt_server - The target server
# tgt_state - The server state desired one of running, stopped
# 
sub command_start_stop
{
    my ($apitoken, $tgt_server, $tgt_state) = @_;

    my $sw = WebService::Scaleway->new($apitoken);
    my $org = $sw->organizations;

    my @servers = $sw->list_servers();

    foreach my $nsserver ( @servers ) {
	if ($nsserver->{name} eq $tgt_server) {
	    if (($nsserver->{state} eq "stopped") && ($tgt_state eq "running")) {
		print $nsserver->{name} . " is currently stopped starting it\n" if $verbose;

		if (!defined $nsserver->{public_ip}) {
		    my $newip = $sw->create_ip($org);
		    $newip->{server} = $nsserver->{id};
		    $sw->update_ip($newip);
		}
		$sw->perform_server_action($nsserver, "poweron");

		wait_for_state($sw, $nsserver, $tgt_state, $wait_time);

	    } elsif (($nsserver->{state} eq "running") && ($tgt_state eq "stopped")) {
		print $nsserver->{name} . " is currently running stopping it\n" if $verbose;
		$sw->perform_server_action($nsserver, "poweroff");

		wait_for_state($sw, $nsserver, $tgt_state, $wait_time);

		if (defined $nsserver->{public_ip}) {
		    $sw->delete_ip($nsserver->{public_ip}->{id});
		}

	    } elsif (($nsserver->{state} eq "running") && ($tgt_state eq "running")) {
		print $nsserver->{name} . " is already running\n" if $verbose;

	    } elsif (($nsserver->{state} eq "stopped") && ($tgt_state eq "stopped")) {
		print $nsserver->{name} . " is already stopped\n" if $verbose;

	    } else {
		print "unhandled state transition\n" if $verbose;
		print Dumper($nsserver) if $verbose;

	    }

	    return 0;
	}
    }
    print "server not found\n" if $verbose;
    return 1;
}
