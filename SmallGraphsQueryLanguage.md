SmallGraphs Query Language
==========================

First attempt
-------------
Directory(sd) -Contains-> s
Directory(td) -Contains-> t

count
(s,t) {
File(s) -Defines-> Function -Calls-> Function(a)
File(t) -Defines-> Function(a)
}

----

count{FanPage} -Has-> count{Post} -HasText-> count{Text} -HasURL-> URL

----


Second attempt
---------------

subgraph files = {
    node callee = Function;
    walk File(calling) -Defines-> Function -Calls-> $callee;
    walk File(called) -Defines-> $callee;
};

walk Directory -Contains-> $files.calling;
walk Directory -Contains-> $files.called;

aggregate $files as count;

----

walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;

aggregate $pages as count;
aggregate $posts as count;
aggregate $texts as count;


