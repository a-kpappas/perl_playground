#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Data::Dumper;
use List::Util qw(first);

sub query_smelt {
    my $graphql = $_[0];
    my $api_url = qq( --request POST  https://smelt.suse.de/graphql/);
    my $header = qq( --header "Content-Type: application/json");
    my $data = qq( --data '{"query": "$graphql"}');
    my $response = qx(curl $api_url $header $data 2>/dev/null );
    return $response;
}

sub get_packages_in_RR{
    my $rr= $_[0] ;
    my $gql_query = "{incidents(incidentId: $rr){edges{node{incidentpackagesSet{edges{node{package{name}}}}}}}}";
    my $response = query_smelt($gql_query);
    my @packages;
    my $graph = JSON->new->utf8->decode($response);
    my @nodes= @{$graph->{'data'}{'incidents'}{'edges'}[0]{'node'}{'incidentpackagesSet'}{'edges'}};
    foreach (@nodes){
        push(@packages, $_->{'node'}{'package'}{'name'});
    }
    return @packages;
}

sub get_bins_for_packageXmodule{
    (my $package, my $module) = ($_[0], $_[1]);
    my $response = qx(curl "https://smelt.suse.de/api/v1/basic/maintained/$package/" 2>/dev/null);
    my $graph = JSON->new->utf8->decode($response);
    my @bins;
    if ( exists( $graph->{$module})) {
        my @keys = keys % {$graph->{$module}};
        my $upd_key = first {m/Update\b/} @keys;
        my @hashes = @{$graph->{$module}{$upd_key}};
        foreach  (@hashes) {
            push @bins, $_;
        }
    }
    return @bins;
}

#Get JSON of maintenance status
my @packages = get_packages_in_RR(13024);
my @repos = qw{ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/ http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Server-Applications_15-SP1_x86_64/};
my @modules;
foreach (@repos){
    if ($_=~ m{SUSE_Updates_(?<product>.*)/}){
        push(@modules, $+{product});
    }
}

my @binaries;
foreach my $p (@packages){
    foreach my $m (@modules){
        push @binaries , get_bins_for_packageXmodule($p,$m);
    }
}

print Dumper(@binaries);

