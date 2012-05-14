doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    if @title?
        title "#{@title} — GraphD"
    else
        title "GraphD"
    meta(name: 'description', content: @description) if @description?
    link(rel: 'canonical', href: @canonical) if @canonical?

    #link rel: 'icon', href: '/favicon.png'
    #link rel: 'stylesheet', href: '/app.css'

    #script src: 'http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js'
    #script src: '/app.js'

    #coffeescript ->
    #  $(document).ready ->
    #    alert 'hi!'        

    style '''
      header, nav, section, article, aside, footer {display: block}
      nav li {display: inline}
      nav.sub {float: right}
      #content {margin-left: 120px}
    '''
  body ->
    header ->
      #a href: '/', title: 'Home', -> 'Home'

      nav ->
        ul ->
          #li -> a href: '/about', title: 'About', -> 'About'
          #li -> a href: '/pricing', title: 'Pricing', -> 'Pricing'

    div id: 'content', ->
      @body

    footer ->

# vim:sw=2:sts=2
