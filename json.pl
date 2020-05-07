#!/usr/bin/perl
use strict;
use warnings;
use version;
use JSON;
use Data::Dumper;
use List::Util qw(first);
#use List::MoreUtils qw(pairwise);

sub query_smelt {
    my $graphql = $_[0];
    my $api_url = "--request POST https://smelt.suse.de/graphql/";
    my $header = '--header "Content-Type: application/json"';
    my $data = qq( --data '{"query": "$graphql"}');
    return  qx(curl $api_url $header $data 2>/dev/null );
}

sub get_packages_in_RR{
    my $rr= $_[0] ;
    my $gql_query = "{incidents(incidentId: $rr){edges{node{incidentpackagesSet{edges{node{package{name}}}}}}}}";
    my $graph = JSON->new->utf8->decode( query_smelt($gql_query));
    my @nodes= @{$graph->{'data'}{'incidents'}{'edges'}[0]{'node'}{'incidentpackagesSet'}{'edges'}};
    my @packages = map { $_->{'node'}{'package'}{'name'} } @nodes;
    return @packages;
}

sub get_bins_for_packageXmodule{
    # This function uses the term package in the way that SMELT uses it. Not as
    # an rpm but as a set of binaries that receive varying levels of support and are
    # spread through modules.
    (my $package, my $module_ref) = ($_[0], $_[1]);
    my $response = qx(curl "https://smelt.suse.de/api/v1/basic/maintained/$package/" 2>/dev/null);
    my $graph = JSON->new->utf8->decode($response);
    # Get the modules to which this package provides binaries.
    my @existing_modules = grep{ exists( $graph->{$_}) } @{$module_ref};
    my @arr;
    foreach my $m (@existing_modules) {
        # The refs point to a hash of hashes. We only care about the value with
        # the codestream key. The Update key is different for every SLE
        # Codestream so instead of maintaining a LUT we just use a regex for it.
        my $upd_key = first {m/Update\b/} keys % {$graph->{$m}};
        push (@arr, @{$graph->{$m}{$upd_key}});
    }
    return  map { $_->{'name'} => $_ } @arr;
}

sub zypper_search {
    my $params = shift;
    my @fields = ('status', 'name', 'type', 'version', 'arch', 'repository');
    my @ret;

    my $output = qx{zypper -n se -s $params};
    print $output."\n";

    for my $line (split /\n/, $output) {
        my @tokens = split /\s*\|\s*/, $line;
        next if $#tokens < $#fields;
        my %tmp;

        for (my $i = 0; $i < scalar @fields; $i++) {
            $tmp{$fields[$i]} = $tokens[$i];
        }

        push @ret, \%tmp;
    }
    # Remove header from package list
    shift @ret;
    return \@ret;
}

#Get JSON of maintenance status
my @packages = get_packages_in_RR(13024);

#my $incident_repos ="http://download.suse.de/ibs/SUSE:/Maintenance:/14916/SUSE_Updates_SLE-Module-Python2_15-SP1_x86_64/,http://download.suse.de/ibs/SUSE:/Maintenance:/14916/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/";


my @repos = qw{ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Server-Applications_15-SP1_x86_64/};
print Dumper(@repos);


my @modules;
foreach (@repos){
    if ($_=~ m{SUSE_Updates_(?<product>.*)/}){
        push(@modules, $+{product});
    }
}

print "Packages: @packages, Modules: @modules\n";
my %binaries;
foreach my $p (@packages){
    %binaries = ( %binaries, get_bins_for_packageXmodule($p, \@modules));
}


my @l2 = grep{ ($binaries{$_}->{'supportstatus'} eq 'l2') } keys %binaries; 
my @l3 = grep{ ($binaries{$_}->{'supportstatus'} eq 'l3') } keys %binaries;

#my $seref = zypper_search("--match-exact -i @l2 @l3");
#print Dumper( (@l2, @l3)  );
foreach (@l2,@l3){
    if ( !(system("rpm -q $_ 1>/dev/null")>>8) ) {
        my $ver= qx(rpm -q --queryformat '%{VERSION}.%{RELEASE}' $_);
        print  version->parse($ver)." ";
        $binaries{$_}->{'oldversion'} = $ver ;
    }
    else{
        $binaries{$_}->{'oldversion'}="Not installed";
    }
#    printf "%-20s %-20s\n",$_, $binaries{$_}->{'oldversion'}
}

foreach (@l2,@l3) {
    if ( !(system("rpm -q $_ 1>/dev/null")>>8) ) {
        $binaries{$_}->{'oldversion'} = qx(rpm -q --queryformat '%{VERSION}-%{RELEASE}' $_);
    } else {
        $binaries{$_}->{'oldversion'}="Not installed";
    }
    printf "%-20s %-20s\n",$_, $binaries{$_}->{'oldversion'}
}


# my %l2 = grep{ $_->{'supportstatus'} eq 'l2'} %binaries;
# my %l3 = grep{ $_->{'supportstatus'} eq 'l3'} %binaries;
# print Dumper(%l3);
#my $seref = zypper_search("--match-exact -i @names");
#foreach ( @{$seref} ){
#    print "$_->{'version'}\n";
#}
#print Dumper($seref);

#print "New: ".Dumper(@new_binaries);
             
