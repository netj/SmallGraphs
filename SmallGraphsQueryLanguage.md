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


Above will be compiled into SQL looking like this:

----

    walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;
    walk User(user) -Wrote-> $posts;
    
    aggregate $pages as count;
    aggregate $posts as count;
    aggregate $texts as count;

Given how each objects and links, attributes are layed out across the relational database, such as:

    object "FanPage" idendified by "mobject.id";
    attribute "name" of "FanPage" as "mobject.name";
    attribute "url"  of "FanPage" as "mobject.link";

    object "Post"    idendified by "ugc.id";
    link "Has" from "FanPage" to "Post" as "ugc.mobject_id";

    object "Text"    idendified by "ugc_txt.id";
    object "URL"     idendified by "url.id";
    link "HasURL" from "Text" to "URL" as "url_ugc_txt.{ugc_txt_id,url_id}";

    link "HasText" from "Post" to "Text" as "ugc.ugc_txt_id";

    object "User"   idendified by "user.id";
    link "Wrote" from "User" to "Post" as "ugc.from_id";

Above will be compiled into SQL looking like this:

    SELECT * FROM (
        SELECT mobject.id as _FanPage_id_,
               ugc.id as _Post_id_,
               ugc_txt.id as _Text_id_,
               url.id as _URL_id_
        FROM mobject, ugc, ugc_txt, url, url_ugc_txt
        WHERE mobject.id = ugc.mobject_id
          AND ugc.ugc_txt_id = ugc_txt.id
          AND ugc_txt.id = url_ugc_txt.ugc_txt_id
          AND url_ugc_txt.url_id = url.id
    ) AS _w1_
    INNER JOIN (
        SELECT user.id as _User_id_,
               ugc.id as _Post_id_
        FROM user, ugc
        WHERE user.id = ugc.from_id
    ) AS _w2_
    ON _w1_._Post_id_ = _w2_._Post_id_

    LIMIT 10;
    

Once we add aggregations as following:

    walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;
    walk User(user) -Wrote-> $posts
    
    aggregate $pages as count;
    aggregate $posts as count;
    aggregate $texts as count;

The generated SQL will look like:

    ...


