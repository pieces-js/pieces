'use strict'
pi = require '../../core'
require './setup'
require './compiler'
require './klass'
require '../events'
utils = pi.utils
Nod = pi.Nod

Init = pi.ComponentInitializer

_array_rxp = /\[\]$/

_proper = (klass, name, prop) -> Object.defineProperty(klass::, name, prop)

_prop_setter =
  'default': (name, val) ->
    if @__properties__[name] != val
      @__properties__[name] = val
      true
    else
      false

  bool: (name, val) ->
    val = !!val
    if @__properties__[name] != val
      @__properties__[name] = val
      true
    else
      false

_toggle_class = (val, class_desc) ->
  return unless class_desc?
  if class_desc.on is val
    @addClass class_desc.name
  else
    @removeClass class_desc.name

_node_attr = (val, node_attr) ->
  return unless node_attr?
  if val is node_attr.on
    @attr(node_attr.name, node_attr.name)
  else
    @attr(node_attr.name, null)

class pi.Base extends pi.Nod
  @include_plugins: (plugins...) ->
    plugin.included(@) for plugin in plugins

  # Add list of required subcomponents
  # If after initialization some required components
  # are missing an error is thrown
  @requires: (components...) ->
    @before_create ->
      while(components.length)
        cmp = components.pop()
        if @[cmp] is undefined
          throw Error("Missing required component #{cmp}") 

  # Generates active property for instance of a class
  # - adds __properties__ object to store properties values and description;
  # - generate simple getter (with default values support);
  # - generate setter which can toggle class, trigger events, cast values;
  # - [bool only] generate additional function to set/toggle values.
  #
  # Generated property is not configurable and not enumerable.
  # It's writable unless 'readonly' option is set to true.
  #   
  # @example
  #   @active_property 'enabled', 
  #     type: 'bool', 
  #     event: 'enabled', 
  #     class: 
  #       name: 'is-disabled'
  #       on: false
  #     functions: ['enable', 'disable']
  #     toggle: true
  @active_property = (name, options={}) ->
    # ensure that every class has its own props
    @::__prop_desc__ = utils.clone(@::__prop_desc__ || {})

    options.type ||= 'default'

    if options.class? and typeof options['class'] is 'string'
      options.class =
        name: options.class
        on: true

    if options.node_attr? and typeof options.node_attr is 'string'
      options.node_attr =
        name: options.node_attr
        on: true

    @::__prop_desc__[name] = options 

    d = 
      get: ->
        @__properties__[name]

    if !!options.readonly
      d.writable = false
    else
      d.set = (val) ->
        if _prop_setter[options.type].call(@, name, val)
          val = @__properties__[name]
          _toggle_class.call(@, val, options.class)
          _node_attr.call(@, val, options.node_attr)
          @trigger(options.event, val) if options.event?
        val

    # generate function aliases for boolean props
    if options.type is 'bool'
      if options.functions?
        # first name is for setting true values
        @::[options.functions[0]] = -> 
          @[name] = true
          @
        # second name is for setting false value
        @::[options.functions[1]] = -> 
          @[name] = false
          @
      if options.toggle
        toggle_name = if typeof options.toggle is 'string' then options.toggle else "toggle_#{name}"
        @::[toggle_name] = (val = null) ->
          if val is null
            @[name] = !@[name]
          else
            @[name] = val
          @

    _proper(@, name, d)

  constructor: (@node, @host, @options = {}) ->
    super

    # 6-step initialization
    @preinitialize()
    @initialize()
    @init_plugins()
    @init_children()
    @setup_events()
    @postinitialize()

  # Define instance vars here and active properties defaults
  preinitialize: ->
    pi.Nod.store(@, true)
    @__properties__ = {}
    @__components__ = []
    @__plugins__ = []
    @pid = @data('pid') || @attr('pid') || @node.id
    
    for own name, desc of @__prop_desc__
      do(name, desc) =>
        @__properties__[name] = desc.default

  # Setup instance initial state (but not children)
  initialize: ->       
    @disable() if (@options.disabled || @hasClass(pi.klass.DISABLED))
    @hide() if (@options.hidden || @hasClass(pi.klass.HIDDEN))
    @activate() if (@options.active || @hasClass(pi.klass.ACTIVE))
    @_initialized = true
    @trigger pi.Events.Initialized, true, false

  @register_callback 'initialize'

  # Extend instance functionality with plugins
  # (from options)
  init_plugins: ->
    if @options.plugins?
      @attach_plugin @constructor.lookup_module(name) for name in @options.plugins
      delete @options.plugins
    return

  attach_plugin: (plugin) ->
    if plugin?
      utils.debug_verbose "plugin attached #{plugin::id}"
      @__plugins__.push plugin.attached(@)

  # Find all top-level children components (elements with class pi.klass.PI)
  # and initialize them
  # 
  # If a child has pid then it would be stored as this[pid]
  # 
  # @example
  #   div.pi id="example"
  #     div.pi data-pid="a"
  #     ul
  #       li.pi data-pid="b"
  #         div.pi data-pid="c"
  #   
  #   # find example as pi.Base
  #   example = pi.find("#example")
  #   example.a # => pi.Base
  #   example.b # => pi.Base
  #   example.b.c #=> pi.Base
  init_children: ->
    for node in @find_cut(".#{pi.klass.PI}")
      do (node) =>
        child = Init.init node, @
        if child?.pid
          if _array_rxp.test(child.pid)
            arr = (@[child.pid[..-3]]||=[])
            arr.push(child) unless arr.indexOf(child)>-1
          else
            @[child.pid] = child
          @__components__.push child
    return

  # Add event handlers from options
  setup_events: ->
    for event, handlers of @options.events
      for handler in handlers.split(/;\s*/)
        @on event, pi.Compiler.str_to_event_handler(handler, this)
    delete @options.events
    return

  # Finish initialiation and trigger 'created' event.
  postinitialize: ->
    @trigger pi.Events.Created, true, false

  @register_callback 'postinitialize', as: 'create' 

  # re-init children (grandchildren and so on)
  # = init_children() + __components__.all -> piecify()
  piecify: ->
    @__components__.length = 0
    @init_children()
    for c in @__components__
      c.piecify()

  ## event dispatcher ##

  trigger: (event, data, bubbles) ->
    if @enabled or event is pi.Events.Enabled
      super event, data, bubbles

  bubble_event: (event) ->
    @host.trigger(event) if @host?

  ## public interface ##

  @active_property 'visible', 
    type: 'bool', 
    default: true,
    event: pi.Events.Hidden, 
    class: 
       name: pi.klass.HIDDEN
       on: false
    functions: ['show', 'hide']

  @active_property 'enabled', 
    type: 'bool',
    default: true
    event: pi.Events.Enabled, 
    class: 
       name: pi.klass.DISABLED
       on: false
    functions: ['enable', 'disable']

  @active_property 'active', 
    type: 'bool',
    default: true
    event: pi.Events.Active, 
    class: 
       name: pi.klass.ACTIVE
       on: false
    functions: ['activate', 'deactivate']

  dispose: ->
    return if @_disposed
    if @host?
      @host.remove_component @
    plugin.dispose() for plugin in @__plugins__
    @__plugins__.length = 0
    @__components__.length = 0
    @__properties__ = {}
    super
    @trigger pi.Events.Destroyed, true, false

  # Remove all references to child (called when child is disposed)
  remove_component: (child) ->
    return unless child.pid
    if _array_rxp.test(child.pid)
      delete @["#{child.pid[..-3]}"] if @["#{child.pid[..-3]}"]
    else
      delete @[child.pid]
    @__components__.splice(@__components__.indexOf(child),1)

  # Override Nod#remove_children to handle components first
  remove_children: ->
    list = @__components__.slice()
    for child in list
      @remove_component child
      child.remove()
    super

module.exports = pi.Base
