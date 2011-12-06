smallgraph = require "syntax"

query = """
walk FanPage(pages) -Has-> Post(posts) -HasText-> Text(texts) -HasURL-> URL;
walk User(user) -Wrote-> $posts;
"""

console.log query
console.log smallgraph.parse query
