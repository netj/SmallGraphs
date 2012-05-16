#!/usr/bin/env coffee
fs = require("fs")
process.argv.shift()
for f in process.argv
    fs.writeFileSync f, JSON.stringify (JSON.parse fs.readFileSync f), null, 2
