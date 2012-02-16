Compiling SmallGraph Queries into State Machines
================================================

This document describes how a SmallGraph query can be compiled into
node-centric message-passing state machin to find matching subgraph instances.


Structure of SmallGraph Query
------------------------------

A SmallGraph query `q` consists of number of walks `q.walks`.

Each walk `w <- q.walks` is an alternating sequence of `(w.length+1)/2` step
nodes and `(w.length+1)/2 - 1` step edges.


### Types of Step Nodes

We can partition step nodes into following categories:

* Initial Step Node

    A step node whose in-degree is 0.

* Terminal Step Node

    A step node whose out-degree is 0.

* Intermediate Step Node

    A step node whose in-degree and out-degree is both 1.

* Junction Step Node

    A step node whose in-degree or out-degree is greater than 1.


### Step Edges

* Walk Edge

    TODO

### Identifiers

TODO StepId, WalkId


### Constraints

TODO q.constraints(walkid, stepid).accepts(node or edge)




Normalizing the Query
---------------------

### Additional Edges in the Normalized Query

* Walk Edge

    TODO

* Return Edge

    TODO


### Simplifying Walk Edges

For simplicity, we consider series of intermediate nodes and edges that
connect them as a single (simplified) walk edge, so that the query graph
consists only of initial, terminal and junction step nodes.


### Paving a Canonical Walk Way by Adding Return Edges

1. Pick a terminal step node that will output the complete matches.
2. Starting from that terminal step node,

    1. Visit each neighbor step node that starts a walk edge that ends at the
    current step node in a breadth-first manner.
    2. For each walk edge that starts from the current step node, add a
    corresponding return edge from the step at which the walk ends only if it
    has not been visited yet.




Node-centric Message Passing State Machine
--------------------------------------------

### Data Structures Used in the Compiled State Machine

#### Nodes and Edges in Target Graph

Each node `n` of the target graph provides way to iterate through its outgoing edges:

    e <- n.edges_out

Each edge `e` provides a way to access its source and target node:

    n = e.source
    m = e.target


#### Path
TODO just a list of node and edge IDs


#### Match
TODO describe Match data structure


#### Messages Passed between Individual Nodes in the Target Graph

Individual node in the target graph will send messages to neighbor nodes based
on the messages it receives from neighbors or the system.  The message is
always one of the following types:

1. `Start`

    This message is used to let every node try to match itself with the initial
    step nodes.

2. `Walking(WalkId, StepId, Path, Match)`

    This message is used to extend matching paths among intermediate nodes.

3. `Arrived(WalkId, Match)`

    This is used when a complete path for a walk has be found at a
    non-intermediate node.

4. `Returned(WalkId, Match)`

    This is used between non-intermediate nodes, for passing back discovered
    paths that match non-canonical walks which originate from the recipient
    node.



### Vocabularies to Describe Behavior

#### Initial Walks

Initial walks `walks_init` of query `q` is the set of walks whose source is not a target of
any other walk:

    q.walks_init = [ w <- q.walks | [] == [ w2 <- q.walks | w2.target == w.source ] ]


#### Walks and Return Edges of Step Nodes

Given a SmallGraph query `q` and a non-intermediate step node `s` of it,
we use these short hands to denote the set of:

* incoming walks `s.walks_in  = [ w2 <- q.walks | w2.target == s ]`.
* outgoing walks `s.walks_out = [ w2 <- q.walks | w2.source == s ]`.
* incoming return edges `s.returns_in  = [ r <- q.returns | r.target == s ]`.
* outgoing return edges `s.returns_out = [ r <- q.returns | r.source == s ]`.

Observe that after paving the canonical walk way, for any step `s`,

* `s.walks_out.size-1 <= s.returns_in .size <= s.walks_out.size` and
* `s.walks_in .size-1 <= s.returns_out.size <= s.walks_in .size`.



### How the Compiled State Machine is Used in the Algorithm to Find All Matching Subgraphs


Given a SmallGraph query `q`, **input** target graph `g`.

First, **send message** `Start` to every node `n <- g.nodes`.

Then, repeat processing messages for every node until no new messages remains.
Every individual node `n <- g.nodes` will go through each of its incoming
messages and take appropriate actions:

1. When `Start` arrives:

    For each initial walk `w_init <- q.walks_init`,
    
    * If `q.constraints(w_init, 0).accepts(n)`, then

        **send message** `Walking(w_init, 0, [n], {})` **to** itself `n`.


