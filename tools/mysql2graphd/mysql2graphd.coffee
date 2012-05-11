#!/usr/bin/env coffee
# mysql2graphd.coffee -- a script for extracting graph layout from MySQL databases
# Usage:
#   mysqldump --no-data ... | mysql2graphd.coffee >graphd.json
# Author: Jaeho.Shin@Stanford.EDU
# Rewritten: 2011-12-24
# Created: 2011-12-11

Lazy = require "lazy"

typeMap =
    varchar     : "xsd:string"
    char        : "xsd:string"
    text        : "xsd:string"
    mediumtext  : "xsd:string"
    longtext    : "xsd:string"
    enum        : "xsd:string"
    set         : "xsd:string"
    int         : "xsd:integer"
    tinyint     : "xsd:byte"
    smallint    : "xsd:short"
    mediumint   : "xsd:integer"
    bigint      : "xsd:integer"
    float       : "xsd:float"
    real        : "xsd:double"
    double      : "xsd:double"
    datetime    : "xsd:dateTime"

objects = {}
foreignKeys = {}

tableName = null
idField = null
attrs = null
links = null

input = new Lazy process.stdin
input.lines.forEach (line) ->
        if m = /CREATE TABLE `(.*)` \(/.exec line
            tableName = m[1]
            idField = null
            attrs = {}
            links = {}
        else if m = /PRIMARY KEY \(`([^`]+)`\)/.exec line
            # id
            idField = m[1]
        else if m = /CONSTRAINT.* FOREIGN KEY \(`([^`]+)`\) REFERENCES `([^`]+)` *\(`([^`]+)`\)/.exec line
            # link
            fkey =
                table: tableName
                field: m[1]
                reftable: m[2]
                reffield: m[3]
            (foreignKeys[tableName] ?= []).push fkey
            # we dont think keys are attrs
            delete attrs[fkey.field]
        else if m = /`([^`]+)` (\w+)/.exec line
            # field
            attrs[m[1]] =
                field: m[1]
                type: typeMap[m[2].toLowerCase()]
        else if m = /^\)/.exec line
            # end of a table
            if idField?
                delete attrs[idField]
                objects[tableName] =
                    id:
                        table: tableName
                        field: idField
                    attrs: attrs
                    links: links
                label_candidate_fields = (k for k,v of attrs when /name|label/.test k)
                # TODO rank label_candidate_fields
                objects[tableName].label = label_candidate_fields[0] if label_candidate_fields.length > 0
            idField = null

input.join ->
    # find multiple foreign keys from a table
    for table,fkeys of foreignKeys
        s_obj = objects[table]
        if (a for a of s_obj?.attrs)?.length > 0
            # generate links to each foreign tables, treating this table as a node
            for fkey in fkeys
                t_obj = objects[fkey.reftable]
                if s_obj? and t_obj.id.field == fkey.reffield
                    s_obj.links["to-" + t_obj.id.table] =
                        to: t_obj.id.table
                        field: fkey.field
        # generate links from multiple foreign key relationships, treating this table as an edge
        for i in [0 .. fkeys.length-2]
            for j in [i+1 .. fkeys.length-1]
                s_fkey = fkeys[i]
                t_fkey = fkeys[j]
                linktable = s_fkey.table # == t_fkey.table
                s_obj = objects[s_fkey.reftable]
                t_obj = objects[t_fkey.reftable]
                if   s_obj?.id.table == s_fkey.reftable and
                     s_obj?.id.field == s_fkey.reffield and
                     t_obj?.id.table == t_fkey.reftable and
                     t_obj?.id.field == t_fkey.reffield
                    s_obj.links[linktable] =
                        to: t_fkey.reftable
                        field: t_fkey.field
                        table: linktable
                        joinOn: s_fkey.field

    console.log JSON.stringify { objects: objects }, null, 2

process.stdin.resume()
process.stdin.setEncoding 'utf8'
