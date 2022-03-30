#!/usr/bin/env perl
use strict;
use warnings;

use FileHandle;
use AtlasData::Buoy;
use RamData::Flags qw(%FLAG);
use DBConexion::DBConexion qw(secure_connect_db);

MAIN:{

$|=1;

my $version =  "1.12";  # last version before svn


# get the deployment name (eg pm241a,tc004a)
my $dep =  shift @ARGV;

unless (defined $dep and $dep =~ /\d{3}[a-f]$/io)
  {die "\n$0: version $version\n\nUSAGE:\n\n  $0 pm###x [all met wind at rh swr rain lwr baro temp sal pres curr]\n\n"}

#get the options (eg rh, temp, sal, met)
my @opts = @ARGV;

#make a string for later pattern matching
my $opts=join(" ", @opts);
#if no options, or "all", load all tables
if (@opts == 0 or $opts =~ /all/io)
  {@opts = ();}

#things to load:
#  OPTION   TABLES          FILES
#  all      all             all
#  met      wind, temp, rh  met
# wind      wind            met
# at/air    temp            met
# rh/hum    rh              met
#swr/rad    swr             rad
# rain      rain            rain
#  lwr      lwr             lwr
# baro      baro            baro
# temp      temp            temp
#  sal      salinity        sals, salm, salc
# pres      wpres           pres
# curr      currents        curr

my ($ram_dir,$cal_dir,$dep2);

$ram_dir = $cal_dir = $dep = lc $dep;

if ($dep =~ /^pm/io)
  {
  $cal_dir =~ s/pm(\d{3})[a-f]/PM$1/io;
  $ram_dir =~ s/pm(\d{3})([a-f])/pm$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^qm/io)
  {
  $cal_dir =~ s/qm(\d{3})[a-f]/QM$1/io;
  $ram_dir =~ s/qm(\d{3})([a-f])/qm$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^pi/io)
  {
  $cal_dir =~ s/pi(\d{3})[a-f]/PI$1/io;
  $ram_dir =~ s/pi(\d{3})([a-f])/pi$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^ra/io)
  {
  $cal_dir =~ s/ra(\d{3})[a-f]/RA$1/io;
  $ram_dir =~ s/ra(\d{3})([a-f])/ra$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^ke/io)
  {
  $cal_dir =~ s/ke(\d{3})[a-f]/KE$1/io;
  $ram_dir =~ s/ke(\d{3})([a-f])/ke$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^pa/io)
  {
  $cal_dir =~ s/pa(\d{3})[a-f]/PA$1/io;
  $ram_dir =~ s/pa(\d{3})([a-f])/pa$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
elsif ($dep =~ /^ar/io)
  {
  $cal_dir =~ s/ar(\d{3})[a-f]/AR$1/io;
  $ram_dir =~ s/ar(\d{3})([a-f])/ar$1/io;
  $dep2=$1.$2;
  $ram_dir = '/Users/white/Repos/AtlasData/Processing/' . $ram_dir . '/';
  }
else  # it's not a standard next-gen mooring.   default to directory below
  {
  #this is a special case intended for salinity files from standard ATLAS
  # and current meter moorings, which will not have cal files etc.
  $cal_dir = "";  #no cal file needed, I hope
  $ram_dir =~ s/^(\w+)(\d{3})([a-f])$/$1$2/io;
  $dep2=$2.$3;
  # $ram_dir = '/archive/summer/summer4/data/seacat/' . $ram_dir . '/';
  }
opendir DIR, $ram_dir or die "Couldn't open directory $ram_dir!";
my @dir_list=readdir DIR;
closedir DIR;

my @files;

#this is the same algorithm used in places like "davg" to pick out
#  all the files:
foreach (@dir_list)
  {
  if (/^(met|rad|lwr|baro|rain|sal[cms]|pres|temp|curr)[0-9]?$dep2\.davg$/i)
    {push @files, $_;}
  }

  if (@files==0)
    {warn "No files found in $ram_dir!\n";}

# now we have all the possible files to use in @files.  Good if we WANT all.
#  if not:
my @filestoprocess;
my $yetmet=0;
foreach my $opt (@opts)   #note: loop never executes if no options
  {
  if    ($opt =~ /sal(inity)?/io) {$opt="sal[cms]";}
  elsif ($opt =~ /curr/io) {$opt="curr";}
  elsif ($opt =~ /swr/io) {$opt="rad";}
  foreach my $file (@files)
    {
    if ($file =~ /$opt/i or
        ($file =~ /met/io and $opt =~ /at|air|rh|hum|wind/io
		and not $yetmet))
      {
      push @filestoprocess, $file;
      if ($file =~ /met/io) {$yetmet=1;}
      }
    }
  }


## CWF 08/09/2004 - if @filestoprocess is empty then we
## should process all files!
if (scalar @filestoprocess) {
  @files = @filestoprocess;
}
#print "@files\n";

# now we have all the files we need to use
# But we need to get the salinity files in the right order:
# Must load combined file (sdc###X.davg) last.
# easily done, but not very versatiley, with a reverse sort by filename
@files = reverse sort @files;

my $cal;         # calibration filename to use
my $buoy;        # AtlasData::Buoy object created from it
my @all_sensors; # list of all sensor labels, e.g C2, WIND1, T11, P2
my $site;        # nominal site location, e.g. 010W

# Make sure to check the RAM directories first for cal files!
if ($cal_dir)
  {
  unless (-e "$ram_dir$dep.cal")
    {
#     printf "env($cal_dir): %s\n", $ENV{$cal_dir};
#     printf "calfile: %s.cal\n", $dep;

    $cal = $ENV{$cal_dir} . "/$dep.cal";
    $buoy=new AtlasData::Buoy($cal) or die "cal file $cal not found!";
    }
  else
    {
    $cal = "$ram_dir$dep.cal";
    $buoy=new AtlasData::Buoy($cal) or die "cal file $cal not found!";
    }
  print "Using cal file $cal.\n";
  }
else
  {print "No cal file being loaded!!!\b\n";}

if ($buoy)
  {
  @all_sensors=keys %{$buoy->{sensor_label}}; #used later to get sn, depth etc
  $site=$buoy->{DEPLOYMENT}{loc};  # something like "8N170W" or "00"
  # should come from database table Site, and therefore match what's in
  # the data database.  If there is no "buoy" object (seacat salinity),
  # get the site from the data file later on
  }


if (scalar(@files)==0)
  {print "no data files found!\n";}

#ok, now we've got all the information we need to put in the database,
# except for the time and data.

#connect to database
# my $dbh = secure_connect_db('SiteData','RAMdbload')
#   or die "Couldn't connect to database SiteData!";

open(my $dbh, '>', '/Users/white/Repos/AtlasData/Processing/RAMdbload_out.txt')
  or die "Couldn't connect to database SiteData!";

#now start the main loop:  go through each file we want to load
foreach my $file (@files)
  {
  print "\n$ram_dir$file\n";

  my $fh = new FileHandle($ram_dir.$file, "r")
    or die "Can't open input ".$ram_dir.$file.": $!";
  #load file header (5 lines)
  my @head;
  for my $line (0..4)
    {push @head, scalar <$fh>}

  #if no buoy location from cal file, try to get it from the data file
  unless ($site)
    {$site = get_site($head[1]);}
  #now load the whole file contents into memory
  #works the same as flag_data etc.; we produce a list of references
  # to lists containing all the elements from one line of the file.
  my @data;  # list of lists
  while ( <$fh> )   #read until EOF
    {
    my @line = split;
    push @data, [@line];
    }
  $fh->close;

  #these are the hashes that will contain the file and data specific
  # parameters.  There is a hash key (of some sort) for each sensor in
  # the current file.  met data use "wind","at","rh".temp data use "T1","T2"...
  #There are three distinct types of keys:
  # pressure, temperature use "sensor label", e.g. P1, T11
  # salinity and currents use depth, e.g. 120
  # everything else uses the text words below, e.g. baro,wind,at,rh
  # it doesn't really matter what is used, just a question of convenience
  my (%table,%sensor,%data_columns,%source_column,%qc_columns,
      %serial,%type,%depth);

  #For each sensor (key to the hash), the following are stored:
  # %table   database table to use for this datum
  # %sensor   instrument name, used to retrieve depth, serial numbers etc
  # %data_columns    contains numbers corresponding to the file column
  #                  numbers which will be stored as data in the database
  #                  This is a _list_; wind has 4 data columns, salinity 2
  # %source_columns    contains numbers corresponding to the file column
  #                    numbers which will be stored as "data_mode"
  #                    This is a _list_; in practice all just have one element
  # %qc_columns    contains numbers corresponding to the file column
  #                numbers which will be stored as "data_quality"
  #                This is a _list_; wind has 2 qualities

  # special variables for salinity only:
  my (%seacat_type,%seacat_serial,%module_type,%module_serial,
      %sal_type_column,@depth);
  #For each sensor (keyed by depth), the following are stored:
  # %seacat_type   contains the "senstype" from the first header line
  #                containing seacat serial numbers.  will be "7*", if present
  # %seacat_serial   contains the serial number from the first header line
  #                  containing seacat serial numbers.
  # %module_type   contains the "senstype" from the 2nd header line
  #                containing module serial numbers. Will be "24", if present
  # %module_serial   contains the serial number from the 2nd header line
  #                  containing module serial numbers.
  # %sal_type_column   contains the file column number which contains
  #                    the "senstype" which we should use

  # This primarily used for salinity hash key,
  # but also for verifying number of columns for temp and pres
  # it's just a list of the depths from the file header
  @depth = ($head[4] =~ m/(\d+)/og);

  # Now we fill all these hashes for the current file:

  my $warn1="\nBad number of columns in";
  my $warn2="file.\nIs it an old-style file without QC columns?\n";

  if ($file =~ m/met/io)
    {
    unless (@{$data[0]} == 15)
      {die "$warn1 MET $warn2";}
    if (@opts==0 or $opts =~ /met/io)  # if all to be loaded,
      {$opts .= " wind at rh ";}
    if ($opts =~ /wind/io)
      {
      $table{wind}="wind";
      $sensor{wind} = (grep {$_ =~ /^WIND\d+/io} @all_sensors)[0];
      @{$data_columns{wind}}  = (1,2,3,6);
      @{$source_column{wind}} = (5);   #ignore the second one, always the same
      @{$qc_columns{wind}}    = (4,7);
      }
    if ($opts =~ /at|air/io)
      {
      $table{temp}="temp";
      $sensor{temp} = (grep {$_ =~ /^AIR\d+/io} @all_sensors)[0];
      @{$data_columns{temp}}  = (9);
      @{$source_column{temp}} = (11);
      @{$qc_columns{temp}}    = (10);
      }
    if ($opts =~ /rh|hum/io)
      {
      $table{rh}="rh";
      $sensor{rh} = (grep {$_ =~ /^RH\d+/io} @all_sensors)[0];
      @{$data_columns{rh}}  = (12);
      @{$source_column{rh}} = (14);
      @{$qc_columns{rh}}    = (13);
      }
    } #end if file = met

  elsif ($file =~ m/rad|swr/io)
    {
    unless (@{$data[0]} == 6)
      {die "$warn1 SWR $warn2";}
    $table{swr}="swr";
    $sensor{swr} = (grep {$_ =~ /^SWR\d+/io} @all_sensors)[0];
    @{$data_columns{swr}}  = (1,2,3);
    @{$source_column{swr}} = (5);
    @{$qc_columns{swr}}    = (4);
    }

  elsif ($file =~ m/rain/io)
    {
    unless (@{$data[0]} == 6)
      {die "$warn1 RAIN $warn2";}
    $table{rain}="rain";
    $sensor{rain}  = (grep {$_ =~ /^RAIN\d+/io} @all_sensors)[0];
    @{$data_columns{rain}}  = (1,2,3);
    @{$source_column{rain}} = (5);
    @{$qc_columns{rain}}    = (4);
    }

  elsif ($file =~ m/lwr/io)
    {
    unless (@{$data[0]} == 5)
      {die "$warn1 LWR $warn2";}
    $table{lwr}="lwr";
    $sensor{lwr}  = (grep {$_ =~ /^LWR\d+/io} @all_sensors)[0];
    @{$data_columns{lwr}}  = (1);
    @{$source_column{lwr}} = (4);
    @{$qc_columns{lwr}}    = (3);
    }

  elsif ($file =~ m/baro/io)
    {
    unless (@{$data[0]} == 4)
      {die "$warn1 BARO $warn2";}
    $table{baro}="baro";
    $sensor{baro}  = (grep {$_ =~ /^BARO\d+/io} @all_sensors)[0];
    @{$data_columns{baro}}  = (1);
    @{$source_column{baro}} = (3);
    @{$qc_columns{baro}}    = (2);
    }

  elsif ($file =~ m/temp/io)
    {
   unless (@{$data[0]} == (@depth*3 + 1))
    {die "$warn1 TEMP $warn2";}
    my @sensors  = ( grep {$_ =~ /^T\d+/io} @all_sensors );

    # @sensors is full of labels like T1,T2,T3.  But they are numbered in
    #the order they are in the cal file, not neccesarily by depth.
    #first we have to sort them by depth, so they correspond to columns in
    #data files:
    @sensors = sort { $buoy->get_depth($a) <=> $buoy->get_depth($b)} @sensors;


    if (scalar(@sensors) != $#{$data[0]}/3)
      {
      print "number of TEMP sensors (".scalar(@sensors).") ".
	   "in cal file does not match data file (".($#{$data[0]}/3).") !\n\n";
      print "Do you wish to load anyway?";
      my $input =<STDIN>;
      if ($input =~ m/^y/io)
	{
	my @filedepths = split " ",$head[4];
	my @sensors2;

#print "@filedepths\n";

	foreach my $sens (@sensors)
	  {
	  foreach (@filedepths)
	    {
            if ($_ == $buoy->get_depth($sens))
                 {push @sensors2, $sens;print "\n:$sens:\n";}
            }
	  }
	@sensors=@sensors2;
	}
      else
        {return 0;}
      }

    my $data_column=1;
    foreach (@sensors)
     {
      $table{$_}="temp";
      $sensor{$_} = $_;
      @{$data_columns{$_}}  = ($data_column);
      @{$source_column{$_}} = ($data_column+2);
      @{$qc_columns{$_}}    = ($data_column+1);
      $data_column += 3;
      }
    }

  elsif ($file =~ m/sal/io)  #salinity
    {
# Salinity may have entirely different sensors from the cal file, since
#  it can be derived from both module and seacat data
#  So, we get info ONLY from data file, not from cal file (buoy object) at all.
    unless (@{$data[0]} == (@depth*5 + 1))
      {die "$warn1 SAL $warn2";}

    %sensor = map {($_,"")} (@depth);  #dummy hash for later use
    my @seacat_type   = $head[2] =~ m/(\d+):/og;
    my @seacat_serial = $head[2] =~ m/:(\d+)/og;
    my @module_type   = $head[3] =~ m/(\d+):/og;
    my @module_serial = $head[3] =~ m/:(\d+)/og;
    #now make some hashes, so these will work much like the other types
    %seacat_type   = map { ($depth[$_],$seacat_type[$_])}   (0..$#depth);
    %seacat_serial = map { ($depth[$_],$seacat_serial[$_])} (0..$#depth);
    %module_type   = map { ($depth[$_],$module_type[$_])}   (0..$#depth);
    %module_serial = map { ($depth[$_],$module_serial[$_])} (0..$#depth);
    undef @seacat_type;undef @seacat_serial;
    undef @module_type;undef @module_serial;

    my $data_column=1;
    foreach (@depth) #have to use array to keep in depth order
      {
      $table{$_}="salinity";
      @{$data_columns{$_}}  = ($data_column,$data_column+1);
      @{$source_column{$_}} = ($data_column+4);
      @{$qc_columns{$_}}    = ($data_column+3);
      $sal_type_column{$_}  = $data_column+2;
      $depth{$_}         = $_; # make this for later use like other files
      $data_column += 5;
      }
    }

  elsif ($file =~ m/curr/io)  #currents
    {
# Currents may have entirely different sensors from the cal file, since
#  we don't trust the cal files
#  So, we get info ONLY from data file, not from cal file (buoy object) at all.
    my $old=-999; my @newdepth;

    foreach (@depth)  # current file has 4 identical depth headers per sensor
      {if ($_ != $old) {push @newdepth,$_; $old=$_;}}
    @depth=@newdepth;undef @newdepth;
    unless (@{$data[0]} == (@depth*8 + 1))
      {die "$warn1 CURR $warn2";}

    %sensor = map {($_,"")} (@depth);  #dummy hash for later use
# hack to accomodate rare case of Nortek Aquadopp used (no telemetry, no cal file record)
# October 2017 DMD
#    my @serial = $head[2] =~ m/ARG\s*(\d+)/og;
    my @serial = $head[2] =~ m/A[RQ][GD]\s*(\d+)/og;
    #now make some hashes, so these will work much like the other types

    %serial = map { ($depth[$_],$serial[$_])} (0..$#depth);
    undef @serial;

    my $data_column=1;
    foreach (@depth) #have to use array to keep in depth order
      {
      $table{$_}="currents";
      @{$data_columns{$_}}  = ($data_column,$data_column+1,$data_column+2,$data_column+5);
      @{$source_column{$_}} = ($data_column+4);   #ignore the second one; always the same?
      @{$qc_columns{$_}}    = ($data_column+3,$data_column+6);
      $depth{$_}            = $_; # make this for later use like other files
# hack to accomodate rare case of Nortek Aquadopp used (no telemetry, no cal file record)
# October 2017 DMD
#      $type{$_}             = 40; # make this for later use like other files
      $type{$_}             = $head[2] =~ m/AQD/ ? 42 : 40;
      $data_column += 8;
      }
     }

  elsif ($file =~ m/pres/io)
    {
    unless (@{$data[0]} == (@depth*3 + 1))
      {die "$warn1 PRES $warn2";}
    my @sensors  = grep {$_ =~ /^P\d+/io} @all_sensors;

    # @sensors is full of labels like P1,P2,P3.  But they are numbered in
    #the order they are in the cal file, not necessarily by depth.
    #first we have to sort them by depth, so they correspond to columns in
    #data files:
    @sensors = sort { $buoy->get_depth($a) <=> $buoy->get_depth($b)} @sensors;

    if (@sensors != $#{$data[0]}/3)
      { die "number of PRES sensors in cal file (".scalar(@sensors).
	    ") does not match data file (".($#{$data[0]}/3).") !";}

    my $data_column=1;
    foreach (@sensors)
      {
      $sensor{$_} = $_;
      $table{$_}="wpres";
      @{$data_columns{$_}}  = ($data_column);
      @{$source_column{$_}} = ($data_column+2);
      @{$qc_columns{$_}}    = ($data_column+1);
      $data_column += 3;
      }
    }

  else
    {die "Unidentifiable file type $file!";}


  #unless salinity (already done) get serial numbers, types, depths...
  unless ($file =~ /sal|curr/io)
    {
    foreach (keys %sensor)
      {
      $serial{$_} = $buoy->get_serial_num($sensor{$_});
      $type{$_}   = $buoy->get_sensor_type($sensor{$_});
      $depth{$_}  = $buoy->get_depth($sensor{$_});
      }
    }

  # Now do the messy processing:
  # loop over each sensor

    my $ram_rows_changed= 0;
    my $realtime_rows_changed=0;
  foreach (keys %sensor)
    {

    #first, delete the old RAM records:

    print " \n Deleting old records for sensor $_ \n";
    my $dbcommand;

   if ($file =~ m/curr/io)  #currents
      {
      $dbcommand =
	"\n\nDELETE FROM $table{$_} WHERE deploy_id = \"$dep\" AND " .
	"(data_mode=5 OR data_mode=6 OR data_mode=7) AND " .
	"(senstype=$type{$_} AND sensor_sn=$serial{$_})\n";

      # Use this opportunity to set all realtime data that may
      # be present to use_site=0.  Completed RAM currents data
      # will always supercede all realtime records. DMD May2005

      my $rows = print $dbh (qq{ UPDATE $table{$_} SET use_site=0
                              WHERE deploy_id = '$dep'
                              AND (senstype=$type{$_} AND sensor_sn=$serial{$_})
                              AND data_mode < 5\n});

      unless (defined $rows)
         {warn ("Bad update!")}
      $realtime_rows_changed += $rows;

      }

    elsif ($file =~ /salc/io)
      #for combined salinity files, delete any truly combined daily
      # averages ONLY!!  Module and seacat data are deleted when
      # their respective files are loaded
      {
      $dbcommand =
	"\n\nDELETE FROM $table{$_} WHERE  deploy_id = \"$dep\" AND " .
        "(data_mode=5 OR data_mode=6 OR data_mode=7) AND " .
	"senstype=69\n";
      }

    elsif ($file =~ /sal[sm]/io)
      {
      #if a seacat or module file, delete the approriate type
      $dbcommand =
	"\n\nDELETE FROM $table{$_} WHERE  deploy_id = \"$dep\" AND " .
        "(data_mode=5 OR data_mode=6 OR data_mode=7) AND (" .
        (($file =~ /sals/io)?
	   "senstype=$seacat_type{$_} AND sensor_sn=$seacat_serial{$_}":
	   "senstype=$module_type{$_} AND sensor_sn=$module_serial{$_}").")\n";
      }
    else  # all the other file types
      {
      $dbcommand =
	"\n\nDELETE FROM $table{$_} WHERE deploy_id = \"$dep\" AND " .
	"(data_mode=5 OR data_mode=6 OR data_mode=7) AND " .
	"(senstype=$type{$_} AND sensor_sn=$serial{$_})\n";
      }

    my $rows = print $dbh $dbcommand;
    #print "$dbcommand\n";
    print "$rows rows deleted.\n\n";

    } # end of table query/delete ( end of loop over every key)


    # now we start from scratch and insert the new values
    # remember, file contents are in list of lists @data

    print " INSERTING new values  \n";

    # first, we'll see if this is one of the deployments that should
    # never be released.  These are in the database TAO_status.CoLocateSites
    # connect to database
    # Cleaned up this block May2005 DMD: added finish(), disconnect() for handles in this scope
    my $dont_use=0;
    # {
    # my $dbh_stat = secure_connect_db('TAO_status')
    #   or die "Couldn't connect to database TAO_status!";
    # my $dbcommand="SELECT * from TAO_status.CoLocateSites where deployment_id".
    #               " = \"$dep\"\n";

    # my $sth = $dbh_stat->prepare($dbcommand);
    # my $rows = $sth->execute();

    # if ($rows>0)
    #   {
    #   while (my @row = $sth->fetchrow_array())
	  #   {
    #     print "$row[0], $row[1] in TAO_status.CoLocateSites;".
	  #     " setting use_site to zero.\n";
    #     }
    #   $dont_use=1;
    #   }

    #   $sth->finish();
    #   $dbh_stat->disconnect();
    # }

    while (@data)
      {
      #@line is the next day's data from the file
      my @line=@{shift @data};

      #now make the 2 parts of the date to "DATE_ADD" later
      #datetime of Jan 1
      my $jan1date = substr($line[0],0,4).'-01-01 '.
	             substr($line[0],7,2).':'.
                     substr($line[0],9,2).':'.
		     substr($line[0],11,2);
      #days to add for day of year
      my $days_to_add = substr($line[0],4,3) - 1;

      #now loop over each column (temperatures by depth, for instance, or wind, at, rh)
      foreach my $sensor (keys %sensor)
        {
	# $use keeps track of whether "use_site" will be true or false
	# when the new data are added to the database.
        my $use;

	#first, we don't "use" any data from colocated buoys in CoLocateSites
        if ($dont_use)
	  {$use=0;}

	#second, we never "use" data from sds, sdm files:
        elsif ($file =~ /sal[sm]/io)
	  {$use=0;}

	#check to see if we have ANY good new data
	#kind of cryptic: wind has _4_ values, so make a string of 0/1 values
	#for whether each datum is < 1e30.  If all data bad, you get something
	#like "0000".  Then you "+ 0" to make it a number, and it is false.
	#"0000" is true otherwise.
	# so this basically says "if we have any good data..."
	elsif (  join("",map {$line[$_]< $FLAG{thresh}?1:0}
		             (@{$data_columns{$sensor}}) ) + 0  )
	  {
	  #data are good, use them
	  $use=1;

	  #now set use=0 for real-time
	  #for the seperate seacat and module salinity files, DON'T do this!

	  my $update;

	  if ($table{$sensor} =~ /curr/io) { # realtime for currents is updated per deployment
	     $update = undef;

	  } elsif ($table{$sensor} =~ /sal/io) {
	    if ($file =~ /salc/io) # don't set real-time use=0 for s,m files
	      {
	      $update=
	      "\nUPDATE $table{$sensor} SET use_site=0 ".
	      "WHERE deploy_id = \"$dep\" AND ".
	        "obs_time = DATE_ADD(\"$jan1date\", ".
		                     "INTERVAL $days_to_add DAY) ".
		"AND (data_mode=1 or data_mode=2 or data_mode=3) AND (".
	          (($seacat_type{$sensor}==0)?"0":"(senstype=$seacat_type{$sensor} AND sensor_sn=$seacat_serial{$sensor})").
	        " OR ".
	          (($module_type{$sensor}==0)?"0":"(senstype=$module_type{$sensor} AND sensor_sn=$module_serial{$sensor})").
	      ")\n";
	      } #end if "salc"
	    else {  #it's a salm (module) or sals (seacat) data file
	      $update = undef;
	    } #end elsif salinity

	  } else { # everything else not salinity or currents
	    $update=
	    "UPDATE $table{$sensor} SET use_site=0 ".
            "WHERE deploy_id = \"$dep\" AND ".
	      "obs_time = DATE_ADD(\"$jan1date\", INTERVAL $days_to_add DAY) ".
	      "AND (data_mode=1 or data_mode=2 or data_mode=3) AND ".
	      "(senstype=$type{$sensor} AND sensor_sn=$serial{$sensor})\n";
	  }

	  # Need to update real-time "use" flag?
	  if ($update)
	    {
	    my $rows = print $dbh $update;
	    #print "$update\n";
	    unless (defined $rows)
	      {warn ("Bad update!")}
	    $realtime_rows_changed += $rows;
	    #print "$rows rows altered\n";
	    }
	  } #end of "if we have good new data"

        else  #we have bad new data, "use" only if real time bad or nonexistent
	  {
      # no update for currents, already taken care of
      if ($table{$sensor} =~ /curr/io) {
        $use = 1;

        } else {
         my ($columns, $where_clause);
         # First, we need to see if real-time bad or nonexistent with
         #  a database query:
         # for everything BUT wind and sal, only one datum
         unless ($table{$sensor} =~ /wind|sal/io)
         {
            $columns = "data_avg";
            $where_clause="WHERE  obs_time = DATE_ADD(\"$jan1date\", ".
                          "INTERVAL $days_to_add DAY) ".
                          "AND  deploy_id = \"$dep\" ".
                          "AND  (data_mode=1 or data_mode=2 or data_mode=3) ".
                          "AND  (senstype=$type{$sensor} ".
                          "AND sensor_sn=$serial{$sensor})\n";
         }
         elsif ($table{$sensor} =~ /wind/io)
         {
            $columns = "u,v,speed,dir";
            $where_clause="WHERE  obs_time = DATE_ADD(\"$jan1date\", ".
                          "INTERVAL $days_to_add DAY) ".
                          "AND  deploy_id = \"$dep\" ".
                          "AND  (data_mode=1 or data_mode=2 or data_mode=3) ".
                          "AND  (senstype=$type{$sensor} ".
                          "AND sensor_sn=$serial{$sensor})\n";
         }
         elsif ($table{$sensor} =~ /sal/io)
         {
            $columns = "salinity, density";
            $where_clause="WHERE  obs_time = DATE_ADD(\"$jan1date\", ".
                          "INTERVAL $days_to_add DAY) ".
                          "AND  deploy_id = \"$dep\" ".
                          "AND  (data_mode=1 or data_mode=2 or data_mode=3) ".
                          "AND \n(".
                             (($seacat_type{$sensor}==0)?"0":"(senstype=$seacat_type{$sensor} AND sensor_sn=$seacat_serial{$sensor})").
                          " OR \n".
                             (($module_type{$sensor}==0)?"0":"(senstype=$module_type{$sensor} AND sensor_sn=$module_serial{$sensor})").
                          ")\n";
         }

         my $query="SELECT $columns FROM $table{$sensor} $where_clause ".
                   "ORDER BY obs_time \n";
         my $sth = print $dbh $query;
         my $rows = 0;

         if (defined $rows and $rows == 0) #returned "0E0", no rows found
            {$use=1;}
         # could have an "else" here, but why bother? @row will be empty
         my (@row, $count);
        #  while (@row = $sth->fetchrow_array())
        #  {
        #     $count += 1;
        #     if ($count != 1)
        #        {warn ("bad row count $count from query!");exit}
        #     #check for ALL flagged data in database
        #     if ( join("",map {$row[$_] < $FLAG{thresh}?0:1} (0..$#row)) + 0)
        #     {
        #        $use=1;
        #        my $update="UPDATE $table{$sensor} SET use_site=0 $where_clause";
        #        my $rows = print $dbh $update;
        #        #print "$update\n";
        #        unless (defined $rows)
        #           {die ("Bad update!")}
        #        $realtime_rows_changed += $rows;
        #        #print "\n$rows rows altered\n\n";
        #     }
        #     else  #there is some good data in database
        #     {
        #       $use=0;
        #     }
        #  }
        #  $sth->finish();
      }
	  }#done with new bad data (and good data, too;
           # and "sals" and "salm" files which are never "use"d)


        #now add the new RAM data!!
	my $insert;
        #first make the date correct for jan 1, then do a _database_ operation
	# to add the days of the year.

	#we use "REPLACE" to insert the data.  "INSERT" would work fine
	# (after deletion of pre-existing records), BUT we DON'T want to
	# delete pre-existing records for the combined salinity file (sdc).
	# So we just use "REPLACE" for all.

	# for all types but salinity, here's the statement:
        unless ($file =~ /sal/io)
	  {
	  $insert = "REPLACE INTO $table{$sensor} VALUES(\"$site\", ".
                    "DATE_ADD(\"$jan1date\", INTERVAL $days_to_add DAY), ".
		    "$use, ".
	            "\"". uc $dep ."\", ".
		    join(",",@line[@{$data_columns{$sensor}}]). ", ".
	            join(",",@line[@{$source_column{$sensor}}]). ", ".
	            join(",",map {($line[$_],"NULL")} (@{$qc_columns{$sensor}})). ", ".
	            "$type{$sensor}, ".
	            "\"$serial{$sensor}\", ".
	            "$depth{$sensor})\n";
          #the "join" statements are needed to list multiple data for one
          # database record.  This is required for salinity (which also has
          # density), and wind, which has U, V, SPD, DIR.  I think all data
	  # types have only one source column, but it is maintained as a list.
	  # The quality has 2 columns for wind (SPD, DIR).
	  # The quality additionally needs "null" values inserted after each
	  # quality in the data file.  These "null" values get inserted into
	  # columns of "cal_quality" in the database.  So the quality join
	  # statement will result in something like "2,NULL" for most datatypes
	  # and something like "2,NULL,2,NULL" for wind.

	  }
	else # it IS salinity:
	  {
	  my $sample_type = @line[$sal_type_column{$sensor}]; #24 or 70/71
	  my $serial;

	  if ($module_type{$sensor} == $sample_type)
	    {$serial = $module_serial{$sensor};}
	  elsif ($seacat_type{$sensor} == $sample_type)
	    {$serial = $seacat_serial{$sensor};}
	  elsif ($sample_type == 69)
	    {$serial = $seacat_serial{$sensor}.":".$module_serial{$sensor};}
	  elsif ($sample_type == 0)
	    {}
	  else
	    {die "whoops. problem here!";}

	  unless ($sample_type == 0) #if we got a "00" type sample, skip it
	    {
	    $insert = "REPLACE INTO $table{$sensor} VALUES(\"$site\", ".
	              "DATE_ADD(\"$jan1date\", INTERVAL $days_to_add DAY), ".
	              "$use, ".
	              "\"". uc $dep ."\", ".
	              join(",",@line[@{$data_columns{$sensor}}]). ", ".
	              join(",",@line[@{$source_column{$sensor}}]). ", ".
	              join(",",map {($line[$_],"NULL")} (@{$qc_columns{$sensor}})). ", ".
	              "$sample_type, ".
	              "\"". $serial ."\", ".
	              "$depth{$sensor})\n";
	    #see the section above for a description of the join statements
	    }
	  }  #done with unless it's a salinity file...

	#this does all insertions:
	if ($insert)
          {
	  my $rows = print $dbh $insert;
	  #print "$insert\n";
	  unless (defined $rows)
	    {die ("Bad insert!")}
	  if ($rows==1 or $rows==2)
	    #a "REPLACE" returns "2" when a line was substituted.
	    # not sure why, unless it considers that both the old row
	    # and the new one were affected
	    {$ram_rows_changed++;}
	  else
	    {die "bad number of rows changed";}
	  #print "$rows rows altered\n";
	  }
        } #end loop over sensors

      } #end of inserting one line of data

    print "$realtime_rows_changed real-time rows updated\n";
    print "$ram_rows_changed RAM rows inserted\n";

  if ( $file =~ m/sal/io and $ram_rows_changed )  #salinity
    # update table SiteData.LoadStatus with salinity algorithm variant used['SAL78_T68','SAL78_T90']
    # and date of loading
    {
      my $sal78_variant = ( $head[1] =~ m/\*SALCORR\s*$/i ) ?
                          'SAL78_T68'
                        : 'SAL78_T90';

      print "\nUpdating table LoadStatus with salinity algorithm type \'$sal78_variant\' ...\n";
      my $update = ( is_deployed($dbh, $dep) ) ?
                   qq{UPDATE LoadStatus SET ram_seawater_algorithm='$sal78_variant',ram_seawater_load_dt=CURDATE() WHERE deploy_id='$dep' \n}
                 : qq{INSERT INTO LoadStatus(deploy_id,ram_seawater_algorithm,ram_seawater_load_dt) VALUES('$dep','$sal78_variant',CURDATE()) \n};

      my $success = print $dbh($update);
      unless ($success)
         {warn ("*** Table LoadStatus not updated correctly!")}
    }


  } #end loop over files

  #now run the SQL "adjustment script" if present:
# disabled 6Jun2005 DMD
# enabled with modified subroutine 11Sept2007 DMD
  # sql_script($ram_dir,$dep,$dbh);


  close $dbh


} # end MAIN




########################## sub get_site ############################

sub get_site
  {
  my $line = shift;
  print "$line\n";

  my ($latd,$latm,$NorS,$lond,$lonm,$EorW)=
       ($line =~ /DEPLOYED AT\s+(\d+)\s+(\d+.?\d*)([NnSs]?)\s?,\s?(\d+)\s+(\d+.?\d*)([EeWw]?)/io);

  my $lat    = $latd + $latm/60;
  $lat       = -$lat if $NorS eq 'S';

  my $long   = ($lond + $lonm/60);
  $long      = 360 - $long if $EorW eq 'W';

  my $site= eval {TAOPerl::SiteLabel::find($lat,$long )};
  print "Using site: $site\n";
  return $site;

  }  # end sub get_site



########################## sub is_deployed ############################

# checks for existing entry for this deployment ID in database table LoadStatus
#

sub is_deployed {

   my ($dbh,$deplid) = @_;

# issue query
   my $sth = $dbh->prepare (qq{SELECT COUNT(*) from LoadStatus WHERE deploy_id='$deplid'})
      or bail_out_mysql ("Cannot prepare query");
   $sth->execute ()
      or bail_out_mysql ("Cannot execute query");
# read results of query
   my $count = $sth->fetchrow_array();
   bail_out_mysql ("Error during retrieval") if ($sth->err);
# clean up
   $sth->finish ()
      or bail_out_mysql ("Cannot finish query");
   return $count;
}


########################## sub sql_script ############################

# executes the SQL commands in a default script file.  Used for special
# exceptions to the standard rules.

# This needs much more work:
# my exception scripts are usually written to be easily read
# and have multi-line commands. 6Jun2005 DMD
# consider what the following would do:
#
#   UPDATE temp SET use_site=0
#       WHERE deployment_id= ....
#       ... ;
#

# reinstated with modifications 11Sept2007 DMD

sub sql_script
  {
  my ($ram_dir,$deployment, $dbh) = @_;

  my $scriptfile = $ram_dir . $deployment . '.sql';
  if (-r $scriptfile)
    {
    my $fh = new FileHandle($scriptfile, "r")
      or die "File $scriptfile exists, but can\'t be opened: $!";
    my @scriptlines = <$fh>;
    $fh->close;
    print "\nScript file found: $scriptfile\nExecuting ...\n";

    my $sqlcommand = '';
    foreach (@scriptlines)
      {
         next if ( /^#/ );
         next if (/^\s*$/);
         chomp;
         $sqlcommand .= " $_";

         if ( $sqlcommand =~ /;\s*$/) {
            if ( $sqlcommand =~ /USE\s+SiteData/i ) {
#               print " - Skipping \"$sqlcommand\"\n";
               $sqlcommand = '';
               next;
            }

            $sqlcommand =~ s/^\s*//g;
            $sqlcommand =~ s/\s+/ /g;
            $sqlcommand =~ s/;\s*$//;
#            print " + $sqlcommand;\n";
            my $rows = $dbh->do($sqlcommand);
            unless (defined $rows)
              {die ("command failed: $sqlcommand\n")}
            else
              {print "$rows rows changed: $sqlcommand\n";}

            $sqlcommand = '';
         }
      } #end loop over script lines

    } #end readable file

  else
    {print "\nNo script file found: $scriptfile\n";}

  }  # end sub sql_script


#################
### print error code and string, then exit
#################
sub bail_out_mysql {
   my ($message) = shift;
   die "$message\nError $DBI::err ($DBI::errstr)\n";
}

__END__

=pod

=head1 NAME

B<RAMdbload> - Load TAO delayed mode data into database.

=head1 VERSION

This document refers to B<RAMdbload> version 1.10

=head1 SYNOPSIS

  RAMdbload deployment_id [OPTION ...]

  $ RAMdbload pi220a

  $ RAMdbload pi220a curr

B<deployment_id> label is B<REQUIRED>. The default OPTION is B<all>.

=head2 OPTIONS

  +----------+----------------+------------------+
  | OPTION   | TABLES         | FILES            |
  +----------+----------------+------------------+
  | all      | all            | all              |
  | met      | wind, temp, rh | met              |
  | wind     | wind           | met              |
  | at, air  | temp           | met              |
  | rh, hum  | rh             | met              |
  | swr, rad | swr            | rad              |
  | rain     | rain           | rain             |
  | lwr      | lwr            | lwr              |
  | baro     | baro           | baro             |
  | temp     | temp           | temp             |
  | sal      | salinity       | sals, salm, salc |
  | pres     | wpres          | pres             |
  | curr     | currents       | curr             |
  +----------+----------------+------------------+

=head1 DESCRIPTION

Program to load RAM-derived daily average data from TAO Next-Generation
moorings into an SQL database (SiteData) containing all daily averaged data.

=head1 HISTORY

=over 2

=item 2002/305

P. A'Hearn - Version 1.00

=item ???

Nuria Ruiz - Modifications

=item 2003/008

P. A'Hearn - Version 1.01 removed the query before delete, as it takes a LONG
time to execute on the temp database

=item 2003/134

P. A'Hearn - Version 1.02 fixed a problem with subsurface sensors (e.g. P1, P2,
P3) not being sorted by depth, so that 180m pressures might be inserted as 300
or 500. Problem could have affected any data for which cal file sensors were
not in depth order.

=item 2003/134147

P. A'Hearn - Version 1.03 allowed override of number of temperature columns
different from number in cal file

=item 2004/350

P. A'Hearn - Version 1.04 added check of TAO_status.CoLocateSites

=item 2005/003

P. A'Hearn - Version 1.05 added automatic running of /home/drumlin/data/nxram/
pm###/pm###x.sql script, if it exists.

=item 2005/006

P. A'Hearn - Version 1.06 modified for changed SiteData database with
cal_quality

=item 2005/035

P. A'Hearn - Version 1.07 modified to handle SonTek current meter data in "curr"
files

=item 01May2005

D Dougherty - Version 1.08 modified to set all real-time data to use_site=0
for "curr" loading as per Tricia Plimpton request. D Dougherty 06Jun2005
disable automatic exception script processing (sql_script): results can be
unpredicatble and potentially harmful

=item July2006

DMD - Version 1.09 updated paths from /home/drumlin/data/nxram ->
/home/data/nxram /home/summer4/data/seacat ->
/archive/summer/summer4/data/seacat

=item August2007

DMD - Version 1.10 when salinity data is loaded, make entry into table
SiteData.LoadStatus to indicate whether seawater algorithms used T68 or T90
temperature as indicated by the presence of a new field "*SALCORR" in the
second line of the data file header

=item Sept2007

DMD - reinstated sql_script subroutine with modifications to parse script
files. (Needs testing)

=back

=cut
