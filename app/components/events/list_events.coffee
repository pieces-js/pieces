'use strict'
pi = require '../../core'

pi.ListEvent = 
  Update: 'update'
  ItemAdded: 'item_added'
  ItemRemoved: 'item_removed'
  ItemUpdated: 'item_updated'
  Clear: 'clear'
  Load: 'load'
  Empty: 'empty'
  ItemClick: 'item_click'
  Filtered: 'filetered'
  Searched: 'searched'
  ScrollEnd: 'scroll_end'
  Sorted: 'sorted'