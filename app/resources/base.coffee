'use strict'
EventDispatcher = require('../core/events').EventDispatcher
utils = require('../core/utils')
ResourceEvent = require('./events')

_singular = (str) ->
  str.replace /s$/,''

# Resources used to share and synchronize data between views.
# All resources should have 'id' field in order to access them by id and to cache resources locally. 
class Base extends EventDispatcher
  # initialize resource with name
  @set_resource: (plural, options = {}) ->
    # element by id
    @__all_by_id__ = {}
    # temp elements by temp id
    @__all_by_tid__ = {}
    @__all__ = []
    @resources_name = plural
    @resource_name = options.singular || _singular(plural)
    @set_storage(options.storage, options) if options.storage?

  @register_association: (name) ->
    if @::__associations__?
      @::__associations__ = @::__associations__.slice()
    else
      @::__associations__ = []
    @::__associations__.push name

  # Build resources from array of data and triggers 'load' event unless silent
  @load: (data, silent=false) ->
    if data?
      elements = (@build(el,true) for el in data)
      @trigger(ResourceEvent.Load) unless silent
      elements

  # Can create collection or item from data if resources_name key or resource_name exists 
  # (replace plain objects with resources list or resource respectively)
  # 
  # @example 
  #   class User extends Base
  #     @set_resource 'users'
  #   
  #   # load 'users' from array and 'user' too 
  #   User.from_data({users: [...], user: ...})
  @from_data: (data) ->
    if data[@resource_name]?
      data[@resource_name] = @build data[@resource_name]
    if data[@resources_name]?
      data[@resources_name] = @load(data[@resources_name])
    data

  # Remove all cached resources
  @clear_all: ->
    el.dispose() for el in @__all__
    @__all_by_id__ = {}
    @__all_by_tid__ = {}
    @__all__.length = 0

  # Return resource by id
  @get: (id) ->
    @__all_by_id__[id] || @__all_by_tid__[id]

  # Return first matched element by params
  # 
  # Note: since the order of items is arbitrary
  # you should use this method when only the one item matches params.
  @get_by: (params) ->
    return unless params?
    for el in @__all__ when utils.matchers.object_ext(params)(el)
      return el
    null

  @add: (el) ->
    return if @get(el.id)
    if el.__temp__ is true
      @__all_by_tid__[el.id] = el
    else
      @__all_by_id__[el.id] = el
    @__all__.push el

  # create new resource
  @build: (data = {}, silent = false, add = true) ->
    unless (data.id && (el = @get(data.id)))
      # create element with temp id
      unless data.id
        data.id = "tid_#{utils.uid()}"
        data.__temp__ = true
      
      el = new @(data)
      if add
        @add el  
        # resource should not trigger ResourceEvent.Create event if element is temporary
        @trigger(ResourceEvent.Create, el) unless (silent or el.__temp__) 
      el
    else
      el.set(data, silent)

  @created: (el, temp_id) ->
    if @__all_by_tid__[temp_id]
      delete @__all_by_tid__[temp_id]
      @__all_by_id__[el.id] = el

  @clear_temp: (silent = false) ->
    for own _, el of @__all_by_tid__
      @remove el, silent
    @__all_by_tid__ = {}

  @remove_by_id: (id, silent) ->
    el = @get(id)
    if el?
      @remove el
    return false

  @remove: (el, silent, disposed = true) ->
    if @__all_by_id__[el.id]?
      delete @__all_by_id__[el.id]
    else
      delete @__all_by_tid__[el.id]
    
    @__all__.splice @__all__.indexOf(el), 1
    @trigger(ResourceEvent.Destroy, el) unless silent
    el.dispose() if disposed
    return true

  # Add listener to resource
  @listen: (callback, filter) ->
    EventDispatcher.Global.on "#{@resources_name}_update", callback, null, filter 

  @trigger: (event, el, changes) ->
    data = utils.obj.wrap(@resource_name, el) 
    data.type = event
    data.changes = changes
    EventDispatcher.Global.trigger "#{@resources_name}_update", data, false

  @off: (callback) ->
    if callback?
      EventDispatcher.Global.off "#{@resources_name}_update", callback 
    else
      EventDispatcher.Global.off "#{@resources_name}_update" 

  @all: ->
    @__all__.slice()

  @first: ->
    @__all__[0]

  @second: ->
    @__all__[1]

  @last: ->
    @__all__[@__all__.length - 1]

  @count: ->
    @__all__.length

  # use utils.object_ext to retrieve cached items 
  @where: (params) ->
    el for el in @__all__ when utils.matchers.object_ext(params)(el)

  constructor: (data={}) ->
    super
    @_snapshot = data
    @changes = {}
    @_persisted = true if (data.id? and not data.__temp__)
    @initialize data

  initialize: (data) ->
    return if @_initialized
    @set(data,true)
    @_initialized = true

  @register_callback 'initialize'

  created: (temp_id) ->
    @commit()
    @constructor.created(@,temp_id)
    @

  commit: ->
    for key, params in @changes
      @_snapshot[key] = params[1]
    @changes = {}
    @__dirty__ = false
    @_snapshot

  rollback: ->
    for key, param in @changes
      @[key] = @_snapshot[key]
    @changes = {}
    @

  dispose: ->
    return if @disposed
    for own key,_ of @
      delete @[key]
    @disposed = true
    @

  @register_callback 'dispose', as: 'destroy'

  remove: (silent = false) ->
    @constructor.remove @, silent

  # Returns objects containing all
  # attributes that were set on construction
  # or thru 'set' method
  attributes: ->
    return @__attributes__ if @__attributes__ && !@__dirty__
    @__attributes__ = {}
    for key, val of @_snapshot
      unless @changes[key]
        @__attributes__[key] = val
      else
        @__attributes__[key] = @changes[key][1]
    @__attributes__

  # return association by name
  association: (name) ->
    ((ind = @__associations__?.indexOf(name)) > -1) && @__associations__[ind]

  # Update resource and trigger events if anything has been changed
  set: (params, silent = false) ->
    _changed = false
    _was_id = !!@id and !(@__temp__ is true)
    _old_id = @id
    for own key,val of params
      if @[key]!=val and not (typeof @[key] is 'function') and not (@__associations__? and (key in @__associations__))
        _changed = true
        @changes[key] = [@[key], val]
        @[key] = val
    
    if (@id|0) and not _was_id
      delete @__temp__
      @_persisted = true
      @__tid__ = _old_id 
      type = ResourceEvent.Create
      @created(_old_id)
    else
      type = ResourceEvent.Update
    @__dirty__ = true if _changed
    @trigger(type, (if type is ResourceEvent.Create then @ else @changes)) if (_changed && !silent)
    @

  @register_callback 'set', as: 'update'

  trigger: (e, data, bubbles = false) ->
    super
    @constructor.trigger e, @, data

Base.Event = ResourceEvent
module.exports = Base
