###!
# SmallGraphs
# https://github.com/netj/SmallGraphs
# 
# Copyright (c) 2011-2012, Jaeho Shin.
###
require [
  "order!jquery"
  "smallgraph/main"
  "d3.AMD"
  "order!jquery-ui"
  "order!jquery.svg"
  "order!jquery.svgdom"
  "order!jquery.cookie"
  "order!less"
], ($, smallgraph, d3) ->
  SVGNameSpace = "http://www.w3.org/2000/svg"
  MouseMoveThreshold = 5
  NodeWidth  = 40#px
  NodeHeight = 20#px
  NodeLabelLeft = 0#px
  NodeLabelTop  = 5#px
  NodeConstraintTextHeight = 8#px
  NodeConstraintXSpacing = 5#px
  NodeConstraintYSpacing = 5#px
  NodeRounding = 10#px
  EdgeMarkerSize = 12#px
  EdgeLabelLeft = 0#px
  EdgeLabelTop  = 5#px
  EntryWidth  = 70/2#px
  EntryHeight = 25/2#px

  ResultPageSize = 250#results
  ResultScale    = 0.7#ratio
  ResultPaddingH = 0.2#ratio
  ResultPaddingV = 0.2#ratio
  ResultUpdateTransitionDuration = 1000#ms

  ResultFillColors = [
    "#eb912b"
    "#7099a5"
    "#c71f34"
    "#1d437d"
    "#e8762b"
    "#5b6591"
    "#59879b"
  ]

  # TODO ordinal types

  # quantitative types
  QuantitativeTypes =
    "xsd:decimal": parseInt
    "xsd:integer": parseInt
    "xsd:float":  parseFloat
    "xsd:double": parseFloat
  # TODO more types: ordinal, nominal, temporal, geospatial, ...

  Identity = (x) -> x


  ###
  ## some UI vocabularies
  ###

  smallgraphsShowDialog = (selector, options, msg) ->
    dialog = $(selector).dialog($.extend(
        modal: true
        width:  document.body.offsetWidth  * (1-.618)
        height: document.body.offsetHeight * (1-.618)
      , options))
    dialog.find(".description").html(msg)
    dialog

  smallgraphsShowError = (msg) ->
    smallgraphsShowDialog "#error-dialog",
        title: "Error"
        buttons: [
          text: "OK"
          click: ->
            $(this).dialog("close")
        ]
      , msg


  ###
  ## graph schema/ontology
  ###

  # label for atribute nodes
  LabelForType = {
    "xsd:string"  : "abc"
    "xsd:decimal" : "#"
    "xsd:integer" : "#"
    "xsd:float"   : "#.#"
    "xsd:double"  : "#.###"
    "xsd:boolean" : "y/n"
    "xsd:anyURI"  : "URI"
    "xsd:date"    : "📅"
    "xsd:dateTime": "📅⏰"
    "xsd:time"    : "⏰"
  }

  # known types of nodes
  NodeTypes = []

  # try retreiving graph URL from cookie
  smallgraphsGraphURL = null
  smallgraphsGraphURLHistory = null
  try
    smallgraphsGraphURLHistory = JSON.parse $.cookie("smallgraphsGraphURLHistory")
    smallgraphsGraphURLHistory ?= []
  catch err
    smallgraphsGraphURLHistory = []
  smallgraphsGraphURL = smallgraphsGraphURLHistory[0]

  smallgraphsShowGraphURLPicker = ->
    finishGraphURLInput = ->
      newURL = $("#graph-url-input").val()
      if newURL != smallgraphsGraphURL
        smallgraphsGraphURL = newURL
        smallgraphsLoadSchema()
    # show dialog for choosing target graph
    urlDialog = smallgraphsShowDialog "#graph-url-dialog",
        title: "Choose the Graph to Explore"
        width:  400
        height: 200
        resizable: false
        buttons:
          "Continue Disconnected": ->
            $(this).dialog("close")
            smallgraphsResetSchema()
          "Connect": ->
            $(this).dialog("close")
            finishGraphURLInput()
        close: -> $("#graph-url-input").blur()
    # populate graph url history for autocomplete
    $("#graph-url-input")
      .val(smallgraphsGraphURL ? "http://localhost:53411/")
      .keyup( ->
        switch event.keyCode
          when 14, 13 # enter or return
            $(urlDialog).dialog("close")
            finishGraphURLInput()
      )
      .autocomplete(
        delay: 0
        minLength: 0
        source: smallgraphsGraphURLHistory
      )
  $("#graph-url").click(smallgraphsShowGraphURLPicker)

  # retreive schema, e.g. edge limiting allowed types of source/target nodes and vice versa
  emptySchema = { Namespaces: {}, Objects: {}, TypeLabels: {} }
  smallgraphsGraphSchema = emptySchema
  getLabelAttributeNameOfNode = (node) -> smallgraphsGraphSchema.Objects[node.objectType]?.Label
  smallgraphsOriginalTitle = document.title
  smallgraphsGraphURLOriginalMessage = $("#graph-url").html()
  smallgraphsResetSchema = ->
    sketchpadClearSketch()
    $("#graph-url").html(smallgraphsGraphURLOriginalMessage)
    smallgraphsGraphSchema = emptySchema
    NodeTypes = []
  smallgraphsLoadSchema = ->
    smallgraphsGraphURL = smallgraphsGraphURL.replace(/\/$/g, "")
    console.log "loading graph", smallgraphsGraphURL
    document.title = "#{smallgraphsOriginalTitle} of #{smallgraphsGraphURL}" # TODO use friendlier name/label of graph
    $("#graph-url").text(smallgraphsGraphURL)
    $.getJSON(smallgraphsGraphURL + "/schema", (schema) ->
        # record the URL in history
        smallgraphsGraphURLHistory = removeAll(smallgraphsGraphURLHistory, [smallgraphsGraphURL])
        smallgraphsGraphURLHistory.unshift(smallgraphsGraphURL)
        $.cookie("smallgraphsGraphURLHistory", JSON.stringify(smallgraphsGraphURLHistory))
        # clear sketch
        sketchpadClearSketch()
        # switch schema
        smallgraphsGraphSchema = schema
        # learn nodes types
        NodeTypes = keySet(schema.Objects)
        # learn labels for types
        $.extend LabelForType, schema.TypeLabels
        # augment with an inverted index of links between objects
        for objType,{Links:links} of schema.Objects
          for lnType,targetObjTypes of links
            for targetObjType in targetObjTypes
              ((schema.Objects[targetObjType]?.RevLinks ?= {})[lnType] ?= []).push objType
      )
      .error((err) ->
        console.error "Error while loading graph schema", smallgraphsGraphURL, err
        smallgraphsShowError "Could not load graph schema from: " + smallgraphsGraphURL
        smallgraphsResetSchema()
      )

  # default graph URL from the location where UI is loaded
  if document.baseURI != location.href
    smallgraphsGraphURL = location.href

  if smallgraphsGraphURL?
    smallgraphsLoadSchema()
  else
    smallgraphsShowGraphURLPicker()

  ###
  ###
  nodeId = 0
  createNode = (x, y, w, h, nr) ->
    w  ?= NodeWidth
    h  ?= NodeHeight
    nr ?= NodeRounding
    node = addToSketchpad "g",
        class: "node"
        transform: translate(x, y)
    node.id = "n" + nodeId++
    node.x = x; node.y = y
    node.w = w; node.h = h
    addToSketchpad "rect",
        rx: nr, ry: nr
        x : -w, y : -h
        width: w*2, height: h*2
      , node
    addToSketchpad "text",
        dx: NodeLabelLeft, dy: NodeLabelTop
      , node
    node

  getNode = (e) ->
    if $(e.parentNode).hasClass("node")
      e.parentNode
    else
      null
  getEdge = (e) ->
    if $(e.parentNode).hasClass("edge")
      e.parentNode
    else
      null

  # TODO use underscorejs
  keySet = (obj) ->
    keys = (key for key of obj)
    keys.sort()
    keys

  removeAll = (allElements, elementsToRemove) ->
    if elementsToRemove?.length > 0
      allElements.filter (n) -> elementsToRemove.indexOf(n) == -1
    else
      allElements

  intersection = (a, b) ->
    # TODO obviously there's a better implementation of this
    removeAll(a, removeAll(a, b))

  attributeNodeLabelForType = (xsdType) ->
    label = LabelForType[xsdType]
    if label? then label else xsdType


  ###
  ## transforms, coordinates stuff
  ###

  translate = (x,y) ->
    "translate(#{x},#{y})"

  pathbox = (x1,y1, x2,y2) ->
    """
    M#{x1} #{y1}
    L#{x2} #{y1}
    L#{x2} #{y2}
    L#{x1} #{y2}
    Z
    """

  updateEdgeCoordinates = (e, x2, y2) ->
    r = Math.sqrt(x2*x2 + y2*y2)
    x1 = if r < e.source.w then 0 else e.source.w * x2/r
    y1 = if r < e.source.h then 0 else e.source.h * y2/r
    dx2 = (EdgeMarkerSize + e.target.w) * x2/r
    dy2 = (EdgeMarkerSize + e.target.h) * y2/r
    dratio = 0.2
    curvature = 0.05 * e.degree # adjust curvature based on the outedge index
    dxm =   curvature * y2
    dym = - curvature * x2
    xm = x2 / 2
    ym = y2 / 2
    $("path", e).attr(
      d: "M#{x1} #{y1} Q #{xm+2*dxm} #{ym+2*dym}, #{
        x2 - dx2 + dratio*dy2}, #{y2 - dy2 - dratio*dx2}"
    )
    $("text", e).attr(
      x: xm+dxm, y: ym+dym
    )

  adjustEdgeLayout = (es...) ->
    for e in es
      # adjust transformation based on source.x/y
      $(e).attr(
        transform: translate(e.source.x, e.source.y)
      )
      # then update the edge end point coordinates based on target.x/y
      updateEdgeCoordinates e, e.target.x - e.source.x, e.target.y - e.source.y
    null # to prevent CS from accumulating values


  ###
  ## sketchpad
  ###
  sketchpad = $("#query-sketchpad")[0]
  sketchpadDoc = sketchpad.ownerDocument
  sketchpadPageLeft = 0
  sketchpadPageTop = 0
  sketchpadSelectionBox = $("#query-sketchpad-selectionbox")[0]
  sketchpadPhantomNode = $("#query-sketchpad-phantom-node")[0]
  $("rect", sketchpadPhantomNode).attr(
    x    : -NodeWidth /2,      y: -NodeHeight/2
    width:  NodeWidth   , height:  NodeHeight
  )
  $(sketchpad).bind("selectstart", -> event.preventDefault())
  sketch = $("#query-sketch")[0]

  addToSketchpad = (name, attrs, target) ->
    node = sketchpadDoc.createElementNS(SVGNameSpace, name)
    $(node).attr(attrs)
    if target?
      target.appendChild(node)
    else
      # place nodes before edges, so that edges are rendered on top of them
      if name == "g" and attrs.class == "node"
        sketch.insertBefore node, sketch.firstChild
      else
        sketch.appendChild node
    node

  sketchpadClearSketch = ->
    nodeId = edgeId = 0
    # TODO warn user if there's a sketch being deleted
    $("*", sketch).remove()

  attributeNodesOf = (n) ->
    $(".attribute.node", sketch).filter( -> this.subjectId == n.id)

  queryTypeEntryHandler = null
  queryTypeEntryWasBlurred = null
  borderWithPadding = 3 #px XXX bad hard coding the border width and padding size of input
  $("#query-type-input")
    .css(
      width : "#{(EntryWidth  - borderWithPadding)*2}px"
      height: "#{(EntryHeight - borderWithPadding)*2}px"
    )
    .keyup( ->
      switch event.keyCode
        when 27 # esc
          this.value = ""
          event.preventDefault(); # esc causes bad thing sometime, e.g. exiting full screen mode, etc.
        when 14, 13 # enter or return
          null
        else
          return
      if queryTypeEntryHandler?
        queryTypeEntryHandler this.value
        queryTypeEntryHandler = null
      $("#query-type-entry").removeClass("active")
      this.blur()
    )
    .focus( ->
      if queryTypeEntryWasBlurred
        queryTypeEntryWasBlurred = clearTimeout queryTypeEntryWasBlurred
    )
    .blur( ->
      if queryTypeEntryHandler?
        queryTypeEntryWasBlurred = setTimeout ->
            if queryTypeEntryHandler?
              queryTypeEntryHandler()
              queryTypeEntryHandler = null
            $("#query-type-entry").removeClass("active")
          , 200
    )

  queryTypeEntryShow = (x, y, list, done) ->
    if queryTypeEntryWasBlurred
      queryTypeEntryWasBlurred = clearTimeout queryTypeEntryWasBlurred
    if queryTypeEntryHandler?
      queryTypeEntryHandler()
    queryTypeEntryHandler = done
    $("#query-type-input").autocomplete(
      delay: 0
      minLength: 0
      source: list
    )
    $("#query-type-entry")
      .css(
        left: x
        top:  y
      )
      .addClass("active")
    input = $("#query-type-input")[0]
    if list.length == 1
      input.value = list[0]
    else if list.indexOf(input.value) < 0
      input.value = ""
    setTimeout ->
        input.focus()
        input.select()
      , 1


  ###
  ## sketchpad actions
  ###

  sketchpadAction_AddNode =
    name: "add node"
    click: ->
      if event.target == sketchpad
        # create node
        node = createNode(event.offsetX, event.offsetY)
        # ask user to choose type
        queryTypeEntryShow(
          sketchpad.offsetLeft + event.offsetX - EntryWidth ,
          sketchpad.offsetTop  + event.offsetY - EntryHeight,
          NodeTypes,
          (type) ->
            if type
              node.objectType = type
              $("text", node).text(type)
              if smallgraphsGraphSchema != emptySchema
                # show whether edge is invalid or not
                if NodeTypes.indexOf(type) == -1
                  $(node).addClass("invalid")
                else
                  $(node).removeClass("invalid")
              console.log "added node", type, node
            else
              # cancel node creation
              $(node).remove()
        )
        false

  sketchpadAction_MoveNode =
    name: "move node"
    mousedown: ->
      # TODO move all selected nodes
      n = getNode(event.target)
      if n
        this.node = n
        this.offsetX = event.pageX - sketchpadPageLeft - parseInt n.x
        this.offsetY = event.pageY - sketchpadPageTop  - parseInt n.y
        starting = []
        ending = []
        $(".edge", sketchpad).each((i, e) ->
          if e.source == n
            starting.push e
          else if e.target == n
            ending.push e
        )
        this.edgesStarting = starting
        this.edgesEnding = ending
        this
    mousemove: ->
      x = event.pageX - sketchpadPageLeft - this.offsetX
      y = event.pageY - sketchpadPageTop  - this.offsetY
      this.node.x = x
      this.node.y = y
      $(this.node).attr(
        transform: translate(x, y)
      )
      # move edges together
      this.edgesStarting.forEach (e) ->
        $(e).attr(
          transform: translate(x, y)
        )
        x2 = e.target.x - x
        y2 = e.target.y - y
        updateEdgeCoordinates e, x2, y2
      this.edgesEnding.forEach (e) ->
        x2 = x - e.source.x
        y2 = y - e.source.y
        updateEdgeCoordinates e, x2, y2

  EdgeAttributeMark = "@"
  EdgeReverseMark = "^"
  prefixAttributeMark = (t) -> EdgeAttributeMark + t
  prefixReverseMark = (t) -> return EdgeReverseMark + t
  nullNode = { w: 0, h: 0 }
  emptyObjectSchema = { Links: {}, Attributes: {}, RevLinks: {} }
  edgeId = 0
  sketchpadAction_DrawEdgeFromANode =
    name: "draw edge from a node"
    mousedown: ->
      n = getNode(event.target)
      if n?
        if n.isAttributeNode # preventing edges being created from attribute nodes
          return null
        # create edge
        this.sx = parseInt n.x
        this.sy = parseInt n.y
        e = this.edge = addToSketchpad "g",
            class: "edge"
            transform: translate(this.sx, this.sy)
        e.id = "e" + edgeId++
        e.source = n
        e.target = null
        this.line = $(addToSketchpad "path",
            d: "M0 0"
          , e)
        this.label = $(addToSketchpad "text",
            dx: EdgeLabelLeft, dy: EdgeLabelTop
          , e)
        $(e).addClass("drawing")
        # prepare related schema for this source node
        this.objectSchema = (smallgraphsGraphSchema.Objects ? {})[n.objectType] ? emptyObjectSchema
        this.allowedEdgeTypes = (
            # outgoing edges
            keySet(this.objectSchema.Links)
          ).concat(
            # incoming edges
            keySet(this.objectSchema.RevLinks)
              # prefix with reverse edge marks
              .map(prefixReverseMark)
          ).concat(
            # attribute edges
            (
              attrs = keySet(this.objectSchema.Attributes)
              # exclude label attribute
              attrs = removeAll(attrs, [this.objectSchema.Label]) if this.objectSchema.Label?
              attrs
            )
              # prefix with attribute marks
              .map(prefixAttributeMark)
          )
        this
    mousemove: ->
      # drawing edge
      tx = event.offsetX
      ty = event.offsetY
      n = getNode(event.target)
      if n?
        if n == this.edge.source # disallowing self/reflexive/recursive edges
          n = null
        else if n.isAttributeNode # preventing edges being created to existing attribute nodes
          n = null
      e = this.edge
      x2 = tx - this.sx
      y2 = ty - this.sy
      if n? # pointing on a node
        e.target = n
        e.degree = 1 + $(".edge", sketch).filter( ->
          this != e and this.source == e.source and this.target == e.target).length
        # hide phantom node
        $(sketchpadPhantomNode).removeClass("active")
        $("rect", sketchpadPhantomNode).attr({ width : 0, height: 0 })
        # attract end of edge to the node
        x2 = n.x - this.sx
        y2 = n.y - this.sy
        # check graph schema to find types of allowed edges
        targetObjectSchema = smallgraphsGraphSchema.Objects[n.objectType] ? emptyObjectSchema
        allowedEdgeTypesToTarget = (
          intersection(keySet( this.objectSchema.Links),
                       keySet(targetObjectSchema.RevLinks))
        ).concat(
          intersection(keySet( this.objectSchema.RevLinks),
                       keySet(targetObjectSchema.Links))
            .map(prefixReverseMark)
        )
        this.allowedEdgeTypesToTarget = allowedEdgeTypesToTarget
        if smallgraphsGraphSchema != emptySchema
          # show whether edge is invalid or not
          if allowedEdgeTypesToTarget.length == 0
            $(e).addClass("invalid")
          else
            $(e).removeClass("invalid")
      else # not pointing on a node
        e.target = nullNode
        e.degree = 1
        # calculate some length for displacing the phantom node from cursor
        r = Math.sqrt(x2*x2 + y2*y2)
        dx = x2/r * (NodeWidth /2 + EdgeMarkerSize)
        dy = y2/r * (NodeHeight/2 + EdgeMarkerSize)
        # show phantom node
        $("rect", sketchpadPhantomNode)
          .attr(
            width: NodeWidth, height: NodeHeight
            transform: translate(tx+dx, ty+dy)
          )
        sketchpadPhantomNode.x = tx + x2/r * (NodeWidth /2)
        sketchpadPhantomNode.y = ty + y2/r * (NodeHeight/2)
        $(sketchpadPhantomNode).addClass("active")
        if smallgraphsGraphSchema != emptySchema
          # show whether edge is invalid or not
          if this.allowedEdgeTypes.length == 0
            $(e).addClass("invalid")
          else
            $(e).removeClass("invalid")
      updateEdgeCoordinates e, x2, y2
    mouseup: ->
      e = this.edge
      n = getNode(event.target)
      lx = sketchpad.offsetLeft + this.sx + parseInt(this.label.attr("x")) - EntryWidth
      ly = sketchpad.offsetTop  + this.sy + parseInt(this.label.attr("y")) - EntryHeight
      if n == this.edge.source # disallowing self/reflexive/recursive edges
        # hide phantom node
        $(sketchpadPhantomNode).removeClass("active")
        $("rect", sketchpadPhantomNode).attr({ width : 0, height: 0 })
        # cancel edge
        $(e).remove()
      else if n? and not n.isAttributeNode # finish edge to the target
        e.target = n
        e.degree = 1 + $(".edge", sketch).filter( ->
          this != e and this.source == e.source and this.target == e.target).length
        allowedEdgeTypesToTarget = this.allowedEdgeTypesToTarget
        # ask user to choose type
        queryTypeEntryShow(
          lx, ly,
          allowedEdgeTypesToTarget,
          (type) ->
            if type
              # show whether the edge is valid or not
              if smallgraphsGraphSchema != emptySchema
                if allowedEdgeTypesToTarget.indexOf(type) == -1
                  $(e).addClass("invalid")
                else
                  $(e).removeClass("invalid")
              # reverse the edge if needed
              if type.substring(0, EdgeReverseMark.length) == EdgeReverseMark
                type = type.substring(EdgeReverseMark.length) # get the proper type name
                node = e.target
                e.target = e.source
                e.source = node
                adjustEdgeLayout e
              e.linkType = type
              $("text", e).text(type)
              $(e).removeClass("drawing")
              console.log "added edge", type, e
            else
              # cancel edge creation
              $(e).remove()
        )
      else # add both a node and an edge to it
        objSchema = this.objectSchema
        tx = sketchpadPhantomNode.x
        ty = sketchpadPhantomNode.y
        queryTypeEntryShow(
          lx, ly,
          this.allowedEdgeTypes,
          (type) ->
            # hide phantom node
            $(sketchpadPhantomNode).removeClass("active")
            $("rect", sketchpadPhantomNode).attr({ width : 0, height: 0 })
            if type
              if type.substring(0, EdgeAttributeMark.length) == EdgeAttributeMark
                # add an attribute node
                type = type.substring(EdgeAttributeMark.length) # get the proper type name
                attrNode = createNode(tx, ty,
                  NodeWidth/2, NodeHeight/2,
                  0
                )
                $(attrNode).addClass("attribute")
                if $(e.source).hasClass("aggregate")
                  $(attrNode).addClass("aggregate")
                attrNode.subjectId = e.source.id
                attrNode.attributeName = type
                attrNode.attributeType = objSchema.Attributes[type]
                $("text", attrNode).text(attributeNodeLabelForType(objSchema.Attributes[type]))
                attrNode.isAttributeNode = true
                # finish attribute edge
                e.target = attrNode
                adjustEdgeLayout e
                e.linkType = type
                $(e).addClass("attribute")
                $("text", e).text(type)
                $(e).removeClass("drawing")
                if smallgraphsGraphSchema != emptySchema
                  # show whether the attribute node and edge is valid or not?
                  if attrNode.attributeType?
                    $(attrNode).removeClass("invalid")
                    $(e).removeClass("invalid")
                  else
                    $(attrNode).addClass("invalid")
                    $(e).addClass("invalid")
                console.log "added attribute edge", type, e
              else
                # create a node at the end
                node = createNode(tx, ty)
                allowedNodeTypes = null
                if type.substring(0, EdgeReverseMark.length) == EdgeReverseMark
                  type = type.substring(EdgeReverseMark.length) # get the proper type name
                  # reverse the edge
                  e.target = e.source
                  e.source = node
                  # find out what types of node can come as a source
                  allowedNodeTypes = objSchema.RevLinks[type]
                else
                  # e.source remains the same
                  e.target = node
                  # find out what types of node can come as a target
                  allowedNodeTypes = objSchema.Links[type]
                adjustEdgeLayout e
                e.linkType = type
                $("text", e).text(type)
                $(e).removeClass("drawing")
                # and show whether the edge can be valid or not
                if allowedNodeTypes?.length > 0
                  $(e).removeClass("invalid")
                else
                  if smallgraphsGraphSchema != emptySchema
                    $(e).addClass("invalid")
                  # if edge itself is invalid, any node can come at the end
                  allowedNodeTypes = NodeTypes
                # ask user to choose what type of node should be added
                setTimeout ->
                  queryTypeEntryShow(
                    sketchpad.offsetLeft + tx - EntryWidth ,
                    sketchpad.offsetTop  + ty - EntryHeight,
                    allowedNodeTypes.sort(), (nodeType) ->
                      if nodeType
                        # create node
                        node.objectType = nodeType
                        $("text", node).text(nodeType)
                        if smallgraphsGraphSchema != emptySchema
                          # show whether node and edge are invalid or not
                          if allowedNodeTypes.indexOf(nodeType) == -1
                            # edge is invalid if this type of node is not allowed
                            $(e).addClass("invalid")
                            # but the node can still be a valid one
                            if NodeTypes.indexOf(nodeType) == -1
                              $(node).addClass("invalid")
                            else
                              $(node).removeClass("invalid")
                          else
                            $(node).removeClass("invalid")
                        console.log "added edge", type, e, "with a node", nodeType, node
                      else
                        # cancel node creation
                        $(node).remove()
                        # and also the edge creation
                        $(e).remove()
                  )
                , 100
            else
              # cancel edge creation
              $(e).remove()
        )

  sketchpadCurrentSelection = []
  sketchpadAction_SelectNodeOrEdge =
    name: "select node or edge"
    click: ->
      nodeOrEdge = getNode(event.target) ? getEdge(event.target)
      if nodeOrEdge?
        if isDoingMultipleSelection = (event.metaKey or event.ctrlKey)
          if $(nodeOrEdge).hasClass("selected")
            removeAll(sketchpadCurrentSelection, [nodeOrEdge])
            $(nodeOrEdge).removeClass("selected")
          else
            $(nodeOrEdge).addClass("selected")
            sketchpadCurrentSelection.push nodeOrEdge
        else
          $(sketchpadCurrentSelection).removeClass("selected")
          sketchpadCurrentSelection = []
          $(nodeOrEdge).addClass("selected")
          sketchpadCurrentSelection.push nodeOrEdge
      false

  sketchpadAction_SelectArea =
    name: "select area"
    mousedown: ->
      if event.target == sketchpad
        x1 = this.x1 = event.offsetX
        y1 = this.y1 = event.offsetY
        this.rect = $("rect", sketchpadSelectionBox)
          .attr(
            x: x1, y: y1, width: 0, height: 0
          )
        $(sketchpadSelectionBox).addClass("active")
        # TODO invert selection? or exclude range from current selection?
        # incremental selection
        if isDoingMultipleSelection = (event.metaKey or event.ctrlKey)
          this.initialSelection = sketchpadCurrentSelection
        else
          $(sketchpadCurrentSelection).removeClass("selected")
          sketchpadCurrentSelection = this.initialSelection = []
        this.lastNodesInBox = []
        this
    mousemove: ->
      x1 = this.x1
      y1 = this.y1
      x2 = event.pageX - sketchpadPageLeft
      y2 = event.pageY - sketchpadPageTop
      this.rect.attr(
        x: Math.min(x1, x2), width:  Math.abs(x2 - x1)
        y: Math.min(y1, y2), height: Math.abs(y2 - y1)
      )
      # update selection
      xl = Math.min(x1,x2)
      xu = Math.max(x1,x2)
      yl = Math.min(y1,y2)
      yu = Math.max(y1,y2)
      nodesInBox = $(".node", sketchpad)
        .filter((i) ->
          x = this.x
          y = this.y
          xl <= x and x <= xu and yl <= y and y <= yu
        )
        .addClass("selected")
        .toArray()
      nodesOutOfBoxNow = removeAll(this.lastNodesInBox, nodesInBox.concat(this.initialSelection))
      $(nodesOutOfBoxNow).removeClass("selected")
      #console.debug nodesInBox.length, nodesOutOfBoxNow.length
      this.lastNodesInBox = nodesInBox
      sketchpadCurrentSelection = this.initialSelection.concat(nodesInBox)
    mouseup: ->
      $(sketchpadSelectionBox).removeClass("active")
      this.rect.attr(
        width: 0, height: 0
      )

  sketchpadAction_RemoveSelection =
    name: "remove selection"
    keypress: ->
      alsoRemoveTargetAttributeNodes = ->
        if this.target?.isAttributeNode?
          $(this.target).remove()
      # first, remove edges that will become dangling by removing the selection
      # along with the attribute nodes without its edge
      $(".edge", sketchpad)
        .filter( ->
          sketchpadCurrentSelection.indexOf(this.source) >= 0 or
          sketchpadCurrentSelection.indexOf(this.target) >= 0
        )
        .each(alsoRemoveTargetAttributeNodes)
        .remove()
      # then, remove the selection
      $(sketchpadCurrentSelection)
        .each(alsoRemoveTargetAttributeNodes)
        .remove()
      sketchpadCurrentSelection = []


  constraintInputPrototype = null
  sketchpadSetupConstraint = (nodes) ->
    null
  sketchpadSetupConstraintForSelection = ->
    null

  sketchpadAction_AddConstraint =
    name: "add constraints"
    dblclick: ->
      node = getNode(event.target)
      if node?
        if $(node).hasClass("attribute")
          subjectNode = $("##{node.subjectId}")[0]
          attrName = "@"+node.attributeName
          constraintType = "constraint"
        else # try constraining label
          subjectNode = node
          labelAttr = getLabelAttributeNameOfNode node
          if labelAttr?
            attrName = "@"+labelAttr
            constraintType = "labelConstraint"
          else
            attrName = "ID"
            constraintType = "constraint"
        # TODO maybe do this in a cleaner jQuery-based UI instead of some primitive prompt
        done = false
        constraintString = (smallgraph.serializeConstraint node[constraintType])
          .replace(/^\[(.*)\]$/, "$1")
        until done
          try
            constraintString = prompt """
            Enter the constraint for #{attrName} of #{subjectNode.objectType}(#{subjectNode.id})
             e.g. >123  or  ="small graphs".
            """, constraintString
            if constraintString
              normalizeConstraint = (cStr) ->
                # adjust user input
                cStr = cStr.replace /^\s+|\s+$/g, ""
                if m = cStr.match /^(=|!=|<=|<|>|>=)\s*(.*)$/
                  [_, rel, expr] = m
                else
                  # treat as an equality if none specified
                  rel = "="
                  expr = cStr
                # treat as a string and quote it if neither numeric nor already quoted
                expr = "\"#{expr}\"" unless m = expr.match /^(".*"|[0-9.]+)$/
                "#{rel}#{expr}"
              constraintString = normalizeConstraint constraintString
              node[constraintType] = smallgraph.parseConstraint "[#{constraintString}]"
            else
              delete node[constraintType]
            done = true
          catch err
            unless confirm "#{err}\nTry again?"
              throw err
        constraintText = $("text.constraint", node)
        if node[constraintType]?
          # display constraints
          if constraintText.length == 0
            constraintText = $(addToSketchpad "text",
                dx: node.w + NodeConstraintXSpacing
                dy: node.h + NodeConstraintYSpacing - NodeConstraintTextHeight
              , node)
            constraintText.addClass("constraint")
          constraintText.text(constraintString)
        else
          # or remove
          constraintText.remove()
      # TODO edge constraint

  $("#query-constraint")
    .button()
    .click(sketchpadSetupConstraintForSelection)

  aggregationSelectionPrototype = {}
  $("#aggregation-list li")
    .each( ->
      aggregationSelectionPrototype[$(this).attr("for")] = this
    )
    .remove()

  sketchpadSetupAggregation = (attrNodes) ->
    if attrNodes.length == 0
      aggregationSetupInProgress = false
      return
    aggregationSetupInProgress = true
    agglst = $("#aggregation-list")
    # prepare the form
    $("li", agglst).remove()
    idx = 0
    attrNodes.forEach (attrNode) ->
      dataType =
        if QuantitativeTypes[attrNode.attributeType]? then "Quantitative"
        else "Ordinal" # TODO Nominal types?
      listitem = $(aggregationSelectionPrototype[dataType]).clone()
      listitem[0].attributeNode = attrNode
      newId = $("label", listitem).attr("for").replace(/\d+$/, idx++)
      $("label", listitem)
        .attr(
          for: newId
        )
        .text(
          "#{$("#"+attrNode.subjectId + " text", sketch).text()} #{
            prefixAttributeMark(attrNode.attributeName)}"
        )
      $("select", listitem)
        .attr("id", newId)
        .val(attrNode.aggregateFunction)
      attrNode.aggregateFunction = $("select", listitem).val()
      agglst.append(listitem)
    finishAggregationForm = ->
      $("li", agglst)
        .each( ->
          this.attributeNode.aggregateFunction = $("select", this).val()
        )
    smallgraphsShowDialog "#aggregation-dialog",
        title: "Choose How to Aggregate Attributes"
        width: document.body.offsetWidth * .618
        buttons: [
          text: "Save"
          click: ->
            finishAggregationForm()
            $(this).dialog("close")
            aggregationSetupInProgress = false
        ]
        close: ->
          aggregationSetupInProgress = false
  sketchpadSetupAggregationForSelection = ->
    aggAttrNodes = []
    sketchpadCurrentSelection.forEach (n) ->
      if $(n).hasClass("aggregate") and $(n).hasClass("node")
        if $(n).hasClass("attribute")
          aggAttrNodes.push(n)
        else
          aggAttrNodes = aggAttrNodes.concat(attributeNodesOf(n).toArray())
    sketchpadSetupAggregation aggAttrNodes

  aggregationSetupInProgress = false
  sketchpadToggleAggregation = ->
    return if aggregationSetupInProgress
    # toggle aggregation
    sketchpadCurrentSelection.forEach (n) ->
      if $(n).hasClass("node") and not $(n).hasClass("attribute")
        $(n).toggleClass("aggregate")
        attributeNodesOf(n).toggleClass("aggregate")
    # choose how attributes are being aggregated
    sketchpadSetupAggregationForSelection()

  $("#query-aggregate")
    .button()
    .click(sketchpadToggleAggregation)

  sketchpadAction_ToggleAggregation =
    name: "toggle aggregation"
    keypress: sketchpadToggleAggregation

  sketchpadAction_SetupAggregation =
    name: "setup aggregation"
    dblclick: ->
      node = getNode(event.target)
      if node?
        if $(node).hasClass("aggregate")
          if $(node).hasClass("attribute")
            sketchpadSetupAggregation [node]
          else
            sketchpadSetupAggregation attributeNodesOf(node).toArray()


  sketchpadCurrentOrdering = []
  orderingSelectionPrototype = $("#ordering-list li")[0]
  $("#ordering-list li").remove()
  sketchpadSetupOrdering = (orderbyNodes) ->
    if orderbyNodes.length == 0
      orderbyNodes = $(".orderby-desc.node, .orderby-asc.node", sketch).toArray()
    return if orderbyNodes.length == 0
    orderlst = $("#ordering-list")
    # prepare the form
    $("li", orderlst).remove()
    idx = 0
    orderbyNodes.forEach (node) ->
      listitem = $(orderingSelectionPrototype).clone()
      $("a", listitem)
        .click( -> listitem.remove())
      listitem[0].node = node
      newId = $("label", listitem).attr("for").replace(/\d+$/, idx++)
      $("label", listitem)
        .attr(
          for: newId
        )
        .text(
          if $(node).hasClass("attribute")
            "#{$("#"+node.subjectId + " text", sketch).text()} #{
              prefixAttributeMark(node.attributeName)}"
          else
            $("text", node).text()
        )
      $("select", listitem)
        .attr("id", newId)
        .val(node.ordering)
      node.ordering = $("select", listitem).val()
      orderlst.append(listitem)
    # make it reorderable
    orderlst.sortable()
    orderlst.disableSelection()
    clearOrdering = ->
      $(".orderby-desc.node, .orderby-asc.node", sketch)
        .removeClass("orderby-desc")
        .removeClass("orderby-asc")
      sketchpadCurrentOrdering = []
    finishOrderingForm = ->
      clearOrdering()
      $("li", orderlst).each( ->
        this.node.ordering = $("select", this).val()
        $(this.node).addClass("orderby-"+this.node.ordering)
        sketchpadCurrentOrdering.push this.node
      )
    smallgraphsShowDialog "#ordering-dialog",
        title: "Choose How to Order the Results"
        width: document.body.offsetWidth * .618
        buttons: [
          text: "Reset"
          click: ->
            clearOrdering()
            $(this).dialog("close")
        ,
          text: "Save"
          click: ->
            finishOrderingForm()
            $(this).dialog("close")
        ]
  sketchpadSetupOrderingForSelection = ->
    orderbyNodes = sketchpadCurrentOrdering.concat(
      removeAll(
        sketchpadCurrentSelection.filter((n) -> $(n).hasClass("node")),
            sketchpadCurrentOrdering
      )
    )
    sketchpadSetupOrdering(orderbyNodes)


  $("#query-order")
    .button()
    .click(sketchpadSetupOrderingForSelection)

  sketchpadAction_SwitchMode =
    name: "cycle mode"
    keypress: ->
      currentMode = $("#query-mode :checked")[0]
      modes = $("#query-mode input")
      modes.each((i,b) ->
        if b == currentMode
          $(modes[(i+1) % modes.length]).click()
      )


  ###
  ## sketchpad modes of mapping actions
  ###
  sketchpadMode = {}
  sketchpadModeButton = $("#query-mode")
    .buttonset()

  sketchpadMouseActions = []
  sketchpadKeyActions = []
  SketchpadActionHandler = (handlerPrototype) ->
    # FIXME there must be a better way than copying contents of handler
    for i of handlerPrototype
      this[i] = handlerPrototype[i]
    this

  sketchpadPervasiveMode = [
    { handler: sketchpadAction_SelectNodeOrEdge }
    { handler: sketchpadAction_SelectNodeOrEdge , modifierKeys: ["meta"] }
    { handler: sketchpadAction_SelectNodeOrEdge , modifierKeys: ["ctrl"] }
    { handler: sketchpadAction_SelectArea       }
    { handler: sketchpadAction_RemoveSelection  , forKeys: [ DOM_VK_BACK_SPACE = 8, DOM_VK_DELETE = 46 ] }
    { handler: sketchpadAction_SwitchMode       , forKeys: [ DOM_VK_M = 77 ] } # DOM_VK_ALT = 18,
    { handler: sketchpadAction_ToggleAggregation, forKeys: [ DOM_VK_A = 65 ] }
    { handler: sketchpadAction_SetupAggregation }
    { handler: sketchpadAction_AddConstraint    }
  ]

  # TODO distinguish actions into two groups:
  #  1. single body actions (click,dblclick,keypress) vs.
  #  2. stateful ones (mousedown->move->up, keydown->up)
  # TODO make it easier to map single actions to click or dblclick from here
  sketchpadMode.sketch = sketchpadPervasiveMode.concat([
    { handler: sketchpadAction_AddNode          ,                       }
    { handler: sketchpadAction_DrawEdgeFromANode,                       }
    { handler: sketchpadAction_MoveNode         , modifierKeys: ["alt"] }
  ])

  sketchpadMode.layout = sketchpadPervasiveMode.concat([
    { handler: sketchpadAction_AddNode          , modifierKeys: ["alt"] }
    { handler: sketchpadAction_DrawEdgeFromANode, modifierKeys: ["alt"] }
    { handler: sketchpadAction_MoveNode         ,                       }
  ])

  sketchpadCurrentMode = null
  sketchpadSwitchToMode = (modeName) ->
    console.log "switching mode to", modeName
    mode = sketchpadMode[modeName]
    mouseActionHandlers = []
    keyActionHandlers = []
    mode.forEach (mapping) ->
      h = new SketchpadActionHandler mapping.handler
      h.modifierKeys = mapping.modifierKeys
      if h.mousedown or h.click or h.dblclick
        mouseActionHandlers.push h
      else if h.keydown or h.keypress
        h.forKeys = mapping.forKeys
        keyActionHandlers.push h
    sketchpadCurrentMode = mode
    sketchpadMouseActions = mouseActionHandlers
    sketchpadKeyActions = keyActionHandlers
  sketchpadSwitchToMode $("#query-mode input[checked]").val()
  sketchpadModeButton
    .change( -> sketchpadSwitchToMode event.target.value)

  ###
  ## sketchpad action dispatcher
  ###
  # See for keycodes: https://developer.mozilla.org/en/DOM/KeyboardEvent#Virtual_key_codes
  sketchpadCurrentMouseActions = []
  sketchpadFirstMouseEvent = null
  SketchpadAction = (handler) ->
    # FIXME there must be a better way than copying contents of handler
    for i of handler
      this[i] = handler[i]
    this
  ModifierKeys = ["shift", "alt", "ctrl", "meta"]
  sketchpadActionDefSatisfyModifierKey = (handler) ->
    if handler.modifierKeys?
      keyIsOn = (modifier) -> event[modifier+"Key"]
      if not (handler.modifierKeys.every(keyIsOn) and
            not removeAll(ModifierKeys, handler.modifierKeys).some(keyIsOn))
        return false
    else
      if event.shiftKey or event.altKey or event.ctrlKey or event.metaKey
        return false
    true
  sketchpadMouseDown = ->
    sketchpadFirstMouseEvent = event
    sketchpadMouseActions.forEach (handler) ->
      if handler.mousedown?
        return unless sketchpadActionDefSatisfyModifierKey handler
        try
          a = new SketchpadAction handler
          r = a.mousedown()
          if r?
            console.debug event.type, event, a, a.name
            sketchpadCurrentMouseActions.push a if r
        catch err
          console.error err, err+""
  sketchpadMouseMove = ->
    sketchpadCurrentMouseActions.forEach (a) ->
      try
        if a.mousemove?
          console.debug event.type, event, a, a.name
          a.mousemove()
      catch err
        console.error err, err+""
  sketchpadMouseUp = ->
    return unless sketchpadFirstMouseEvent?
    sketchpadCurrentMouseActions.forEach (a) ->
      try
        if a.mouseup?
          console.debug event.type, event, a, a.name
          a.mouseup()
      catch err
        console.error err, err+""
    sketchpadCurrentMouseActions = []
    # process clicks if were not dragging
    if Math.abs(event.pageX-sketchpadFirstMouseEvent.pageX) < MouseMoveThreshold and
        Math.abs(event.pageY-sketchpadFirstMouseEvent.pageY) < MouseMoveThreshold
      sketchpadMouseActions.forEach (handler) ->
        if handler.click?
          return unless sketchpadActionDefSatisfyModifierKey handler
          try
            a = new SketchpadAction handler
            console.debug "click", event, a, a.name
            a.click()
          catch err
            console.error err, err+""
    sketchpadFirstMouseEvent = null

  sketchpadDblClick = ->
    sketchpadMouseActions.forEach (handler) ->
        if handler.dblclick?
          return unless sketchpadActionDefSatisfyModifierKey handler
          try
            a = new SketchpadAction handler
            console.debug event.type, event, a, a.name
            a.dblclick()
          catch err
            console.error err, err+""

  sketchpadCurrentKeyActions = []
  sketchpadKeyDown = ->
    # skip events occurred on input elements
    return if event.target.tagName.match /input/i
    sketchpadKeyActions.forEach (handler) ->
      if handler.forKeys and handler.forKeys.indexOf(event.keyCode) != -1
        if handler.keydown?
          try
            a = new SketchpadAction handler
            r = a.keydown()
            if r?
              console.debug event.type, event, a, a.name
              sketchpadCurrentKeyActions.push a if r
          catch err
            console.error err, err+""
    # don't let the browser behave strangely by preventing the default
    # except Command-key/Windows-key related key combinations
    unless event.metaKey
      event.preventDefault()
  sketchpadKeyUp = ->
    sketchpadCurrentKeyActions.forEach (a) ->
      try
        if a.keyup?
          console.debug event.type, event, a, a.name
          a.keyup()
      catch err
        console.error err, err+""
    sketchpadCurrentKeyActions = []
    # skip events occurred on input elements
    return if event.target.tagName.match /input/i
    # process keypresses TODO if were not repeating?
    sketchpadKeyActions.forEach (handler) ->
      if handler.keypress? and handler.forKeys? and handler.forKeys.indexOf(event.keyCode) != -1
        try
          a = new SketchpadAction handler
          console.debug "keypress", event, a, a.name
          a.keypress()
        catch err
          console.error err, err+""
    # TODO longkeypress?
  $(sketchpad)
    .bind("mousedown", sketchpadMouseDown)
    .bind("dblclick",  sketchpadDblClick)
  $(window)
    .bind("mousemove", sketchpadMouseMove)
    .bind("mouseup",   sketchpadMouseUp)
    .bind("keydown",   sketchpadKeyDown)
    .bind("keyup",     sketchpadKeyUp)

  ###
  ## query execution & result presentation
  ###
  smallgraphsCurrentOffset = null
  smallgraphsCurrentQuery = null
  smallgraphsCurrentResultMapping = null

  smallgraphsRunQuery = ->
    # XXX I know this is ugly, but it's required to prevent sketching elements from coming in
    if queryTypeEntryHandler?
      queryTypeEntryHandler()
      queryTypeEntryHandler = null
    # derive SmallGraph query from the sketch
    [
      smallgraphsCurrentQuery
      smallgraphsCurrentResultMapping
    ] = smallgraphsCompileSketchToQuery()
    query = smallgraphsCurrentQuery
    # check if we can really run this query
    if query.length == 0
      smallgraphsShowError "Empty query: Please sketch something to begin your search."
      return
    smallgraphsSendQuery(query, 0)

  smallgraphsSendQuery = (query, offset, msg) ->
    queryURL = "#{smallgraphsGraphURL}/query"
    sgq = "<pre>#{smallgraph.serialize query}</pre>"
    msg ?=
      if offset == 0
        "Running at #{queryURL}:<br>#{sgq}"
      else
        "Getting #{ResultPageSize} more results from #{queryURL}:<br>#{sgq}"
    # indicate we're in progress
    ajaxHandle = null
    progress = smallgraphsShowDialog "#progress-dialog",
        title: "Running Query"
        buttons: [
          text: "Cancel"
          click: ->
            if ajaxHandle?
              ajaxHandle.abort()
            else
              $(this).dialog("close")
        ]
      , msg
    offset ?= 0
    if typeof debugResultURL == "string"
      queryURL = debugResultURL
    # send it to server and get response
    console.debug "sending query to #{queryURL}",
      "limiting range to #{offset}-#{offset+ResultPageSize}",
      "\n#{smallgraph.serialize query}", query, "\n#{JSON.stringify query}"
    ajaxHandle = $.ajax(
      type: 'POST'
      url: queryURL
      contentType: "application/json"
      headers:
        "SmallGraphs-Result-Limit": ResultPageSize
        "SmallGraphs-Result-Offset": offset
      data: JSON.stringify query
      processData: false
      dataType: "json"
      timeout: 3600000 #ms
      success: (result) ->
        ajaxHandle = null
        console.debug "got result", "\n#{JSON.stringify result}\n", result
        # to show each subgraph instance as small multiples
        try
          smallgraphsShowResults(result, offset)
        catch err
          console.error err
          smallgraphsShowError "Error occurred while running query at '#{queryURL}':<br><pre>#{err}</pre>"
        # remove progress indicator
        progress.dialog("close")
      error: (jqXHR, textStatus, err) ->
          ajaxHandle = null
          console.error textStatus, err
          # remove progress indicator
          progress.dialog("close")
          return if textStatus == "abort"
          # show error in a dialog
          smallgraphsShowError "Error occurred while running query at '#{queryURL}':<br>" +
            "<pre>#{textStatus}\t#{err}</pre>" +
                  "Your query was:#{sgq}"
    )

  smallgraphsCompileSketchToQuery = ->
    outAttributeRelated = -> not $(this).hasClass("attribute")
    edges = $(".edge", sketch).filter(outAttributeRelated).toArray()
    ## try to use all edges for stretching walks on both ends
    ws = []
    w = edges.splice 0, 1
    while edges.length > 0
      first = w[0]
      last = w[w.length-1]
      edgesUsed = []
      for e in edges
        if e.target == first.source
          # extend left-end
          w.unshift e
          first = e
          edgesUsed.push e
        else if last.target == e.source
          # extend right-end
          w.push e
          last = e
          edgesUsed.push e
      edges = removeAll(edges, edgesUsed)
      if edgesUsed.length == 0
        # this walk is complete, no more edges can extend it
        # save it and let's start a new walk
        ws.push w
        if edges.length > 0
          w = edges.splice 0, 1
        else
          w = null
    if w?.length > 0
      ws.push w
    # count occurences of objects to use references or not
    nodeOccurs = {}
    seenNode = (n) ->
      nodeOccurs[n] ?= 0
      nodeOccurs[n]++
    ws.forEach (w) ->
      seenNode w[0].source.id
      w.forEach (e) ->
        seenNode e.target.id
    # handle unconnected islands
    $(".node", sketch)
      .filter(outAttributeRelated)
      .filter( -> not nodeOccurs[this.id])
      .each( ->
        # insert fake/partial edges to create single step walks
        ws.push [{source: this}]
        nodeOccurs[this.id] = 1
      )
    ## build a mapping from result data back to a diagram
    resultMappings = []
    addResultMapping = (i, j, obj) ->
      labelAttrFromSchema =
        if obj.objectType?
          smallgraphsGraphSchema.Objects?[obj.objectType]?.Label
        else if obj.linkType?
          smallgraphsGraphSchema.Links?[obj.linkType]?.Label
        else
          null
      do (labelAttrFromSchema) ->
        getLabel =
          if labelAttrFromSchema?
            (step) -> step.attrs?[labelAttrFromSchema] ? step.label ? step.id
          else
            (step) -> step.label ? step.id
        resultMappings.push (data, resultSVG) ->
          step = data.walks[i][j]
          return unless step?
          if typeof step == "string"
            step = data.names[step]
          resultObj = $("#"+obj.id, resultSVG)[0]
          $("text", resultObj).text(getLabel step)
          # bind data to the DOM for later use
          # TODO use dataset API http://www.w3.org/TR/html5/elements.html#custom-data-attribute
          resultObj.data = step
          resultObj.value = getLabel step
    i = 0
    ws.forEach (w) ->
      j = 0
      addResultMapping i, j++, w[0].source
      if w[0].target?
        w.forEach (e) ->
          addResultMapping i, j++, e
          addResultMapping i, j++, e.target
      i++
    ## build a SmallGraph query from it
    stepObject = (o, noref) ->
      if not noref and nodeOccurs[o.id] > 1
        objectRef: o.id
      else
        objectType: o.objectType
        constraint: o.constraint
        # TODO concentrate all constraints to here instead of spreading across "look"s
    stepLink = (e) ->
      linkType: e.linkType
      constraint: e.constraint
    # scan nodes being aggregated
    aggregationMap = {}
    $(".aggregate.node", sketch).each((i,n) ->
      return if $(n).hasClass("attribute")
      aggregationMap[n.id] = []
      nodeOccurs[n.id]++
    )
    # scan nodes for ordering
    sketchpadCurrentOrdering.forEach (n) ->
      unless $(n).hasClass("attribute")
        nodeOccurs[n.id]++
    # enumerate attributes we're interested in
    attributes = []
    $(".attribute.edge", sketch).each((i,e) ->
      if aggregationMap[e.source.id]? # either aggregated
        # FIXME: assign aggregateFunction when adding attributes to aggregated nodes
        aggregationMap[e.source.id].push [
          e.linkType
          (e.target.aggregateFunction ? "count").toLowerCase()
          e.target.constraint # FIXME XXX constraint on individual attributes are turned into one on aggregated values
        ]
      else # or individual value
        attributes.push
          look: [e.source.id, [{name:e.linkType, constraint:e.target.constraint}]]
      resultMappings.push (data, resultSVG) ->
          attr = data.names[e.source.id].attrs
          if attr?
            v = attr[e.linkType]
            resultObj = $("#"+e.target.id, resultSVG)[0]
            $("text", resultObj).text(v)
            # bind data to the DOM for later use
            # TODO use dataset API http://www.w3.org/TR/html5/elements.html#custom-data-attribute
            resultObj.data = v
            resultObj.value = v
      nodeOccurs[e.source.id]++
    )
    #  labelConstraint
    $(".node", sketch).each (i,n) ->
      if n.labelConstraint?
        nodeOccurs[n.id]++
        attributes.push
          look: [
            n.id
            [
              name:getLabelAttributeNameOfNode n
              constraint:n.labelConstraint
            ]
          ]
    # codegen aggregations
    aggregations = []
    for nId, attrsToAggregate of aggregationMap
      aggregations.push
        aggregate: [nId, attrsToAggregate]
    # codegen orderbys
    orderings = []
    sketchpadCurrentOrdering.forEach (n) ->
        if $(n).hasClass("attribute")
          orderings.push [n.subjectId, n.attributeName, n.ordering]
        else
          orderings.push [n.id, null, n.ordering]
    # declare objects we will later reference a few times
    namedObjects = []
    for id,occ of nodeOccurs when occ > 1
      namedObjects.push
        let: [id, stepObject($("#"+id)[0], true)]
    # codegen walks
    walks = []
    for w in ws
      walk = []
      walk.push(stepObject(w[0].source))
      if w[0].target?
        for e in w
          walk.push stepLink(e)
          walk.push stepObject(e.target)
      walks.push
        walk: walk
    # complete codegen
    query = namedObjects
      .concat(walks)
      .concat(attributes)
      .concat(aggregations)
      .concat({orderby: orderings})
    resultMapping = (data, resultSVG) ->
      resultMappings.forEach (mapping) ->
        mapping(data, resultSVG)
    [query, resultMapping]


  results = $("#results")
  $("#result-more")
    .text("Get #{ResultPageSize} more...")
    .button()
    .click( ->
      smallgraphsSendQuery(
        smallgraphsCurrentQuery,
            smallgraphsCurrentOffset + ResultPageSize
      )
    )
  smallgraphsCurrentResultPrototype = null
  smallgraphsCurrentResultOverview = null
  smallgraphsShowResults = (data, offset) ->
    if offset == 0
      # remove if we're starting fresh
      $(".result", results).remove()
      if smallgraphsCurrentResultPrototype?
        smallgraphsCurrentResultPrototype.remove()
        smallgraphsCurrentResultPrototype = null
      # dynamically determine the bounding box of sketch and use that as the size for each
      sketchWidth  = sketchpad.offsetWidth
      sketchHeight = sketchpad.offsetHeight
      firstNode = $(".node", sketch)[0]
      minX = maxX = firstNode.x
      minY = maxY = firstNode.y
      $(".node", sketch)
        .each((i,n) ->
          minX = Math.min(minX, n.x); maxX = Math.max(maxX, n.x)
          minY = Math.min(minY, n.y); maxY = Math.max(maxY, n.y)
        )
      sketchWidth  = maxX - minX + 2*NodeWidth
      sketchHeight = maxY - minY + 2*NodeHeight
      translateX = - minX + NodeWidth  + sketchWidth  * ResultPaddingH
      translateY = - minY + NodeHeight + sketchHeight * ResultPaddingV
      resultWidth  = ResultScale * sketchWidth  * (1+2*ResultPaddingH)
      resultHeight = ResultScale * sketchHeight * (1+2*ResultPaddingV)
      # build a prototype for individual result
      resultPrototype = $("<div>")
          .attr(
            class: "result"
          )
          .css(
            width : "#{resultWidth }px"
            height: "#{resultHeight}px"
          )
          .append($(document.createElementNS(SVGNameSpace, "svg"))
            .append($(sketch).parent().find("defs").clone())
            .append($(sketch).clone()
              .removeAttr("id")
              .attr(
                transform: "scale(#{ResultScale}), translate(#{translateX},#{translateY})"
              )
            )
          )
      marker = $("marker", resultPrototype)
      marker.attr(
        id: "result-arrowhead"
        markerWidth:  marker.attr("markerWidth" )/ResultScale
        markerHeight: marker.attr("markerHeight")/ResultScale
      )
      $(".node, .edge", resultPrototype)
        .removeClass("selected attribute invalid orderby-desc orderby-asc")
      $(".edge text, text.constraint", resultPrototype)
        .remove()
      $(".node text", resultPrototype)
        .text("")
      # TODO adjust edge coords, or add an arrow-ending? updateEdgeCoordinates e, x2, y2
      smallgraphsCurrentResultPrototype = resultPrototype
      # from the query, derive a function for summarizing data for visual encodings
      dataOverview = {}
      dataColorIndex = 0
      addDataOverviewFor = (id, name, map) ->
        dataOverview[id] =
          id: id
          attr: name
          map: map
          min: null
          max: null
          sum: null
          count: 0
          fillColor: ResultFillColors[dataColorIndex++]
        dataColorIndex %= ResultFillColors.length
      smallgraphsCurrentQuery.forEach (decl) ->
          if decl.aggregate?
            agg = decl.aggregate
            id = agg[0]
            addDataOverviewFor id, "label", (d) -> d.names[id].label
            agg[1].forEach (attrAgg) ->
              attrName = attrAgg[0]
              aggfn = attrAgg[1]
              $(".attribute.node", sketch)
                .filter( -> this.subjectId == id and this.attributeName == attrName)
                .toArray().forEach (attrNode) ->
                  addDataOverviewFor attrNode.id, attrName, (d) -> d.names[id].attrs[attrName]
          else if decl.look?
            look = decl.look
            id = look[0]
            look[1].forEach (attrName) ->
              $(".attribute.node", sketch)
                .filter( -> this.subjectId == id and this.attributeName == attrName)
                .toArray().forEach (attrNode) ->
                  if QuantitativeTypes[attrNode.attributeType]?
                    addDataOverviewFor attrNode.id, attrName,
                      (d) -> d.names[id].attrs[attrName]
      smallgraphsCurrentResultOverview = dataOverview
    # analyze new data for finding data range for visual encodings
    for id,overview of smallgraphsCurrentResultOverview
      data.forEach (d) ->
        v = overview.map(d)
        if overview.count == 0
          overview.sum = v
          overview.min = v
          overview.max = v
        else
          overview.sum += v
          if v < overview.min then overview.min = v
          if v > overview.max then overview.max = v
        overview.count++
    # now, show each of them with the resultPrototype
    for datum in data
      aResult = smallgraphsCurrentResultPrototype.clone()
      smallgraphsCurrentResultMapping datum, aResult
      aResult.appendTo(results)
    smallgraphsCurrentOffset = offset
    # do more visual encoding
    for id,overview of smallgraphsCurrentResultOverview
      fillColor = overview.fillColor
      elements = $("#"+id, results)
      if elements.hasClass("node")
        rect = $("rect", elements)
        x = rect.attr("x")
        y = rect.attr("y")
        h = rect.attr("height")
        w = rect.attr("width")
        # FIXME sometimes w is strangely big
        wScale = d3.scale.linear()
          .domain([overview.min, overview.max])
          .range([0, w])
        # XXX D3, as of 2.7.0, has a problem setting parentNode to div.result
        # so I had to use multiple group selection, which will have a little overhead :(
        getValue = (n) -> [n.value]
        column = elements.toArray().map(getValue)
        d3sel = d3.select(results[0])
          .selectAll("#"+id).data(column)
          .selectAll(".overlay").data(Identity)
        d3sel
          .enter()
            .append("svg:rect")
            .attr("class", "overlay")
            .style("fill", fillColor)
            .attr("x", x)
            .attr("y", y)
            .attr("rx", NodeRounding)
            .attr("ry", NodeRounding)
            .attr("height", h)
            .attr("width", 0)
          .transition().duration(ResultUpdateTransitionDuration)
            .attr("width", wScale)
        d3sel
          .transition().duration(ResultUpdateTransitionDuration)
            .attr("width", wScale)
      # TODO also do edges
    # if data was full page, then add a button for fetching more
    if data.length == ResultPageSize
      $("#result-stats").text("Showing first #{offset+data.length} results")
      $("#result-more").addClass("active")
    else
      $("#result-stats").text("Showing all #{offset+data.length} results")
      $("#result-more").removeClass("active")
    # click to open the result accordion only when starting fresh
    if offset == 0
      $("#result-header").click()

  $("#query-run")
    .button()
    .click(smallgraphsRunQuery)

  $("#result-refine")
    .button()
    .click( -> $("#query-header").click())

  $("#result-reorder")
    .button()
    .click( ->
      # FIXME reorder results from here
      $("#result-refine").click()
      setTimeout ->
        $("#query-order").click()
      , 500
    )

  ###
  ## overall UI layout
  ###
  $(sketchpad)
    .css(
      width : "#{window.innerWidth  - 40 }px"
      height: "#{window.innerHeight - 140}px"
    )
  $("#frame")
    .accordion(
      animated: true
      #fillSpace: true
      event: "click"
      changestart: (event, ui) ->
        $("#"+ ui.oldContent.attr("id") + "-tools").removeClass("active")
        $("#"+ ui.newContent.attr("id") + "-tools").   addClass("active")
    )
  $("#query-tools").addClass("active")
  sketchpadPageLeft = sketchpad.offsetLeft + sketchpad.offsetParent.offsetLeft
  sketchpadPageTop  = sketchpad.offsetTop  + sketchpad.offsetParent.offsetTop


  $("#loading-screen").remove()

# vim:et:sw=2:sts=2:ts=8
