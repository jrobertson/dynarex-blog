# Introducing the Dynarex Blog gem

* 18-Mar-2014: This gem isn't currently being maintained. *

The Dynarex Blog gem is an XML based Blog publishing sytem.

## Installation

`sudo gem install dynarex-blog`

## Example

    require 'dynarex-blog'

    blog = DynarexBlog.new
    blog.create_entry title: "abc2", body: "aaa", tags: "aasd fwerf"

Notes: 
* A maximum of 10 entries are stored in the index.xml file.
* A maximum of 15 entries are stored in the back-end files.
* The lookup files primarily contain all the ids for the blog.
* To view a page containing 10 blog entries use Blog#page(number).
* To delete a blog entry use Blog#delete(id).
* Ideally create a new blog from an empty directory e.g. DynarexBlog.new '~/jrobertson/blog'

Here's the output directory listing for the excuted code above:

<pre>
james@lucia:~/learning/ruby/blog$ ls -ltr
total 32
-rw-r--r-- 1 james james 425 2010-06-03 00:20 index.xml
-rw-r--r-- 1 james james 425 2010-06-03 00:20 entry1.xml
-rw-r--r-- 1 james james 481 2010-06-03 00:20 entry_lookup.xml
-rw-r--r-- 1 james james 425 2010-06-03 00:20 aasd1.xml
-rw-r--r-- 1 james james 480 2010-06-03 00:20 aasd_lookup.xml
-rw-r--r-- 1 james james 872 2010-06-03 00:20 entities.xml
-rw-r--r-- 1 james james 425 2010-06-03 00:20 fwerf1.xml
-rw-r--r-- 1 james james 481 2010-06-03 00:20 fwerf_lookup.xml
</pre>

Here's what index.xml looks like:
<pre>
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;entries&gt;
  &lt;summary&gt;
    &lt;recordx_type&gt;dynarex&lt;/recordx_type&gt;
    &lt;format_mask&gt;[!title]; [!body]; [!tags]&lt;/format_mask&gt;
    &lt;schema&gt;entries/entry(title,body,tags)&lt;/schema&gt;
  &lt;/summary&gt;
  &lt;records&gt;
    &lt;entry id="2" created="2010-06-03 00:20:33 +0100" last_modified=""&gt;
      &lt;title&gt;abc2&lt;/title&gt;
      &lt;body&gt;aaa&lt;/body&gt;
      &lt;tags&gt;aasd fwerf&lt;/tags&gt;
    &lt;/entry&gt;
  &lt;/records&gt;
&lt;/entries&gt;
</pre>

Here's the lookup file:
<pre>
&lt;?xml version="1.0" encoding="UTF-8"?&gt;
&lt;entries&gt;
  &lt;summary&gt;
    &lt;recordx_type&gt;dynarex&lt;/recordx_type&gt;
    &lt;format_mask&gt;[!id] [!file] [!year] [!month] [!uri]&lt;/format_mask&gt;
    &lt;schema&gt;entries/entry(id,file,year,month,uri)&lt;/schema&gt;
  &lt;/summary&gt;
  &lt;records&gt;
    &lt;entry id="1" created="2010-06-03 00:20:33 +0100" last_modified=""&gt;
      &lt;id&gt;2&lt;/id&gt;
      &lt;file&gt;entry1.xml&lt;/file&gt;
      &lt;year&gt;2010&lt;/year&gt;
      &lt;month&gt;06&lt;/month&gt;
      &lt;uri&gt;abc2&lt;/uri&gt;
    &lt;/entry&gt;
  &lt;/records&gt;
&lt;/entries&gt;
</pre>

*update: 03-Jun-2010 @ 5:47pm*

Resources:
* [jrobertson's dynarex-blog at master](http://github.com/jrobertson/dynarex-blog)

