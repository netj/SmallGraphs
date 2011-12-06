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
    
    aggregate $pages as count;
    aggregate $posts as count;
    aggregate $texts as count;

"""
    """
    subgraph files = {
        let callee = Function;
        walk File(calling) -Defines-> Function -Calls-> $callee;
        walk File(called) -Defines-> $callee;
    };
    
    walk Directory -Contains-> $files.calling;
    walk Directory -Contains-> $files.called;
    
    aggregate $files as count;

"""
    """
    walk user -wrote-> post -contains-> url;
    walk user -friend-of-> user -wrote-> post -contains-> url;
    walk user -fan-of-> fanpage;
    walk user -fan-of-> fanpage;
"""
]

i = 0
for query in queries
    console.log "- #{i} -------------------"
    console.log query
    console.log "------------------------"
    sg = parser.parse query
    #console.log sg
    #console.log ""

    console.log serializer.serialize sg
    console.log "------------------- #{i} -"
    i++
