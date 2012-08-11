# A sample MetaWeblog RPC handler. Bear in mind that you will need to rewrite most of it.
#
# Define the standard methods for MetaWeblog API here. If you have a valiation problem or somesuch
# within the method just raise from there, exceptions will be translated into RPC fault codes.
#
# You will need to take a look at (and override) get_entry and friends to retrofit that to your own engine.
#
# Entry struct
#
# A fundamental unit of the MT/MW API is the Entry struct (a Hash). Return that Hash
# anytime an entry struct is required. Here a short intro on the fields of the struct (you can use
# both symbols and strings for keys):
#   title, for the title of the entry;
#   description, for the body of the entry;
#   dateCreated, to set the created-on date of the entry;
#   In addition, Movable Type’s implementation allows you to pass in values for five other keys:
#   int mt_allow_comments, the value for the allow_comments field;
#   int mt_allow_pings, the value for the allow_pings field;
#   String mt_convert_breaks, the value for the convert_breaks field;
#   String mt_text_more, the value for the additional entry text;
#   String mt_excerpt, the value for the excerpt field;
#   String mt_keywords, the value for the keywords field;
#   String mt_basename, the value for the slug field;
#   array mt_tb_ping_urls, the list of TrackBack ping URLs for this entry;
#
# If specified, dateCreated should be in ISO.8601 format.
# Also note that most blogging clients will have BIG issues if you supply non-UTC timestamps, so if you
# are using ActiveRecord timezone support (and you should!) take care to do all of your RPC operations
# with all timezones switched to UTC.
class BlogRPC::SampleHandler < BlogRPC::BasicHandler
  
  # An example mapping for the XMLRPC fieldnames to ActiveRecord fields.
  STRUCT_TO_ENTRY = {
    "title" => "title", 
    "description" => "body",
    "dateCreated" => "created_at",
    "mt_text_more" => "more",
    "mt_basename" => "slug",
    "mt_allow_comments" => "allow_comments",
    "permalink" => "permalink",
    "link" => "permalink",
    "postId" => "id"
  }
  
  STRUCT_TO_CATEGORY = {
    "categoryId" => "id",
    "categoryName" => "title",
  }
  
  # Should return something like [{:key => '__markdown__', :label => "Markdown"}]
  # This is used to form a formatting menu in blog clients that allow choices in formatting
  rpc "mt.supportedTextFilters", :out => :array do
    [
      {:key => '__default__', :label => "Convert Line Breaks"},
      {:key => '__markdown__', :label => "Markdown"}
    ]
  end
  
  # Toggle the draft flag and return true.
  rpc "mt.publishPost", :in => [:int, :string, :string], :out => :bool do | postid, user, pw |
    login!(user, pw)
    get_entry(postid).update_attributes :draft => false
    true
  end
  
  # Delete the post. Appkey can be ignored since it's Google specific.
  rpc "blogger.deletePost", :in => [:string, :int, :string, :string, :bool], :out => :bool do | appkey, postid, user, pw, void |
    login! user, pw
    get_entry(postid).destroy
    true
  end
  
  # Return an Array of Hashes from here that define available categories.
  # Category hashes look like this: {categoryId: 1, categoryTitle: "Bad RPC practices"}
  rpc "mt.getCategoryList", :in => [:int, :string, :string], :out => :array do | blogid, user, pw |
    login! user, pw
    check_blog_permission! user, blogid
    find_all_categories.map do | c |
      category_to_struct(c)
    end
  end
  
  # Get the categories of a specific entry.
  # Return an Array of Hashes from here - categories assigned to the passed post.
  # You can also set {isPrimary: false} or true to denote the primary category.
  rpc "mt.getPostCategories", :in => [:int, :string, :string], :out => :array do | postid, user, pw |
    login! user, pw
    cats = get_entry(postid).categories
    cats.map {|c| category_to_struct(c).merge(:isPrimary => false) }
  end
  
  # Sets the post categories. The last argument is an Array of category Hashes, see above.
  rpc "mt.setPostCategories", :in => [:int, :string, :string, :array], :out => :bool do | postid, user,pw, categories |
    login! user, pw
    entry = get_entry(postid)
    set_category_ids(entry, categories.map{|c| c["categoryId"]})
    true
  end
  
  # Returns the recent post titles. This is used by blog clients to speed up listings of entries since
  # this only retreives some information. By default, this method should send the following data about an entry:
  #   userId, dateCreated, postId, title 
  rpc "mt.getRecentPostTitles", :in => [:int, :string, :string, :int], :out => :array do | blogid, user, pw, num |
    login! user, pw
    defaults = {:userId => 1}
    short_keys = %w( dateCreated postId title userid)
    latest_entries(num).map do | entry |
      struct = {}
      short_keys.each { | k | struct[k] = entry[STRUCT_TO_ENTRY[k]] }
      defaults.merge(struct)
      struct
    end
  end
  
  # Returns the trackback pings of the entry. Most likely you will not be using this.
  # { 
  #   pingTitle  string  -- the title of the entry sent in the ping
  #   pingURL string  -- the URL of the entry
  #   pingIP  string  -- the IP address of the host that sent the ping
  # }
