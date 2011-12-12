#!/usr/bin/env perl
# generate-graphd-from-mysql-schema -- a script for extracting graph layout from MySQL databases
# Usage:
#   mysqldump --no-data ... | generate-graphd-from-mysql-schema >graphd.json
# Author: Jaeho.Shin@Stanford.EDU
# Created: 2011-12-11

use warnings;
use strict;
use JSON;

our %TypeMap = (
    varchar     => "xsd:string",
    char        => "xsd:string",
    text        => "xsd:string",
    mediumtext  => "xsd:string",
    longtext    => "xsd:string",
    enum        => "xsd:string",
    set         => "xsd:string",
    int         => "xsd:integer",
    tinyint     => "xsd:byte",
    smallint    => "xsd:short",
    mediumint   => "xsd:integer",
    bigint      => "xsd:integer",
    float       => "xsd:float",
    real        => "xsd:double",
    double      => "xsd:double",
    datetime    => "xsd:dateTime",
);
my $objects = {};
my $foreignKeys = {};

my $tableName;
my $idField;
my $attrs;
my $links;
while (defined (my $line = <>)) {
    if ($line =~ /CREATE TABLE `(.*)` \(/) {
        $tableName = $1;
        $idField = undef;
        $attrs = {};
        $links = {};
    } elsif ($line =~ /PRIMARY KEY \(`([^`]+)`\)/) {
        # id
        $idField = $1;
    } elsif ($line =~ /CONSTRAINT.* FOREIGN KEY \(`([^`]+)`\) REFERENCES `([^`]+)` *\(`([^`]+)`\)/) {
        # link
        my $fkey = { table => $tableName, field => $1, reftable => $2, reffield => $3, };
        $foreignKeys->{$tableName} = [] if not exists $foreignKeys->{$tableName};
        push @{$foreignKeys->{$tableName}}, $fkey;
        # we dont think keys are attrs
        delete $attrs->{$fkey->{field}};
    } elsif ($line =~ /`([^`]+)` (\w+)/) {
        # field
        $attrs->{$1} = { field => $1, type => $TypeMap{lc $2}, };
    } elsif ($line =~ /^\)/) {
        # end of a table
        if (defined $idField) {
            delete $attrs->{$idField};
            $objects->{$tableName} = {
                id => { table => $tableName, field => $idField, },
                attrs => $attrs,
                links => $links,
            };
            my @label_candidate_fields = grep /name|label/, keys %$attrs;
            # TODO rank label_candidate_fields
            my $label = shift @label_candidate_fields;
            $objects->{$tableName}->{label} = $label if defined $label;
        }
        $idField = undef;
    }
}

# find multiple foreign keys from a table
for my $table (keys %$foreignKeys) {
    my $fkeys = $foreignKeys->{$table};
    if (@$fkeys == 1) {
        my $fkey = $fkeys->[0];
        my $s_obj = $objects->{$table};
        my $t_obj = $objects->{$fkey->{reftable}};
        if ($t_obj->{id}->{field} eq $fkey->{reffield}) {
            $s_obj->{links}->{"to-".$t_obj->{id}->{table}} = {
                to => $t_obj->{id}->{table},
                field => $fkey->{field},
            };
        }
    } elsif (@$fkeys > 1) {
        for (my $i=0; $i<@$fkeys-1; $i++) {
            for (my $j=$i+1; $j<@$fkeys; $j++) {
                my $s_fkey = $fkeys->[$i];
                my $t_fkey = $fkeys->[$j];
                my $linktable = $s_fkey->{table}; # eq $t_fkey->{table}
                my $s_obj = $objects->{$s_fkey->{reftable}};
                my $t_obj = $objects->{$t_fkey->{reftable}};
                if ($s_obj->{id}->{table} eq $s_fkey->{reftable} and 
                    $s_obj->{id}->{field} eq $s_fkey->{reffield} and
                    $t_obj->{id}->{table} eq $t_fkey->{reftable} and 
                    $t_obj->{id}->{field} eq $t_fkey->{reffield}) {
                    $s_obj->{links}->{$linktable} = {
                        to => $t_fkey->{reftable},
                        field => $t_fkey->{field},
                        table => $linktable,
                        joinOn => $s_fkey->{field},
                    };
                }
            }
        }
    }
}

print encode_json { mysql => { layout => { objects => $objects } } };
print "\n";
