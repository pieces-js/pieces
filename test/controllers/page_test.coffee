'use strict'
h = require 'pi/test/helpers'

TestUsers = pi.resources.TestUsers
Controller = pi.controllers.Base
View = pi.TestView
utils = pi.utils
Nod = pi.Nod

describe "Page", ->
  root = h.test_cont(pi.Nod.body)

  after ->
    root.remove()

  page = pi.app.page

  test_div = null

  beforeEach ->
    page.options.default = 'test'
    test_div = h.test_cont root, '''
      <div>
        <div class="pi" data-component="test_view" pid="test" style="position:relative">
          <div class="pi pi-progressbar" pid="loader"></div>
          <div class="pi pi-list-container" pid="list">
            <ul class="list">
            </ul>
          </div> 
        </div>
        <div class="pi" data-component="test2_view" pid="test" style="position:relative">
        </div>
        <div class="pi" data-component="base_view" data-controller="test_preload" pid="test" style="position:relative">
        </div>
      </div>
    '''

  afterEach ->
    page.dispose()
    TestUsers.clear_all()

  describe "initialization", ->
    it "should set contexts", (done) ->
      pi.app.initialize().then(
        ->
          expect(page.context).to.be.instanceof Controller
          expect(page._contexts['test']).to.be.instanceof Controller
          done()
      ).catch(done)


  describe "preload", ->
    cont = t = tp = null

    it "should switch to context with preload", (done) ->
      pi.app.initialize().then(
        ->
          t = page._contexts.test
          tp = page._contexts.test_preload
          expect(page.context_id).to.eq 'test'
          page.switch_to('test_preload').then( 
            ->
              expect(tp.preloaded).to.be.true
              done()
          )
      ).catch(done)


  describe "switching", ->
    cont = t = t2 = null

    it "should switch to context", (done) ->
      pi.app.initialize().then(
        ->
          t = page._contexts.test
          t2 = page._contexts.test2
          expect(page.context_id).to.eq 'test'
          page.switch_to('test2').then( 
            ->
              expect(page.context_id).to.eq 'test2'
              expect(page.context).to.eql t2
              expect(page._history.size()).to.eq 2
              done()
          )
      ).catch(done)

    it "should fail if context is unknown", (done) ->
      pi.app.initialize().then(
        ->
          t = page._contexts.test
          t2 = page._contexts.test2
          expect(page.context_id).to.eq 'test'
          page.switch_to('test3').then( 
            (->
              done('Error')
            ),
            ->
              done()
          )
      ).catch(done)

    it "should switch back in history", (done) ->
      pi.app.initialize().then(
        ->
          t = page._contexts.test
          t2 = page._contexts.test2
          expect(page._history.size()).to.eq 1
          page.switch_to('test2')
      ).then( 
        ->
          expect(page._history.size()).to.eq 2
          page.switch_to('test')
      ).then( 
        ->
          expect(page._history.size()).to.eq 3
          page.switch_to 'test2'
      ).then(
        ->
          expect(page._history.size()).to.eq 4
          page.switch_back()
      ).then(
        ->
          expect(page._history.size()).to.eq 4
          page.switch_back()
      ).then( 
        ->
          expect(page._history.size()).to.eq 4
          expect(page.context_id).to.eq 'test2'
          expect(page.context).to.eql t2
          page.switch_to 'test'
      ).then(
        ->
          expect(page._history.size()).to.eq 3
          page.switch_back()
      ).then(
        ->
          page.switch_back()
      ).then(
        ->
          page.switch_to 'test2'
      ).then(
        ->
          expect(page._history.size()).to.eq 2
          done()
      ).catch(done)