#!/usr/bin/ruby

# file: dynarex-blog.rb

require 'rexml/document'
require 'polyrex'
require 'dynarex'

class DynarexBlog
  include REXML

  def initialize(file_path='./')
    @file_path = file_path[/\/$/] ? file_path : file_path + '/'
    if File.exists? (@file_path + 'index.xml') then  open() else fresh_start() end
    @current_lookup = 'entry_lookup.xml'
  end

  def create_entry(record={})

    @id += 1
    # create a new record
    @index.create record, @id
    
    # if there is more than 10 records shift the 1st record.
    if @index.records.length > 10 then
      # '+++ deleting the 1st index record +++'
      @index.delete @index.records.to_a[0][-1][:id]
    end
    @index.save @file_path + 'index.xml'

    create_record(record, @id.to_s, name='entry', type='main')
    record[:tags].split(/\s/).each do |tag|
      create_record(record, @id.to_s, name=tag, type='tags')
    end

  end

  def delete(id=0)

    # delete from the tags files (entry and lookup), the entry file and lookup
    # look the id up in lookup.xml

    doc_entry, entry = open_lookup_record 'entry', id
    puts entry.to_s

    dynarex_file = @file_path + entry.text('file').to_s
    dynarex = Document.new(File.open(dynarex_file,'r').read)
    dynarex_entry = XPath.first(dynarex.root, "records/entry[@id='#{id}']")
    tags = dynarex_entry.text('tags').split(/\s/)

    dynarex_entry.parent.delete dynarex_entry
    File.open(dynarex_file,'w'){|f| dynarex.write f}

    entry.parent.delete entry
    lookup = "%s%s" % [@file_path, 'entry_lookup.xml']
    File.open(lookup,'w'){|f| doc_entry.write f}

    tags.each do |tag|
      # find the lookup
      doc_tag, tag_entry = open_lookup_record tag, id      
      delete_entry(doc_tag, tag_entry, tag, id)
    end

    doc = Document.new File.open(@file_path + 'index.xml','r').read
    node = XPath.first(doc.root, "records/entry[@id='#{id}']")

    if node then
      node_records = XPath.first(doc.root, 'records')
      node_records.parent.delete node_records
      records = Element.new 'records'
           
      new_records = select_page('entry_lookup.xml', 1)
      new_records.each {|record| records.add record}
      doc.root.add records

      File.open(@file_path + 'index.xml', 'w'){|f| doc.write f}
      @index = Dynarex.new @file_path + 'index.xml'
    end
    
  end

  def fresh_start()

    @id = 1
    @dynarex = new_blog_file 'entry1.xml'
    @index = new_blog_file 'index.xml'

    @entities = Polyrex.new('entities/section[name]/entity[name,count]')
    @entities.create.section({name: 'main'}, id='main')
    @entities.id('main').create.entity(name: 'entry', count: '1')
    @entities.create.section({name: 'tags'}, id='tags')
    @entities.save @file_path + 'entities.xml'

    @lookup = new_lookup_file 'entry_lookup.xml'
  end

  def open(file_path='./')

    @file_path = file_path
    @index = Dynarex.new @file_path + 'index.xml'
    @id = @index.records ? @index.records.to_a[-1][-1][:id].to_i : 0

    @entities = Polyrex.new @file_path + 'entities.xml'

  end

  def page(number)   
    select_page(@current_lookup, number)
  end

  private

  def delete_entry(doc, node, lookup_filename, id)
    file = @file_path + node.text('file').to_s
    Dynarex.new(file).delete(id).save file

    node.parent.delete node
    lookup = "%s%s" % [@file_path, lookup_filename]
    File.open(lookup,'w'){|f| doc.write f}
  end

  def open_lookup_record(name, id)
    lookup_path = "%s%s_lookup.xml" % [@file_path, name]
    lookup = Document.new File.open(lookup_path,'r').read
    [lookup, XPath.first(lookup.root, "records/entry[id='#{id}']")]
  end

  def select_page(lookup, number)

    doc = Document.new File.open(@file_path + lookup,'r').read
    x1 = (number - 1) * 10
    x2 = x1 + 9

    a = XPath.match(doc.root,'records/entry').reverse[x1..x2]
    xpath_ids = "entry[%s]" % a.map{|x| x.attribute('id').value}.map{|x| "@id='%s'" % x}.join(' or ')

    temp_doc = Document.new '<root/>'
    a.map{|x| x.text('file').to_s}.uniq.each do |file|
      doc = Document.new File.open(file,'r').read
      XPath.each(doc.root,'records/entry') do |entry|
        temp_doc.root.add entry
      end
    end

    result = Document.new '<result><summary/><records/></result>'
    records = XPath.first(result.root, 'records')
    XPath.each(temp_doc.root, xpath_ids) do |record|
      records.add record
    end

    result
  end

  def new_blog_file(filename)
    dynarex = Dynarex.new('entries/entry(title,body,tags)')
    dynarex.summary[:format_mask].gsub!(/\s/,'; ')
    dynarex.save @file_path + filename
    dynarex
  end

  def new_lookup_file(filename)
    lookup = Dynarex.new('entries/entry(id,file,year,month,uri)')
    lookup.save @file_path + filename
    lookup
  end

  def create_record(record, id, name, type)

    entry_count = @entities.xpath "records/section[summary/name='#{type}']/records/entity/summary[name='#{name}']/count"
    lookup_path = "%s%s_lookup.xml" % [@file_path, name]

    if entry_count.nil?
      @entities.id('tags').create.entity(name: name, count: '1')
      @entities.save @file_path + 'entities.xml'
      @entities = Polyrex.new @file_path + 'entities.xml'
      entry_count = @entities.xpath "records/section[summary/name='#{type}']/records/entity/summary[name='#{name}']/count"

      dynarex = Dynarex.new('entries/entry(title,body,tags)')
      dynarex.summary[:format_mask].gsub!(/\s/,'; ')
      dynarex_path = @file_path + name + '1.xml'
      dynarex.save dynarex_path

      new_lookup_file lookup_path

    end

    entry_file = "%s%s.xml" % [name, entry_count.text]
    dynarex_path = "%s%s" % [@file_path, entry_file]
    dynarex = Dynarex.new dynarex_path
    
    dynarex.create record, id
    dynarex.save dynarex_path

    # add the record to lookup

    lookup = Dynarex.new lookup_path
    lookup.create id: id, file: entry_file, year: Time.now.strftime("%Y"), month: Time.now.strftime("%m"), uri: record[:title].gsub(/\s/,'-')
    lookup.save lookup_path
    
    # if there is 15 items create a new entries file
    if dynarex.records.length >= 15 then

      entry_count.text = (entry_count.text.to_i + 1).to_s
      @entities.save @file_path + 'entities.xml'

      dynarex = new_blog_file "%s%s.xml" % [name, entry_count.text]

    end
  end

end
