# test code for giraph backend's  match decompression & result mapping

fs = require "fs"
{GiraphGraph} = require "./giraphgraph"
g = new GiraphGraph {
        hdfsPath: "graphs/actors"
        codingSchemaPath: "codingSchema.json"
    }, "/Users/netj/Projects/2012/SmallGraphs/graphd/graphs/actors"

sm = JSON.parse fs.readFileSync "../test.sgm"

outputLines = (""+fs.readFileSync "/tmp/smallgiraph.XXXXXX/output").split /\n/
m = JSON.parse outputLines[parseInt (Math.random() * outputLines.length)]

console.log "with state machine", JSON.stringify sm.qgraph, null, 2
console.log "testing", JSON.stringify m
console.log ""

(g.resultGeneratorForMatches sm) m, (r) ->
    console.log JSON.stringify r
