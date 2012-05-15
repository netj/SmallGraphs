@title = "Graphs"

@body =
  ul ->
    for g in @graphs
      li -> a href: "/g/#{g.id}/", -> g.id

# vim:sw=2:sts=2
