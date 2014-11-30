'use strict'
h = require './helpers'
utils = pi.utils
Nod = pi.Nod
TestUsers = pi.resources.TestUsers
Controller = pi.controllers.Test

describe "Pieces RVC", ->
  root = h.test_cont(pi.Nod.body)

  after ->
    root.remove()

  test_div = list = null

  (window.JST||={})['test/user'] = (data) ->
    nod = Nod.create("<div>#{ data.name }</div>")
    nod.addClass 'item'
    nod.append "<span class='age'>#{ data.age }</span>"
    nod  

  page = pi.app.page

  describe "rvc base restful component", ->
    beforeEach ->
      test_div = Nod.create('div')
      test_div.style position:'relative'
      root.append test_div

    afterEach ->
      list?.remove()
      page.dispose()
      TestUsers.clear_all()
      TestUsers.off()

    it "should bind app resource on init", ->
      pi.app.user = TestUsers.build({name: 'Lee', age: 44})
      test_div.append """
        <div class="pi" pid="test" data-plugins="restful" data-renderer="jst(test/user)" data-rest="app.user">
        </div>
      """
      
      test_div.repiciefy()

      list = test_div.find('.pi') 
      expect(list.restful.resource).to.eq pi.app.user

    it "should bind resource after init", ->
      test_div.append """
        <div class="pi" pid="test" data-plugins="restful" data-renderer="jst(test/user)">
        </div>
      """

      test_div.repiciefy()
      list = test_div.find('.pi') 

      pi.app.user = TestUsers.build({name: 'Lee', age: 44})
      list.restful.bind pi.app.user, true

      expect(list.find('.age').text()).to.eq '44'

      pi.app.user.set age: 45
      expect(list.find('.age').text()).to.eq '45'

    it "should bind remote resource", ->
      test_div.append """
        <div class="pi" pid="test" data-plugins="restful" data-renderer="jst(test/user)" data-rest="TestUsers.find(2)">
        </div>
      """
      test_div.repiciefy()
      list = test_div.find('.pi') 

      expect(list.find('.age').text()).to.eq '12'
      TestUsers.get(2).set age: 13
      expect(list.find('.age').text()).to.eq '13'