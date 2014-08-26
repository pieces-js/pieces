'use strict'
pi = require '../../core'
require '../../components/base/list'
require '../plugin'
require './selectable'
utils = pi.utils
# [Plugin]
# Add ability to 'select' elements within list and sublists

_null = ->

class pi.List.NestedSelect extends pi.Plugin
  id: 'nested_select'
  initialize: (@list) ->
    super

    @selectable = @list.selectable || {select_all: _null, clear_selection: _null} 
    @list.delegate_to @, 'clear_selection', 'select_all', 'selected'

    @list.on 'selection_cleared', (e) =>
      if e.target != @list
        e.cancel()
        @_check_selected()
    return

  _check_selected: pi.List.Selectable::_check_selected

  clear_selection: (silent = false) ->
    @selectable.clear_selection()
    for item in @list.items when item instanceof pi.List
      item.clear_selection?()          
    @list.trigger('selection_cleared') unless silent
  
  select_all: () ->
    @selectable.select_all(true)
    for item in @list.items when item instanceof pi.List
      item.select_all?(true)         

    _selected = @selected() 
    @list.trigger('selected', _selected) if _selected.length

  selected: () ->
    _selected = []
    for item in @list.items
      if item.__selected__
        _selected.push item
      if item instanceof pi.List
        _selected = _selected.concat (item.selected?()||[])
    _selected
