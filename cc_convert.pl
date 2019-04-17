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
    #print "---> orig ops = @$options\n";
    #print "---> conv ops = @conv_ops\n";
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

#print "[\n";

while (my $row = <$fh>) {
 #   print "{\n";
    my $ccarg;
    my @file_args;
   # chomp $row;
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
            print "\"$fd\": \"$pt\",\n";
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
                print "No Translator found for CC = $base_name_compiler\n";
            }
            print "\"command\" : \"@translated_cmds\",\n";
            #print "--> @translated_cmds \n";
            #print "$count $base_name_compiler : @options";
            #exit;
        } else {
            print "$row";
        }
    }
    #$count++;
    #if ($count > 20) {
#        exit 7;
#    }
}
