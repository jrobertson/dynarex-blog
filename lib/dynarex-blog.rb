#!/usr/bin/ruby

# file: dynarex-blog.rb

require 'rexml/document'
require 'polyrex'
require 'dynarex'
require 'hashcache'

class DynarexBlog
  include REXML
  
  attr_accessor :id

  def initialize(file_path='./')
    @file_path = file_path[/\/$/] ? file_path : file_path + '/'
    if File.exists? (@file_path + 'index.xml') then  open(@file_path) else fresh_start() end
    @current_lookup = '_entry_lookup.xml'
    @hc_lookup = HashCache.new(size: 15)
    @hc_lookup.read(@current_lookup) { Document.new File.open(@file_path + @current_lookup,'r').read }
    
    @hc_result = HashCache.new(size: 5)
    @hc_entry_file = HashCache.new(size: 5)
    super()
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

    create_record(record, @id.to_s, name='_entry', type='main')
    record[:tags].split(/\s/).each do |tag|
      create_record(record, @id.to_s, name=tag, type='tags')
    end

  end

  def delete(id=0)

    # delete from the tags files (entry and lookup), the entry file and lookup
    # look the id up in lookup.xml

    doc_entry, entry = open_lookup_record '_entry', id

    dynarex_file = @file_path + entry.text('file').to_s
    dynarex = Document.new(File.open(dynarex_file,'r').read)
    dynarex_entry = XPath.first(dynarex.root, "records/entry[@id='#{id}']")
    tags = dynarex_entry.text('tags').split(/\s/)

    dynarex_entry.parent.delete dynarex_entry
    File.open(dynarex_file,'w'){|f| dynarex.write f}

    entry.parent.delete entry
    lookup = "%s%s" % [@file_path, '_entry_lookup.xml']
    File.open(lookup,'w'){|f| doc_entry.write f}

    tags.each do |tag_name|
      # find the lookup
      doc_tag, node_entry = open_lookup_record tag_name, id      
      delete_entry(doc_tag, node_entry, tag_name, id)
    end

    doc = Document.new File.open(@file_path + 'index.xml','r').read
    node = XPath.first(doc.root, "records/entry[@id='#{id}']")

    if node then
      node_records = XPath.first(doc.root, 'records')
      node_records.parent.delete node_records
      records = Element.new 'records'
           
      new_records = select_page('_entry_lookup.xml', 1)
      new_records.each {|record| records.add record}
      doc.root.add records

      File.open(@file_path + 'index.xml', 'w'){|f| doc.write f}
      @index = Dynarex.new @file_path + 'index.xml'
    end
    
  end

  def fresh_start()

    @id = 1
    @dynarex = new_blog_file '_entry1.xml'
    @index = new_blog_file 'index.xml'

    @entities = Polyrex.new('entities/section[name]/entity[name,count]')
    @entities.create.section({name: 'main'}, id='main')
    @entities.id('main').create.entity(name: '_entry', count: '1')
    @entities.create.section({name: 'tags'}, id='tags')
    @entities.save @file_path + 'entities.xml'

    @lookup = new_lookup_file '_entry_lookup.xml'
  end

  def open(file_path='./')

    @file_path = file_path
    threads = []
    threads << Thread.new{
      @index = Dynarex.new @file_path + 'index.xml'
      @id = @index.records ? @index.records.to_a[-1][-1][:id].to_i : 0
    }
    threads << Thread.new{@entities = Polyrex.new @file_path + 'entities.xml'}
    threads.each {|thread| thread.join}

  end

  def page(number=0)
    lookup = @current_lookup
    @current_lookup = '_entry_lookup.xml'
    result = nil
    
    result = @hc_result.read(lookup + number.to_s) do

      if (number == 1) and (lookup == '_entry_lookup.xml') and (@index.records.length == 10) then 
        doc = @hc_lookup.read(@current_lookup)
        r = Document.new(File.open(@file_path + 'index.xml','r').read)        
      else
        doc = @hc_lookup.read(lookup) { Document.new File.open(@file_path + lookup,'r').read }        
        r = select_page(doc, number) 
        @hc_lookup.refresh(@current_lookup) # refresh to maintain @current_lookup in the cache
      end
      
      [
        ['total_records', XPath.first(doc.root, 'count(records/entry)')],
        ['page_number', number]
      ].each do |name, text|
        r.root.elements['summary'].add Element.new(name).add_text(text.to_s)  
      end    
      
      r
    end
    
    result
  end

  def tag(tag)   
    @current_lookup = tag + '_lookup.xml'
    self
  end  
    
  private

  def delete_entry(doc, node, lookup_filename, id)
    file = @file_path + node.text('file').to_s
    Dynarex.new(file).delete(id).save file

    node.parent.delete node
    lookup = "%s%s_lookup.xml" % [@file_path, lookup_filename]
    File.open(lookup,'w'){|f| doc.write f}
  end

  def open_lookup_record(name, id)
    lookup_path = "%s%s_lookup.xml" % [@file_path, name]
    lookup = Document.new File.open(lookup_path,'r').read
    [lookup, XPath.first(lookup.root, "records/entry[id='#{id}']")]
  end

  def select_page(doc, number)

    #doc = Document.new File.open(@file_path + lookup,'r').read
    
    x1 = (number - 1) * 10
    x2 = x1 + 9

    a = XPath.match(doc.root,'records/entry').reverse[x1..x2]

    xpath_ids = "entry[%s]" % a.map{|x| x.text('id').to_s}.map{|x| "@id='%s'" % x}.join(' or ')

    temp_doc = Document.new '<root/>'
    a.map{|x| x.text('file').to_s}.uniq.each do |file|
      doc_entryx = Document.new( @hc_entry_file.read(file) {File.open(@file_path + file,'r').read})
      XPath.each(doc_entryx.root,'records/entry') do |entry|
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
    dynarex = Dynarex.new('entries/entry(title,body,tags,user)')
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
    lookup_file = "%s_lookup.xml" % name

    if entry_count.nil?
      @entities.id('tags').create.entity(name: name, count: '1')
      @entities.save @file_path + 'entities.xml'
      @entities = Polyrex.new @file_path + 'entities.xml'
      entry_count = @entities.xpath "records/section[summary/name='#{type}']/records/entity/summary[name='#{name}']/count"

      dynarex = Dynarex.new('entries/entry(title,body,tags,user)')
      dynarex.summary[:format_mask].gsub!(/\s/,'; ')
      dynarex_path = @file_path + name + '1.xml'
      dynarex.save dynarex_path

      new_lookup_file lookup_file

    end

    entry_file = "%s%s.xml" % [name, entry_count.text]
    dynarex_path = "%s%s" % [@file_path, entry_file]
    dynarex = Dynarex.new dynarex_path
    
    dynarex.create record, id
    dynarex.save dynarex_path

    # add the record to lookup

    lookup = Dynarex.new @file_path + lookup_file
    lookup.create id: id, file: entry_file, year: Time.now.strftime("%Y"), month: Time.now.strftime("%m"), uri: record[:title].gsub(/\s/,'-')
    lookup.save @file_path + lookup_file
    
    # if there is 15 items create a new entries file
    if dynarex.records.length >= 15 then

      entry_count.text = (entry_count.text.to_i + 1).to_s
      @entities.save @file_path + 'entities.xml'

      dynarex = new_blog_file "%s%s.xml" % [name, entry_count.text]

    end
  end

end
