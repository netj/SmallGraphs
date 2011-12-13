parser = require "syntax"
serializer = require "serialize"

queries = [
    """
    walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;
    walk User(user) -Wrote-> $posts;
"""
    """
    let Post = posts;
    walk FanPage(pages) -Has-> $posts -HasText-> Text(texts) -HasURL-> URL;
    walk User(user) -Wrote-> $posts;
"""
    """
    walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;
    walk User(user) -Wrote-> $posts;
    
    aggregate $pages;
    aggregate $posts;
    aggregate $texts;

"""
    """
    subgraph files = {
        let callee = Function;
        walk File(calling) -Defines-> Function -Calls-> $callee;
        walk File(called) -Defines-> $callee;
    };
    
    walk Directory -Contains-> $files.calling;
    walk Directory -Contains-> $files.called;
    
    aggregate $files;

"""
    """
    walk user -wrote-> post -contains-> url;
    walk user -friend-of-> user -wrote-> post -contains-> url;
    walk user -fan-of-> fanpage;
    walk user -fan-of-> fanpage;
"""
    """
    walk user(n1) -foaf:friend-of-> user;
    look $n1 for @foaf:name , @foaf:address;
    aggregate $n1 with  @foaf:age as sum  , @irs:income as sum;
"""
    """
let n3 = fan-page[="id123"];
let n2 = post;
let n1 = text;
walk $n3 -has-post-> $n2 -contains-text-> $n1 -contains-url-> url;
aggregate $n1;
aggregate $n2;
aggregate $n3;
"""
    """
let n0 = post;
let n1 = text;
let n3 = url;
walk $n0 -contains-text-> $n1 -contains-url-> $n3;
aggregate $n0;
aggregate $n1;
look $n3 for @url[="http://example.com"];
look $n1 for @length[>=100][<200];
look $n2 for @created[<"2011-12-13" | >"2012-12-13"];
"""
]

i = 0
for query in queries
    console.log "- #{i} -------------------"
    console.log query
    console.log "------------------------"
    sg = parser.parse query
    console.log JSON.stringify sg
    console.log "------------------------"
    console.log serializer.serialize sg
    console.log "------------------- #{i} -"
    i++
