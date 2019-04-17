#!/usr/bin/perl -w
# cc_convert.pl ---
# Author: sefo <sefo@sefo-IdeaPad-U330p>
# Created: 15 Apr 2019
# Version: 0.01

use File::Basename;
use Getopt::Long qw(GetOptionsFromString);
use warnings;
use strict;

$|++;

my $ifile = 'compile_commands.json';
my $ofile = 'compile_commands.json.mod';

my $line_count_total = `wc -l < $ifile`;
my $wc_err = $?;

if ($wc_err) {
    print "WARN: Could not find 'wc' command from coreutils to count lines in input file. Install coreutils (e.g. apt install coreutils) to get a useful progress report during parsing\n";
}

chomp($line_count_total);

open(my $ofh, '>', $ofile) or die "Could not open file '$ofile' $!";
open(my $fh, '<:encoding(UTF-8)', $ifile)
    or die "Could not open file '$ifile' $!";


my %mapping = (
    "ccintarm64:cxintarm64" => \&translate_to_ghs_options,
    "cc:gcc:g++" => \&translate_to_ghs_options,
);

my %compile_args;

sub translate_to_ghs_options {
    my $cc = $_[0];
    my $options = $_[1];
    my @cmds_to_split = ("-I","-D");
    foreach my $opt (@$options) {
        foreach my $cmd (@cmds_to_split) {
            if ($opt =~ /$cmd(.*)\s*/) {
                $opt = "$cmd " . "$1";
            }
        }
    }
    my $ostr = join(" ", @$options);
    #fixme: read this from some file
    my @inc_paths = ("/opt/ghs/7.1.6_2018.1.4/include/arm64",
                     "/opt/ghs/7.1.6_2018.1.4/include/integrity",
                     "/opt/ghs/7.1.6_2018.1.4/ansi",
                     "/opt/ghs/7.1.6_2018.1.4/scxx");
    my @defines = ("__EDG__",
                   "__ghs__",
                   "__ARM64__",
                   "__ARM_NEON__",
                   "__LITTLE_ENDIAN__",
                   "__INTEGRITY");
    my @objs;
    my @srcs;

    my $ret = GetOptionsFromString($ostr,"c=s" => \@srcs, "o=s" => \@objs, "I=s" =>  \@inc_paths, "os_dir=s" => \@inc_paths,"D=s" => \@defines);

    foreach my $path (@inc_paths, @objs, @srcs) {
        # make e.g D:\ to /d/ for msys systems
        if ($path =~ /^([a-zA-Z]):(.*)\s*/){
            my $drive = lc $1;
            $path = "/" . "$drive" . "$2";
        }
    }

    my @conv_ops;
    foreach (@inc_paths) {
        $_ = "-I" . $_;
        push @conv_ops, $_;
    }
    foreach (@defines) {
        $_ = "-D" . $_;
        push @conv_ops, $_;
    }
    foreach (@objs) {
        $_ = "-o " . $_;
        push @conv_ops, $_;
    }
    foreach (@srcs) {
        $_ = "-c " . $_;
        push @conv_ops, $_;
    }
    if ($cc =~ "ccintarm64") {
        unshift @conv_ops, 'clang';
    } elsif ($cc =~ "cxintarm64") {
        unshift @conv_ops, 'clang++';
    } else {
        # this can theoretically not happen
        print "Horrible error occured -> not supported compiler\n";
    }
    return @conv_ops;
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
        if ( $row =~ /\s*\"(directory|file)\s*\":\s*\"(.*)\"/i) {
            my $fd = $1;
            my $pt = $2;
            $pt =~ s/\\\\/\//g;
            if ($pt =~ /^([a-zA-Z]):(.*)\s*/){
                my $drive = lc $1;
                $pt = "/" . "$drive" . "$2";
            }
            print $ofh "\"$fd\": \"$pt\",\n";
        } elsif ( $row =~ /\s*\"command\s*\":\s*\"(.*)\"/i) {
            my @options = split(" ", $1);
            foreach (@options) {
                $_ =~ s/\\\\/\//g;
            }
            my $compiler = shift(@options);
            my $base_name_compiler = fileparse($compiler,".exe","");
            my $translator = get_translator($base_name_compiler);
            my @translated_cmds;
            if ($translator) {
                @translated_cmds = $translator->($base_name_compiler, \@options);
            } else {
                print $ofh "No Translator found for CC = $base_name_compiler\n";
            }
            print $ofh "\"command\" : \"@translated_cmds\",\n";
        } else {
            print $ofh "$row";
        }
    }

    if ( $wc_err == 0) {
        my $perc_proc = (($count * 100.00)/$line_count_total);
        printf "Progress: %.1f\% (line $count/$line_count_total) \r", $perc_proc;
    } else {
        printf "Progress: line $count of ??? lines \r";
    }
    $count++;
}
print "\n";
close $fh;
close $ofh;
