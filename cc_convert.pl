#!/usr/bin/perl -w
# cc_convert.pl ---
# Author: sefo <sefo@sefo-IdeaPad-U330p>
# Created: 15 Apr 2019
# Version: 0.01

use File::Basename;
use Getopt::Long qw(GetOptionsFromString);
use warnings;
use strict;

my $filename = 'compile_commands.json';
open(my $fh, '<:encoding(UTF-8)', $filename)
    or die "Could not open file '$filename' $!";


my %mapping = (
    "ccintarm64:cxintarm64" => \&translate_to_ghs_options,
    "cc:gcc:g++" => \&translate_to_ghs_options,
);

my %compile_args;

sub translate_to_ghs_options {
    my $cc = $_[0];
    my $options = $_[1];
    #unshift @$options, 'clang';
    print "@$options \n\n --> converted to: \n\n";
    #$ret = GetOptionsFromString($string, ...);
}

sub get_translator {
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

my $bear_style = 0;
my $count = 0;

while (my $row = <$fh>) {
    my $ccarg;
    my @file_args;
    chomp $row;
    if ($bear_style == 1) {
        if ( $row =~ /\s*\"arguments\s*\":\s*\[/i) {
            do{
                $ccarg = <$fh>;
                if ($ccarg =~ /\s*\"(.+)\"/ ) {
                    push @file_args, $1;
                }
            } while ($ccarg !~ /\s*\],/i);
            my $compilation_unit = pop @file_args;
            $compile_args{$compilation_unit} = join(" ",@file_args);
            my $ret = get_translator($file_args[0]);
        }
    } else {
        if ( $row =~ /\s*\"command\s*\":\s*\"(.*)\"/i) {
            my @options = split(" ", $1);
            foreach (@options) {
                $_ =~ s/\\\\/\//g;
            }
            my $compiler = shift(@options);
            my $base_name_compiler = fileparse($compiler,".exe","");
            my $translator = get_translator($base_name_compiler);
            if ($translator) {
                $translator->($base_name_compiler, \@options);
            } else {
                print "No Translator found for CC = $base_name_compiler\n";
            }
            #print "$count $base_name_compiler : @options";
            $count++;
            exit;
        }
    }
}
