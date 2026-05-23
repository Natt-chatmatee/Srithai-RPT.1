#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;

my $port = $ARGV[0] || 3000;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
my $root = dirname(abs_path($0));

my %mime = (
    html => 'text/html; charset=utf-8',
    css  => 'text/css',
    js   => 'application/javascript',
    png  => 'image/png',
    jpg  => 'image/jpeg',
    ico  => 'image/x-icon',
);

my $server = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    LocalPort => $port,
    Type      => SOCK_STREAM,
    Reuse     => 1,
    Listen    => 10,
) or die "Cannot bind to port $port: $!\n";

print "Server running at http://localhost:$port\n";
$| = 1;

while (my $client = $server->accept()) {
    $client->autoflush(1);
    eval {
        my $req = '';
        # Read request line with timeout protection
        eval {
            local $SIG{ALRM} = sub { die "timeout\n" };
            $req = <$client>;
        };
        defined $req and length $req or do { close $client; next };

        my (undef, $path) = split(' ', $req, 3);

        # drain headers
        while (my $line = <$client>) {
            last if $line =~ /^\r?\n$/;
        }

        $path = '/' unless defined $path;
        $path =~ s/\?.*//;
        $path =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
        $path = '/index.html' if $path eq '/';

        my $file = $root . $path;
        $file =~ s|//|/|g;

        if (-f $file) {
            my ($ext) = ($file =~ /\.([^.]+)$/);
            my $type = $mime{lc($ext // '')} // 'application/octet-stream';
            open my $fh, '<:raw', $file or die "open $file: $!";
            my $body = do { local $/; <$fh> };
            close $fh;
            my $len = length $body;
            syswrite $client, "HTTP/1.1 200 OK\r\nContent-Type: $type\r\nContent-Length: $len\r\nConnection: close\r\n\r\n";
            syswrite $client, $body;
        } else {
            my $msg = "Not found: $path";
            syswrite $client, "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: " . length($msg) . "\r\nConnection: close\r\n\r\n$msg";
        }
    };
    close $client;
}
