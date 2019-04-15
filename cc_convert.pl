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

my %compile_args;

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
    }
}
