TestHelpers = require '../helpers'

describe "nested list plugin", ->
  Nod = pi.Nod
  root = Nod.create 'div'
  Nod.body.append root.node

  beforeEach ->
    @test_div = Nod.create 'div'
    @test_div.style position:'relative'
    root.append @test_div 
    @test_div.append """
        <div class="pi" data-component="list" data-plugins="nested_select" data-pid="test" style="position:relative">
          <ul class="list">          
            <li class="pi item pi-list click1" data-group-id="1" data-id="10" data-plugins="selectable"> 
              <span class="click1">Click1</span>
              <ul class="list">
                <li class="item" data-id="1" data-key="one">One<span class="tags">killer,puppy</span></li>
                <li class="item click2" data-id="2" data-key="someone">Two<span class="tags">puppy, coward</span></li>
                <li class="item click20" data-id="3" data-key="anyone">Tre<span class="tags">bully,zombopuppy</span></li>
              </ul>
            </li>
            <li class="pi item pi-list" data-group-id="2" data-id="11" data-plugins="selectable"> 
              <span>Click2</span>
              <ul class="list">
                <li class="item click3" data-id="4">A</li>
                <li class="item click30" data-id="5">B</li>
                <li class="item" data-id="6">C</li>
              </ul>
            </li>
            <li class="pi item pi-list click10" data-group-id="3" data-id="12" data-plugins="selectable"> 
              <span>Click3</span>
              <ul class="list">
                <li class="item" data-id="7">1</li>
                <li class="item click4" data-id="8">2</li>
                <li class="item" data-id="9">3</li>
              </ul>
            </li>
          </ul>
        </div>
      """
    pi.app.view.piecify()
    @list = $('@test')

  afterEach ->
    @test_div.remove()

  describe "selected and selected_item", ->

    it "should select one upper level item", (done)->
      @list.on 'selected', (event) =>
        expect(@list.selected()[0].record.group_id).to.eq 1
        expect(event.data[0].record.group_id).to.eq 1
        done()

      TestHelpers.clickElement $('.click1').node

    it "should select one lower level item", (done)->
      @list.on 'selected', (event) =>
        expect(@list.selected()[0].record.id).to.eq 2
        expect(event.data[0].record.id).to.eq 2
        done()

      TestHelpers.clickElement $('.click2').node

    it "should select all", (done)->
      @list.on 'selected', (event) =>
        expect(@list.selected()).to.have.length 12
        expect(event.data[1].record.id).to.eq 1
        done()

      @list.select_all()

  describe "selection cleared", ->

    it "should not send nested selection cleared", (done)->
      @list.select_item @list.items[0]

      @list.items[1].select_item @list.items[1].items[0]

      @list.on 'selection_cleared', (event) =>
        done("should not send nested event!")

      TestHelpers.clickElement $('.click3').node
      after 200, done

    it "should send nested selection cleared if all cleared", (done)->
      @list.items[1].select_item @list.items[1].items[0]

      @list.on 'selection_cleared', (event) =>
        done()

      TestHelpers.clickElement $('.click3').node
      after 200, done

  describe "selected records", ->

    it "should select records", ->
      @list.select_item @list.items[0]

      @list.items[1].select_item @list.items[1].items[0]
      @list.items[2].select_item @list.items[2].items[2]

      expect(@list.selected_records().map((rec) -> rec.id)).to.eql [10, 4, 9]

    it "should return one selected record", ->
      @list.select_item @list.items[0]
      expect(@list.selected_record().id).to.eq 10

      @list.clear_selection()

      @list.items[1].select_item @list.items[1].items[0]
      expect(@list.selected_record().id).to.eq 4

  describe "selection types", ->

    it "should all as radio", ->
      TestHelpers.clickElement $('.click1').node
      TestHelpers.clickElement $('.click2').node
      TestHelpers.clickElement $('.click10').node
      TestHelpers.clickElement $('.click3').node
      TestHelpers.clickElement $('.click20').node
      TestHelpers.clickElement $('.click30').node
      TestHelpers.clickElement $('.click4').node

      expect(@list.selected_size()).to.eq 4

    it "should select inner as radio and outer as check", ->
      @list.selectable.type 'check'
      TestHelpers.clickElement $('.click1').node
      TestHelpers.clickElement $('.click2').node
      TestHelpers.clickElement $('.click10').node
      TestHelpers.clickElement $('.click3').node
      TestHelpers.clickElement $('.click20').node
      TestHelpers.clickElement $('.click30').node
      TestHelpers.clickElement $('.click4').node

      expect(@list.selected_size()).to.eq 5

    it "should select inner as check and outer as radio", ->
      item.selectable.type('check') for item in @list.items
      TestHelpers.clickElement $('.click1').node
      TestHelpers.clickElement $('.click2').node
      TestHelpers.clickElement $('.click10').node
      TestHelpers.clickElement $('.click3').node
      TestHelpers.clickElement $('.click20').node
      TestHelpers.clickElement $('.click30').node
      TestHelpers.clickElement $('.click4').node

      expect(@list.selected_size()).to.eq 6

    it "should select as check", ->
      @list.selectable.type 'check'
      item.selectable.type('check') for item in @list.items
      TestHelpers.clickElement $('.click1').node
      TestHelpers.clickElement $('.click2').node
      TestHelpers.clickElement $('.click10').node
      TestHelpers.clickElement $('.click3').node
      TestHelpers.clickElement $('.click20').node
      TestHelpers.clickElement $('.click30').node
      TestHelpers.clickElement $('.click4').node

      expect(@list.selected_size()).to.eq 7
