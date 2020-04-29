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

sub get_package_name{
    my $rr= $_[0] ;
    my $gql_query = "{incidents(incidentId: $rr){edges{node{incidentpackagesSet{edges{node{package{name}}}}}}}}";
    my $response = query_smelt($gql_query);
    my @packages;
    my $json = JSON->new;
    $json = $json->utf8([1]);
    my $graph = $json->utf8->decode($response);
    my @nodes= @{$graph->{'data'}{'incidents'}{'edges'}[0]{'node'}{'incidentpackagesSet'}{'edges'}};
    my $n = @nodes;
    foreach (@nodes){
        print ("$_->{'node'}{'package'}{'name'}");
        push(@packages, $_->{'node'}{'package'}{'name'});
    }
    return @packages;
}

#Get JSON of maintenance status
my @packages = get_package_name(13024);
my @repos = qw{"http://download.suse.de/ibs/SUSE:/Maintenance:/13024/SUSE_Updates_SLE-Module-Basesystem_15-SP1_x86_64/"};
my @products = grep (m{SUSE_Updates_(?<product>.*)/}, @repos);
print "Pr: @products";
