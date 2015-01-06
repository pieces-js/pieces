'use strict'
pi = require '../../core'
require '../plugin'
require '../../components/base/base'
utils = pi.utils

# [Plugin]
# Bind resource to component:
#  - on update re-render component
#  - on destroy remove component   
#  
# Requires Renderable and 'rest' option as compilable string (e.g. 'app.some.user' or 'Resource.get(1)')
class pi.Base.Restful extends pi.Plugin
  id: 'restful'
  initialize: (@target) ->
    super
    unless @target.has_renderable
      @target.attach_plugin pi.Base.Renderable

    if(rest = @target.options.rest)?
      
      f = pi.Compiler.str_to_fun(rest)
      promise = f.call(@)
      
      unless promise instanceof Promise
        promise = if promise then utils.resolved_promise(promise) else utils.rejected_promise()

      promise.then(
        (resource) =>
          @bind resource, (@target.children().length is 0)
        () =>
          utils.error "resource not found: #{rest}", @target.options.rest
      )
    @

  bind: (resource, render = false) ->
    if @resource
      @resource.off pi.ResourceEvent.Update, @resource_update()
      @resource.off pi.ResourceEvent.Create, @resource_update()
    @resource = resource
    unless @resource
      @target.render(null)
      return
    @resource.on [pi.ResourceEvent.Update,pi.ResourceEvent.Create], @resource_update()
    @target.render(resource) if render

  resource_update: () ->
    @_resource_update ||= (e) =>
      utils.debug 'Restful component event'
      @on_update e.currentTarget

  on_update: (data) ->
    @target.render data

  dispose: ->
    @bind null