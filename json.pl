#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(pairwise);

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
    (my $package, my $module_ref) = ($_[0], $_[1]);
    my $response = qx(curl "https://smelt.suse.de/api/v1/basic/maintained/$package/" 2>/dev/null);
    my $graph = JSON->new->utf8->decode($response);
    my @bins;
    foreach my $m (@{$module_ref}) {
        if ( exists( $graph->{$m})) {
            my @keys = keys % {$graph->{$m}};
            my $upd_key = first {m/Update\b/} @keys;
            push (@bins, @{$graph->{$m}{$upd_key}});
        }
    }
    print Dumper(@bins);
    return @bins;
}

#Get JSON of maintenance status
my @packages = get_packages_in_RR(13024);

my $incident_repos ="http://download.suse.de/ibs/SUSE:/Maintenance:/14916/SUSE_Updates_SLE-Module-Python2_15-SP1_x86_64/,http://download.suse.de/ibs/SUSE:/Maintenance:/14916/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/";

my @repos = split(',',$incident_repos);
print Dumper(@repos);

@repos = qw{ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Server-Applications_15-SP1_x86_64/};


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


my @modules;
foreach (@repos){
    if ($_=~ m{SUSE_Updates_(?<product>.*)/}){
        push(@modules, $+{product});
    }
}

print "Packages: @packages, Modules: @modules\n";
my @binaries;
foreach my $p (@packages){
    push( @binaries, get_bins_for_packageXmodule($p,\@modules));
}

my @l3 = grep{ $_->{'supportstatus'} eq 'l3' } @binaries;
my @bind = zypper_search('--match-exact ypbindsad');
if (@bind == []){
    print "TRUE!";
}
print Dumper(@bind);

#print Dumper(@binaries);
             
