#!/usr/bin/perl

#    This file is part of IFMI PoolManager.
#
#    PoolManager is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#

use warnings;
use strict;

require '/opt/ifmi/sm-common.pl';
require '/opt/ifmi/smnotify.pl';
require '/opt/ifmi/ssendstatus.pl';

my $conf = &getConfig;
my %conf = %{$conf};

use Proc::Daemon;
use Proc::PID::File;

Proc::Daemon::Init;
if (Proc::PID::File->running()) {
    exit(0);
}

my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

while ($continue) {

  # Start profile on boot

  if ($conf{settings}{do_boot} == 1) {
    my $uptime = `cat /proc/uptime`;
    $uptime =~ /^(\d+)\.\d+\s+\d+\.\d+/;
    my $rigup = $1;
    if (!-f "/nomine") {
      if (($rigup < 300)) {
        my $filecheck = 0; $filecheck = 1 if (-e "/opt/ifmi/nomine");
        my $mcheck = `ps -eo command | grep -cE [S]M-miner`;
        if ($mcheck == 0 && $filecheck == 0) {
          &startCGMiner;
        }
      }
    }
  }

  #  broadcast node status
  if ($conf{farmview}{do_bcast_status} == 1) {
   &bcastStatus;
  }

  # Email
  if ($conf{monitoring}{do_email} == 1) {
    if (-f "/tmp/smnotify.lastsent") {
      if (time - (stat ('/tmp/smnotify.lastsent'))[9] > ($conf{email}{smtp_min_wait} -10)) {
        &doEmail;
      }
    } else { &doEmail; }
  }

  # Graphs should be no older than 5 minutes
  my $graph = "/var/www/IFMI/graphs/smsummary.png";
  if (-f $graph) {
    if (time - (stat ($graph))[9] > 290) {
      exec('/opt/ifmi/smgraph.pl');
    }
  } else {
    exec('/opt/ifmi/smgraph.pl');
  }

    # Get the ad
    `cd /tmp ; wget --quiet -N http://ads.miner.farm/pm.html ; cp pm.html adata`;

  sleep 60;
}

1;