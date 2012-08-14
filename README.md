SmallGraphs & GraphD
====================

*SmallGraph* is a simple graph query language for [property graph model][],
i.e. labeled multi-graph each of whose vertex/edge has associated key-value
pairs.  *SmallGraphs* and *GraphD* are the key components of the toolchain that
implements the effective usage of this query language.


Quick Start
-----------

### 1. Download and Install

First, [download
SmallGraphs/GraphD](https://github.com/downloads/netj/SmallGraphs/graphd-latest.sh)
and place it where you can easily access it.  Assuming `~/bin` is already in
your PATH environment:

    curl -RLO https://github.com/downloads/netj/SmallGraphs/graphd-latest.sh

    mv graphd-latest.sh ~/bin/graphd
    chmod +x ~/bin/graphd

Please note that [node.js][node.js download] is essential to running
SmallGraphs/GraphD.  Make sure it is installed to your system.

Now, you need to decide where you want to keep all your GraphD metadata and
some actual data.  The following instructions will assume `graphs/` is the
directory you chose, and already present at that directory.

    mkdir -p graphs
    cd graphs


### 2. Start GraphD

To start the GraphD server at the current working directory, run:

    graphd start

(You can optionally pass a *PortNumber* if you want to use a port other than
the default `53411`.)


### 3. Create Graphs

Before sketching or running any query, you need to tell GraphD where your data
is, and how it is laid out there.  You can use different backends for different
graphs, and instructions will vary depending on which you choose.


#### 3.1 Create MySQL-backed Graph

To use data in you [MySQL][] server and view it as a graph, run:

    graphd create mysql NameOfTheGraph MySQLDatabaseName Username Password

(You can pass optional arguments *Hostname* and *PortNumber* at the end if they
differ from `localhost` and `3306`.)

After running it, you will find an `rdbLayout.json` file generated, which
contains how the vertices and edges are laid out in your relational database.  You
can modify this JSON file to fix the labels, or remove unwanted vertex and edge
types.

Don't forget to add to PATH where MySQL is installed.  For instance:

    PATH="/usr/local/mysql/bin:$PATH"

Otherwise, you may get errors, such as `mysqldump: not available`.


#### 3.2 Create Giraph-backed Graph

[Giraph][] is an open-source implementation of [Pregel][] that runs on a Hadoop
cluster.  Pregel is a distributed graph processing style used by Google, which
allows you to describe graph algorithms by specifying how each vertex should
process and transmit messages.

To use Giraph for processing our queries, run:

    graphd create giraph NameOfTheGraph

Then, move into the graph, and import some RDF NTriples:

    cd NameOfTheGraph
    graphd import GraphDataFile.nt

This step will dictionary encode all the triples, i.e. assign unique number to
each URI and automatically derive a graph schema for you based on what types of
vertices happen to be linked by edges of which types.


### 3. Run Queries with SmallGraphs

You can now open <http://localhost:53411/> from your web browser to sketch and
run graph queries.

<img alt=""
src="https://github.com/netj/SmallGraphs/raw/master/doc/SmallGraphs-screenshot.png">

(WebKit-based browsers, such as [Safari][] or [Chrome][] are recommended.)



### 4. Stop GraphD
When you are done with using SmallGraphs and GraphD, simply run the following
command from where you started it:

    graphd stop


----

The remaining sections will explain build instructions and organization of this
source tree.


How to build
------------

### Prerequisites

SmallGraphs, GraphD, and other tools here are written mostly in
[CoffeeScript][] or [Bash][], and requires [node.js][] for building and
running.  Please install at least the following dependencies to your system
before you proceed.

 * [node.js][node.js download]
 * [Git](http://www.git-scm.com/)
 * [GNU Make](http://www.gnu.org/software/make/)
 * [GNU Bash][Bash], [coreutils](http://www.gnu.org/software/coreutils/),
   [sed](http://www.gnu.org/software/sed/),
   [awk](http://cm.bell-labs.com/cm/cs/awkbook/), grep, find, tar, gzip
 * [JDK 6+](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
 * [Apache Maven 3+](http://maven.apache.org/)

On Mac OS X, you are recommended to use
[Homebrew](http://mxcl.github.com/homebrew/) to install most of the missing
ones.

    brew install node git coreutils maven

On Debian-based systems, you can install most of them by running:

    sudo apt-get install git build-essentials coreutils findutils bash sed gawk tar maven



You may need to run the following git commands, to make sure you have all the
required submodules checked out:

    git submodule init
    git submodule update


### Build

To build, simply run:

    make

Everything built will be staged under `@prefix@/`.  You can add a directory to
your `PATH` environment for convenience.

    PATH="$PWD/@prefix@/bin:$PATH"

    graphd ...


### Install

If you want to install it to your system or in your home, say
`~/smallgraphs/bin`, then run:

    make install PREFIX=~/smallgraphs

    PATH="~/smallgraphs/bin:$PATH"

    graphd ...


Another option is to create a self-extracting executable by running:

    make PACKAGEEXECUTES=bin/graphd

This will generate a flat executable file `graphd-*.sh`.  You can then put this
single file anywhere you want and use it as any other script or executable.



Source Layout
-------------

 * `ui/` contains code related to the frontend user interface that lets
   you sketch queries and browse through results.
 * `graphd/` contains the backend code that compiles queries and drives other
   systems to run them.
 * `shell/` contains the command-line interface code.
 * `smallgraph/` contains the parser and serializer for our SmallGraph DSL.
 * `tools/` contains some useful tools for handling graph data.
 * `doc/` contains some documentation.


References
----------

 * SmallGraphs and GraphD were initialy created by [Jaeho Shin][netj] as a
   final project for the [Data Visualization course at Stanford
   University][cs448b].  You can find [a short paper about
   it][cs448b-finalpaper] with more information from [its wiki
   page][cs448b-finalproject].

 * Most part of the software is written in [CoffeeScript][] and [Bash][] with
   several commonly used Unix tools.
 * The frontend UI, SmallGraphs works with a WebKit-based browser, such as
   [Safari][] or [Chrome][].  It heavily depends on [jQuery][] and [jQuery UI][].
   [jQuery-SVG][] and [jQuery-cookie][] made it possible to keep the
   code short.  [d3.js][] also played an important role in visualizing the
   results.
 * The backend GraphD server is built using [express][] on top of
   [node.js][], and connects to MySQL databases with [node-mysql][].
 * SmallGraph parser is generated with [Jison][].


[netj]: https://cs.stanford.edu/~netj "Jaeho Shin at Stanford"

[GraphD]: https://github.com/netj/SmallGraphs/wiki/GraphD
[SmallGraph]: https://github.com/netj/SmallGraphs/wiki/SmallGraph
[property graph model]: https://github.com/tinkerpop/blueprints/wiki/Property-Graph-Model

[cs448b]: https://graphics.stanford.edu/wikis/cs448b-11-fall
[cs448b-finalproject]: https://graphics.stanford.edu/wikis/cs448b-11-fall/FP-ShinJaeho
[cs448b-finalpaper]: http://db.tt/VtPmNq6I


[CoffeeScript]: http://coffeescript.org/
[Bash]: http://www.gnu.org/software/bash/

[node.js]: http://nodejs.org/
[node.js download]: http://nodejs.org/#download
[npm]: http://npmjs.org/
[Express]: http://expressjs.com/ "High performance, high class web development for Node.js"
[Jison]: http://zaach.github.com/jison/ "a JavaScript parser generator by Zach Carter"

[MySQL]: http://www.mysql.com/
[node-mysql]: https://github.com/felixge/node-mysql "Felix Geisendörfer's node module of MySQL client protocol implementation"

[Giraph]: http://incubator.apache.org/giraph/
[Pregel]: http://portal.acm.org/citation.cfm?id=1807167.1807184
[Pregel blogpost]: http://googleresearch.blogspot.com/2009/06/large-scale-graph-computing-at-google.html


[Safari]: http://www.apple.com/safari/
[Chrome]: http://www.google.com/chrome/

[jQuery]: http://jquery.com/
[jQuery UI]: http://jqueryui.com/
[jQuery-SVG]: http://keith-wood.name/svg.html "Keith Wood's jQuery SVG plugin"
[jQuery-cookie]: https://github.com/carhartl/jquery-cookie "Klaus Hartl's jQuery Cookie plugin"

[d3.js]: http://mbostock.github.com/d3/ "Data-Driven Documents by Mike Bostock and others"