# rpc "mt.getTrackbackPings", :in => [:int, :string, :string], :out => :array do | entry_id, user, pw |
#   login! user, pw
#   []
# end

  # Create a new post. The entry Hash has all the standard fields. Should return the ID of the entry created as a String
  rpc "metaWeblog.newPost", :in => [:int, :string, :string, :struct, :bool], :out => :string do | blogid, user, pw, entry_struct, publish_bit |
    login! user, pw
    e = make_new_entry
    change_entry(e, entry_struct, publish_bit)
    e[e.class.primary_key].to_s
  end
  
  # Change an entry replacing fields in the passed Hash. The last argument is the "publish bit" - whether the entry is published or draft.
  # Return true when change succeeded.
  rpc "metaWeblog.editPost", :in => [:int, :string, :string, :struct, :bool], :out => :bool do | entry_id, user, pw, entry_struct, publish_bit |
    login! user, pw
    change_entry(get_entry(entry_id), entry_struct, publish_bit)
    true
  end
  
  # Returns an array of blogs [{:url => blog_url, :blogid => "1", :blogName => "The only blog here"}]
  # The irony is that this is the way MT supports many blog RPCs on one install, so it's a good idea
  # to handle that at least as a bogus function. We will provide a reasonable default.
  rpc "blogger.getUsersBlogs", :in => [:string, :string, :string], :out => :array do | void, user, pw |
    login! user, pw
    blog = {:url => blog_url, :blogid => "1", :blogName => "The only blog here"}
    [blog]
  end
  
  # Retreive an entry by ID. Should return the entry struct.
  rpc "metaWeblog.getPost", :in => [:int, :string, :string], :out => :struct do | entry, user, pw |
    login! user, pw
    entry_to_struct( get_entry(entry) )
  end
    
  # Retreive N last posts, but in their complete form (unlinke getRecentPostTitles)
  rpc "metaWeblog.getRecentPosts", :in => [:int, :string, :string, :int], :out => :array do | blogid, user, pw, num |
    login! user, pw
    check_blog_permission! user, blogid
    latest_entries(num).map {|e| entry_to_struct(e) }
  end
  
  # Creates a file on the server. The passed file Hash has:
  #   bits: the byte content of the upload, in a String
  #   name: the path to put the file to relative to the site root
  # It should return a struct like {url: "http://z.com/img.png"}
  # Note that at least for MarsEdit the URL of the uploaded image should be canonical (with host data)
  # for the preview to display properly.
  # Remember the Rack env object is available for resolving hosts and such!
  rpc "metaWeblog.newMediaObject", :in => [:int, :string, :string, :struct], :out => :struct do | blogid, user, pw, file_struct |
    login! user, pw
    check_blog_permission! user, blogid
    
    file_struct['name'] = file_struct["name"].gsub(/\.\./, '').squeeze('/').gsub(/\s/, '_')
    sanitized_name = File.expand_path(File.join(site_root, file_struct["name"]))
    FileUtils.mkdir_p(File.dirname(sanitized_name))
    
    # Wind the file name if such a file exists
    dir, file = File.dirname(sanitized_name), File.basename(sanitized_name)
    parts = file.split(/\./)
    ext = parts.pop
    counter = 2
    #dbg "Detected sanitized name #{sanitized_name}"
    while File.exist?(sanitized_name)
     #dbg "Already uploaded, winding counter"
      sanitized_name = File.join(dir, [parts, counter, ext].join('.'))
      #puts "Made #{sanitized_name}"
      counter += 1
    end
    
    File.open(sanitized_name, 'w') { |o| o << file_struct["bits"] }
    
    return {:url => File.join(env["HOST"], sanitized_name), :saved_to => sanitized_name }
  end
  
  private
  
  # The following methods are just an example of how you would approach such a handler.
  # Normally you would rewrite almost all of the rpc method implementations.
  
  # Get the site root
  def site_root
    File.dirname(__FILE__)
  end
  
  # Get an entry by ID
  def get_entry(id)
    Entry.find(id)
  end
  
  # Get categories of the entry. The entry passed will be one recieved from one of your own methods
  def get_categories_of(entry)
    entry.categories.map{|c| category_to_struct(c) }
  end
  
  # Assign category ids to an entry
  def set_category_ids(entry, ids)
    entry.category_ids = ids
    entry.save!
  end
  
  # Convert a category to RPC struct (hash)
  def category_to_struct(c)
    STRUCT_TO_CATEGORY.inject({}) do | struct, kv |
      struct[kv[0]] = c[kv[1]].to_s
      struct
    end
  end
  
  def find_all_categories
    Category.find(:all)
  end
  
  # Get a fresh entry
  def make_new_entry
    Entry.new
  end
  
  # Change an entry with data in the entry_struct, honoring the publish bit
  def change_entry(entry_obj, entry_struct, publish_bit)
    entry_struct.each_pair do | k, v |
      # ActiveRecord YAMLifies that if we are not careful. XML-RPC gives us Time.to_gm by default
      v = v.to_time if(v.is_a?(XMLRPC::DateTime))
      model_field = STRUCT_TO_ENTRY[k]
      entry_obj.send("#{model_field}=", v) if model_field
    end
    entry_obj.save!
  end
  
  # Return the latest N entries
  def latest_entries(n)
    Entry.find(:all, :order => 'created_at DESC', :limit => n)
  end
    
  # Transform an entry into a struct
  def entry_to_struct(entry)
    STRUCT_TO_ENTRY.inject({}) do | struct, kv |
      k, v = kv
      
      # Dates and times have to pass through unscathed, converted to utc (!)
      struct[k] = if entry[v].respond_to?(:strftime)
        entry[v].utc
      else
        entry[v].to_s
      end
      struct
    end
  end

  # Raise from here if the user is illegal
  def login!(user, pass)
  end
  
  # Return your blog url from here
  def blog_url
  end
  
  # Raise from here if the user cannot post to this specific blog
  def check_blog_permission!(blog_id, user)
  end
end
