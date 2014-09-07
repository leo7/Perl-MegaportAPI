#!/usr/bin/env perl

use 5.10.0;
use strict;
use warnings;

use JSON;
use Time::Piece;
use LWP::UserAgent;

my $username = 'username';
my $password = 'password';

my $ua = LWP::UserAgent->new;

my ($response, $company, $token);

# Login to Megaport and generate session token
say "Logging in as $username";
$response = $ua->post('https://api.megaport.com/login', { username => $username, password => $password });
if (!$response->is_success) {
    die sprintf "Error: %s", $ua->content;
}

$company = (keys %{from_json($response->content)->{permissions}})[0]; # Grab first company_id from permissions hash
$token = from_json($response->content)->{session} or die "Error: Unable to decode JSON";

# GET list of notifications
say "Fetching list of notifications..";
$response = $ua->get("https://api.megaport.com/secure/party/company/$company/notification?token=$token");
if (!$response->is_success) {
    die sprintf "Error: %s", $ua->content;
}

my $notifications = from_json($response->content) or die "Error: Unable to decode JSON";

foreach my $n (@$notifications) {
    # Convert start time to human-readable
    # Times are given in millisecond resolution timestamps
    my $start = Time::Piece->strptime(substr($n->{start}, 0, -3), '%s')->datetime;

    say sprintf('    [%-2d - %s] %s', $n->{notificationId}, $start, $n->{subject});

    # Now that we've done something useful with it, mark as read
    if (!$n->{readDate}) {
        $response = $ua->post("https://api.megaport.com/secure/party/person/notification/$n->{notificationId}?token=$token");
    }
}

# Logout
$response = $ua->post("https://api.megaport.com/logout/$token");
if (!$response->is_success) {
    die sprintf "Error: %s", $ua->content;
}

say "\nLogged out";
exit 0;
