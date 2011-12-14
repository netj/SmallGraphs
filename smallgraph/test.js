(function() {
  var i, parser, queries, query, serializer, sg, _i, _len;
  parser = require("syntax");
  serializer = require("serialize");
  queries = ["walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;\nwalk User(user) -Wrote-> $posts;", "let Post = posts;\nwalk FanPage(pages) -Has-> $posts -HasText-> Text(texts) -HasURL-> URL;\nwalk User(user) -Wrote-> $posts;", "walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;\nwalk User(user) -Wrote-> $posts;\n\naggregate $pages;\naggregate $posts;\naggregate $texts;\n", "subgraph files = {\n    let callee = Function;\n    walk File(calling) -Defines-> Function -Calls-> $callee;\n    walk File(called) -Defines-> $callee;\n};\n\nwalk Directory -Contains-> $files.calling;\nwalk Directory -Contains-> $files.called;\n\naggregate $files;\n", "walk user -wrote-> post -contains-> url;\nwalk user -friend-of-> user -wrote-> post -contains-> url;\nwalk user -fan-of-> fanpage;\nwalk user -fan-of-> fanpage;", "walk user(n1) -foaf:friend-of-> user;\nlook $n1 for @foaf:name , @foaf:address;\naggregate $n1 with  @foaf:age as sum  , @irs:income as sum;", "let n3 = fan-page[=\"id123\"];\nlet n2 = post;\nlet n1 = text;\nwalk $n3 -has-post-> $n2 -contains-text-> $n1 -contains-url-> url;\naggregate $n1;\naggregate $n2;\naggregate $n3;", "let n0 = post;\nlet n1 = text;\nlet n3 = url;\nwalk $n0 -contains-text-> $n1 -contains-url-> $n3;\naggregate $n0;\naggregate $n1;\nlook $n3 for @url[=\"http://example.com\"];\nlook $n1 for @length[>=100][<200];\nlook $n2 for @created[<\"2011-12-13\" | >\"2012-12-13\"];"];
  i = 0;
  for (_i = 0, _len = queries.length; _i < _len; _i++) {
    query = queries[_i];
    console.log("- " + i + " -------------------");
    console.log(query);
    console.log("------------------------");
    sg = parser.parse(query);
    console.log(JSON.stringify(sg));
    console.log("------------------------");
    console.log(serializer.serialize(sg));
    console.log("------------------- " + i + " -");
    i++;
  }
}).call(this);
