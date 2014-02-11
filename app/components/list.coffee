do (context = this) ->
  "use strict"
  # shortcuts
  $ = context.jQuery
  pi = context.pi  = context.pi || {}
  utils = pi.utils

  list_klass = pi.config.list?.list_klass? || 'list'
  item_klass = pi.config.list?.item_klass? || 'item'


  object_matcher = (obj) ->
    for key,val of obj
      if typeof val == "string"
        obj[key] = (value) -> 
          !!value.match new RegExp(val)
      else if val instanceof Object
        obj[key] = object_matcher val
      else
        obj[key] = (value) ->
          val == value

    (item) ->
      for key,matcher of obj
        unless item[key]? and matcher(item[key])
          return false
      return true

  string_matcher = (string) ->
    if string.indexOf(":") > 0
      [path, query] = string.split ":"
      regexp = new RegExp(query)
      (item) ->
        !!item.nod.find(path).text().match(regexp)
    else
      regexp = new RegExp(string)
      (item) ->
        !!item.nod.text().match(regexp)

  # Basic list component

  class pi.List extends pi.Base
    initialize: () ->
      @items_cont = @nod.find(".#{ list_klass }")
      @item_renderer = @options.renderer
      
      unless @item_renderer?
        @item_renderer = (nod) -> 
          item = nod.data()
          item.nod = nod
          item

      @items = []
      @buffer = document.createDocumentFragment()
    
      @parse_html_items()

      @nod.on "click", ".#{ item_klass }", (e) =>  @_item_clicked($(` this `),e)

    parse_html_items: () ->
      @add_item($(nod)) for nod in @items_cont.find(".#{ item_klass }")
      @_flush_buffer false

    # Set list elements
    # @params [Array, Null] data if null then clear list

    data_provider: (data = null) ->
      @clear() if @items.length  

      return unless data? 
      
      @add_item(item,false) for item in data
      @_flush_buffer()
      @trigger 'update'

    add_item: (data, update = true) ->
      item = @_create_item data
      @items.push item

      # save item index in DOM element
      item.nod.data('list-index',@items.length-1)
      
      if update then @items_cont.append(item.nod) else @buffer.appendChild(item.nod.get(0))

      @trigger('update', {type:'item_added',item:item}) if update
      
    add_item_at: (data, index, update = true) ->
      if @items.length-1 < index
          @add_item data,update
          return
            
      item = @_create_item data
      @items.splice(index,0,item)
      
      _after = @items[index+1]
      
      # save item index in DOM element
      item.nod.data('list-index',index)

      item.nod.insertBefore(_after.nod)

      @trigger('update', {type:'item_added', item:item}) if update

    remove_item: (item,update = true) ->
      index = @items.indexOf(item)
      if index > -1
        @items.splice(index,1)
        @_destroy_item(item)
        item.nod.data('list-index','')
        @trigger('update', {type:'item_removed',item:item}) if update
      return  

    remove_item_at: (index,update = true) ->
      if @items.length-1 < index
        return
      
      item = @items[index]
      @remove_item(item,update)


    # Find items within list using query
    #
    # @params [String, Object] query 
    #
    # @example Find items by object mask (would match all objects that have keys and equal ('==') values)
    #   list.find({age: 20, name: 'John'})
    # @example Find by string query = find by nod content
    #   list.find(".title:keyword") // match all items for which item.nod.find('.title').text().search(/keyword/) > -1

    find: (query) ->
      matcher = if typeof query == "string" then string_matcher(query) else object_matcher(query)
      item for item in @items when matcher(item)


    size: () ->
      @items.length

    clear: () ->
      @items_cont.children().detach()
      @items.length = 0
      @trigger 'update', {type:'clear'}


    _create_item: (data) ->
      @item_renderer data

    _destroy_item: (item) ->
      item.nod?.remove?()

    _flush_buffer: (append = true) ->
      @items_cont.append @buffer if append
      @buffer = document.createDocumentFragment()

    _item_clicked: (target,e) ->
      return unless target.data('list-index')?
      item = @items[target.data('list-index')]
      @trigger('item_click', { item: item})


  # [Plugin]
  # Loads data dynamically and append new loaded items to the end of the list
  #

  class pi.Autoload
    constructor: (@list) ->
      return

  # [Plugin]
  # Add ability to 'select' elements within list
  # 
  # Highlights selected elements with 'is-selected' class 

  class pi.Selectable
    constructor: (@list) ->
      @type = @list.options.select || 'radio' 
      
      @list.on 'item_click', (event) =>
        if @type == 'radio' and not event.data.item.selected
          @list.clear_selection()
        @list._toggle_select event.data.item
        return
      @list.selectable = this
      @list.delegate ['clear_selection','selected','select_all','_select','_deselect','_toggle_select'], 'selectable'

      return

    _select: (item) ->
      if not item.selected
        item.selected = true
        item.nod.addClass 'is-selected'

    _deselect: (item) ->
      if item.selected
        item.selected = false
        item.nod.removeClass 'is-selected'
    
    _toggle_select: (item) ->
      if item.selected then @_deselect(item) else @_select(item)

    clear_selection: () ->
      @_deselect(item) for item in @items
    
    select_all: () ->
      @_select(item) for item in @items


    # Return selected items
    # @returns [Array]
  
    selected: () ->
      item for item in @items when item.selected