2. When `Walking(w, s, path, match)` arrives:

    * When `s == 2*k-1` for some integer `k`,
        which means a walk has reached current node, so we may continue it if the
        current node matches the corresponding step.
    
        If `q.constraints(w, 2*k).accepts(n)`, then

        * If `2*k+1 == w.length-1`, then this walk is complete, so
    
            **send message** `Arrived(w, match.add(w, path++[n]))` **to** itself `n`.
    
        * Otherwise,
    
            **send message** `Walking(w, 2*k, path++[n], match)` **to** itself `n`.

    * When `s == 2*k` for some integer `k`,
        which means current node matches the step node, so that we can continue
        looking for its matching outgoing edges.

        For each outgoing edge of `n`, `e <- n.edges_out`
        
        * If `q.constraints(w, 2*k+1).accepts(e)`, then

            **send message** `Walking(w, 2*k+1, path++[e], match)` **to** target node of
            it, `e.target`.


3. When `Arrived(w, match)` arrives:

    This message means paths matching up to walk `w` have been found in `match`
    and it ended on this node `n` which turns out to be a non-intermediate step
    node.  We proceed based on what role is assigned to this step node, and
    what other matches already arrived on the node.

    Let the corresponding step to this node `s = w.target`.

    First, associate `match` to this node `n`, so that we can find them easily
    later: `n.rememberMatches(match)`.

    Then,
    for each compatible match `match_i <- n.findCompatibleMatches(s.walks_in, match)`,

    * When this is a terminal step (`s.walks_out.size == 0`),

        * When there are no outgoing return edges (`s.returns_out.size == 0`),

            **output** `match_i`.

        * Otherwise (`s.returns_out.size > 0`),

            for each outgoing return edge `r_o <- s.returns_out` and
            its corresponding incoming walk `w_i = r_o.walk`,
                **send message** `Returned(w_i, match_i)` **to** `match_i[w_i][0]`.

    * Otherwise, when this step has some outgoing walks (`s.walks_out.size > 0`),

        * When there are no incoming return edges (`s.returns_in.size == 0`), then

            **send message** `Walking(s.walks_out[0], 0, [n], match_i)` **to** itself `n`
            to initiate walk on the canonical way.

            Observe that this is a step with a single outgoing walk
            (`s.walks_out.size - 1 <= s.returns_in.size`, thus
            `s.walks_out.size == 1`).

        * Otherwise (`s.returns_in.size > 0`),

            for each incoming return edge `r_i <- s.returns_in` and
            its corresponding outgoing walk `w_o = r_i.walk`,
                **send message** `Walking(w_o, 0, [n], match_i)` to itself `n`.

4. When `Returned(w, match)` arrives:

    This means matching paths beyond walk `w` have been found in `match`, and
    they are returned to this node `n` which is a non-intermediate step node.
    We propagate different messages based on what role is assigned to this step
    node, and what other matches arrived and returned at the node.

    Let the corresponding step to this node `s = w.source`.

    Note that any `Returned` message is passed along return edges, so that this step
    definitely has some incoming return edges (`s.returns_in.size > 0`), and thus
    some outgoing walks (`s.walks_out.size > 0`).
    
    First, associate `match` to this node `n`, so that we can find them easily
    later: `n.rememberMatches(match)`.

    Then, for each compatible match `match_ir <- n.findCompatibleMatches(s.walks_in ++ s.returns_in, match)`,

    * When all outgoing walks return (`s.walks_out.size == s.returns_in.size`),

        for each outgoing return edge `r_o <- s.returns_out` and
        its corresponding outgoing walk `w_i = r_o.walk`,
            **send message** `Returned(w_i, match_ir)` **to** `match_ir[w_i][0]`.
    
    * Otherwise (`s.walks_out.size > s.returns_in.size`),
        this step is on the canonical walk way, and there is an outgoing walk
        `w_o` that does not have a return edge.

        **send message** `Walking(w_o, 0, [n], match_ir)` **to** itself `n`
        to continue walk on the canonical way,
        where `w_o <- s.walks_out - [ r.walk | r <- s.returns_in ]`).

        Observe that there can be only a single outgoing walk
        (`s.walks_out.size - 1 <= s.returns_in.size`,
        thus `s.walks_out.size - s.returns_in.size == 1`).



Compilation to State Machines
-----------------------------

From the description above, we can expand/inline all operations that involve
only the elements of the query, i.e. step node (`s`, `w.source`, `w.target`),
walk (`w`, `s.walks_in`, `s.walks_out`, `q.walks`, `q.walks_init`) and return
edge (`s.returns_in`, `s.returns_out`), and their constraints
(`q.constraints(w, s).accept(...)`).

TODO efficient match finding, compatibility check, obtaining source node of
particular walk, and data structure for bag of Matches

