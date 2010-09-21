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
    
    @hc_result = HashCache.new(size: 10)
    @hc_entry_file = HashCache.new(size: 10)
    @hc_lookup_a = HashCache.new(size: 10)
    
    raw_tags = @entities.xpath "records/section[summary/name='tags']/records"    
    @tags = XPath.match(raw_tags, 'entity/summary').map{|tag| %w(name entry_count).map {|x| tag.text(x).to_s} }    
    super()
  end

  def create_entry(record={})

    @hc_result.reset
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
    if record[:tags] then
      record[:tags].split(/\s/).each do |tag|
        create_record(record, @id.to_s, name=tag, type='tags')
      end
    end    
    
  end  
    
  def entry(id)
    doc_lookup = @hc_lookup.read(@current_lookup) { Document.new File.open(@file_path + @current_lookup,'r').read }
    file = XPath.first(doc_lookup.root, "records/entry[id='#{id}']/file/text()").to_s
    doc_entries = Document.new(@hc_entry_file.read(file) { File.open(@file_path + file,'r').read })
    XPath.first(doc_entries.root, "records/entry[@id='#{id}']")
  end
  
  def update(id, h)
    lookup = Dynarex.new @file_path + @current_lookup
    lookup_id = lookup.records[id][:id]
    file = lookup.records[id][:body][:file]

    dynarex = Dynarex.new(@file_path + file) 
    prev_tags = dynarex.record(id).tags
    cur_tags = h[:tags]
    
    if cur_tags.length > 0 then
      
      a = cur_tags.split(/\s/)
    
      if prev_tags and prev_tags.length > 0 then
	
	b = prev_tags.split(/\s/)
	old_list = a - b # tags to be deleted
	new_list = b - a # tags to be inserted
	
	old_list.each {|x| delete_entry(tag_name, id) }
	common = a.to_set.intersection(b).to_a # tags to be updated     
	common.each {|name|  update_entry(name, id, h) }
      else
	new_list = a
      end
      
      new_list.each {|tag| create_record(h, id, name=tag, type='tags') }
      
      dynarex.update(id, h)
      dynarex.save
    end
    
    lookup.update(lookup_id, uri: h[:title].gsub(/\s/,'-')).save
    @hc_lookup.write(@current_lookup) { Document.new File.open(@file_path + @current_lookup,'r').read }        

    refresh_index if index_include? id

  end

  def delete(id='')

    # delete from the tags files (entry and lookup), the entry file and lookup
    # look the id up in lookup.xml

    lookup = Dynarex.new @file_path + @current_lookup
    lookup_id = lookup.records[id][:id]
    file = lookup.records[id][:body][:file]
    
    dynarex = Dynarex.new(@file_path + file)    
    tags = dynarex.record(id).tags.split(/\s/)
    dynarex.delete(id).save

    lookup.delete(lookup_id).save

    tags.each do |tag_name|
      # find the lookup
      delete_entry(tag_name, id)
    end

    # start of reindexing
    refresh_index if index_include? id
    
  end

  def fresh_start()

    @id = 1
    @dynarex = new_blog_file '_entry1.xml'
    @index = new_blog_file 'index.xml'

    @entities = Polyrex.new('entities/section[name]/entity[name,count,entry_count]')
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

    result = nil
    
    result = @hc_result.read(lookup + number.to_s) do

      if (number == 1) and (lookup == '_entry_lookup.xml') and (@index.records.length == 10) then 
        doc = @hc_lookup.refresh(lookup)
        r = Document.new(File.open(@file_path + 'index.xml','r').read)        
      else
	doc = @hc_lookup.read(lookup) { Document.new File.open(@file_path + lookup,'r').read }        
        r = select_page(doc, number)
        @current_lookup = '_entry_lookup.xml'
        
        # refresh to maintain _entry_lookup in the cache
        @hc_lookup.refresh(@current_lookup) 
        @hc_lookup_a.refresh(@current_lookup)
      end
      
      total_records = XPath.first(doc.root, 'count(records/entry)')
      total_pages, remainder = %w(/ %).map {|x| total_records.send x, 10}
      total_pages += 1 if remainder > 0      
      
      summary = {
        total_records: total_records,
        page_number: number,
        total_pages: total_pages
      }
      
      summary.each do |name, text|
        r.root.elements['summary'].add Element.new(name.to_s).add_text(text.to_s)  
      end    
      
      r
    end
    
    result
  end

  def tag(tag)      
    @current_lookup = (@tags.assoc(tag) ? tag  : '_404') + '_lookup.xml'      
    self
  end
  
  def tags
    @tags
  end
  
  def rebuild_index()
    refresh_index()
  end
    
  private

  def delete_entry(lookup_filename, id)
    
    lookup_path = "%s%s_lookup.xml" % [@file_path, lookup_filename]    
    lookup = Dynarex.new lookup_path
    
    lookup_id = lookup.records[id][:id]
    file = lookup.records[id][:body][:file]
    lookup.delete(lookup_id).save    
    
    Dynarex.new(@file_path + file).delete(id).save
    delete_cache_entry(lookup_filename, file)

  end
  
  def update_entry(lookup_filename, id, h)

    lookup_path = "%s%s_lookup.xml" % [@file_path, lookup_filename]    
    lookup = Dynarex.new lookup_path
    lookup_id = lookup.records[id][:id]
    
    file = lookup.records[id][:body][:file]
    lookup.update(lookup_id, uri: h[:title].gsub(/\s/,'-')).save    

    Dynarex.new(@file_path + file).update(id, h).save        
    delete_cache_entry(lookup_filename, file)
  end  

  def delete_cache_entry(lookup_filename, file)
    
    @hc_entry_file.delete(file)
    pg = file[/\d+\.xml$/]
    
    if pg then
      @hc_result.delete(lookup_filename + pg) 
      @hc_lookup_a.delete(lookup_filename + pg)
    end
    
    @hc_lookup.delete(lookup_filename)    
  end

  def select_page(doc, number)

    #doc = Document.new File.open(@file_path + lookup,'r').read    
    
    x1 = (number - 1) * 10
    x2 = x1 + 9

    lookup_a = @hc_lookup_a.read(@current_lookup + number.to_s) {XPath.match(doc.root,'records/entry')}
    a = lookup_a.reverse[x1..x2]
    

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

    delete_cache_entry(lookup_file, entry_file)
    # add the record to lookup

    lookup = Dynarex.new @file_path + lookup_file
    lookup.create id: id, file: entry_file, year: Time.now.strftime("%Y"), month: Time.now.strftime("%m"), uri: record[:title].gsub(/\s/,'-')
    lookup.save @file_path + lookup_file
    @hc_lookup.write(lookup_file) { Document.new File.open(@file_path + lookup_file,'r').read }
    
    # if there is 15 items create a new entries file
    if dynarex.records.length >= 15 then

      entry_count.text = (entry_count.text.to_i + 1).to_s
      @entities.save @file_path + 'entities.xml'

      dynarex = new_blog_file "%s%s.xml" % [name, entry_count.text]

    end
  end
  
  def refresh_index()
    doc_index = Document.new File.open(@file_path + 'index.xml','r').read

    node_records = XPath.first(doc_index.root, 'records')
    node_records.parent.delete node_records

    lookup = '_entry_lookup.xml'
    doc = Document.new File.open(@file_path + lookup,'r').read
    page = select_page(doc, 1)
    doc_index.root.add XPath.first(page.root, 'records')

    File.open(@file_path + 'index.xml', 'w'){|f| doc_index.write f}
    @index = Dynarex.new @file_path + 'index.xml'    
  end  
  
  def index_include?(id)
    doc = Document.new File.open(@file_path + 'index.xml','r').read
    XPath.first(doc.root, "records/entry[@id='#{id}']")
  end

end
