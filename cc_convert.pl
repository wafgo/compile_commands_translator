#!/usr/bin/perl -w
# cc_convert.pl ---
# Author: sefo <sefo@sefo-IdeaPad-U330p>
# Created: 15 Apr 2019
# Version: 0.01

use warnings;
use strict;

my $filename = 'compile_commands.json';
open(my $fh, '<:encoding(UTF-8)', $filename)
    or die "Could not open file '$filename' $!";

my %ghs_mapping = (
    "a" => "b"
);

my %gnu_mapping = (
    "a" => "b",
    "b" => "c"
);

my %mapping = (
    "cxxarm:cxxarm64" => \%ghs_mapping,
    "cc:gcc:g++" => \%gnu_mapping,
);

my %compile_args;

sub get_map_table_from_cc {
    my $cc = $_[0];
    my @cc_names = keys %mapping;

    foreach (@cc_names) {
        my @supported_compilers = split(":", $_);
        foreach (@supported_compilers) {
            if (/\s*$cc\s*/) {
                return $mapping{join(":",@supported_compilers)};
            }
        }
    }
    return 0;
}


while (my $row = <$fh>) {
    my $ccarg;
    my @file_args;
    chomp $row;
    if ( $row =~ /\s*\"arguments\s*\":\s*\[/i) {
        do{
            $ccarg = <$fh>;
            if ($ccarg =~ /\s*\"(.+)\"/ ) {
                push @file_args, $1;
            }
        } while ($ccarg !~ /\s*\],/i);
        my $compilation_unit = pop @file_args;
        $compile_args{$compilation_unit} = join(" ",@file_args);
        my $ret = get_map_table_from_cc($file_args[0]);
        if ( $ret ) {
            print $ret->{"b"} . "\n";
        }
    }
}
