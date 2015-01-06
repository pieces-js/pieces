'use strict'
pi = require '../../core'
require '../plugin'
require '../../components/base/list'
utils = pi.utils

# [Plugin]
#
# Bind resources to List (handle create, update and destroy events)  
class pi.List.Restful extends pi.Plugin
  id: 'restful'
  initialize: (@list) ->
    super
    @items_by_id = {}
    @listen_load = @list.options.listen_load is true
    @listen_create = if @list.options.listen_create? then @list.options.listen_create else @listen_load
    if (rest = @list.options.rest)? 
      if rest.indexOf(".") > 0
        rest = utils.capitalize(rest)

      resources = pi.Compiler.str_to_fun(rest).call(@) 

    if resources?
      @bind resources, @list.options.load_rest, @scope

    @list.delegate_to @, 'find_by_id'
    @list.on pi.Events.Destroyed, =>
      @bind null
      false
    @

  bind: (resources, load = false) ->
    if @resources
      @resources.off @resource_update()
    @resources = resources
    unless @resources?
       @items_by_id = {}
       @list.clear() unless @list._disposed
       return

    @resources.listen @resource_update()
    
    @load(resources.all()) if load

  find_by_id: (id) ->
    if @listen_load
      return @items_by_id[id] if @items_by_id[id]?
    items = @list.where(record: {id: (id|0)})
    if items.length
      @items_by_id[id] = items[0]

  load: (data) ->
    for item in data
      @items_by_id[item.id] = @list.add_item(item, true) unless @items_by_id[item.id] and @listen_load
    @list.update()

  resource_update: () ->
    @_resource_update ||= (e) =>
      utils.debug 'Restful list event', e.data.type
      @["on_#{e.data.type}"]?.call(@, e.data[@resources.resource_name])

  on_load: ->
    return unless @listen_load
    @load @resources.all()

  on_create: (data) ->
    return unless @listen_create
    unless @find_by_id(data.id)
      @items_by_id[data.id] = @list.add_item data
    # handle temp item created
    else if data.__tid__ and (item = @find_by_id(data.__tid__))
      delete @items_by_id[data.__tid__]
      @items_by_id[data.id] = item
      @list.update_item item, data

  on_destroy: (data) ->
    if (item = @find_by_id(data.id))
      @list.remove_item item
      delete @items_by_id[data.id]
    return

  on_update: (data) ->
    if (item = @find_by_id(data.id))
      @list.update_item item, data

  dispose: ->
    @items_by_id = {}
    @resources.off(@resource_update()) if @resources?