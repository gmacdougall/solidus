# *ProductGroups* are used for creating and managing sets of products.
# Product group can be either anonymous(adhoc) or named.
#
# Anonymous Product groups are created by combining product scopes generated from url
# in 2 formats:
#
#   /t/*taxons/s/name_of_scope/comma_separated_arguments/name_of_scope_that_doesn_take_any//order
#   */s/name_of_scope/comma_separated_arguments/name_of_scope_that_doesn_take_any//order
#
# Named product groups can be created from anonymous ones, lub from another named scope
# (using ProductGroup.from_url method).
# Named product groups have pernament urls, that don't change even after changes
# to scopes are made, and come in two types.
#
#   /t/*taxons/pg/named_product_group
#   */pg/named_product_group
#
# first one is used for combining named scope with taxons, named product group can
# have #in_taxon or #taxons_name_eq scope defined, result should combine both
# and return products that exist in both taxons.
#
# ProductGroup#dynamic_products returns chain of named scopes generated from order and
# product scopes. So you can do counting, calculations etc, on resulted set of products,
# without retriving all records.
#
# ProductGroup operates on named scopes defined for product in Scopes::Product,
# or generated automatically by Searchlogic
#
class ProductGroup < ActiveRecord::Base
  validates_presence_of :name
  validates_associated :product_scopes

  before_save :set_permalink
  before_save :update_memberships

  has_and_belongs_to_many :cached_products, :class_name => "Product"
  # name
  has_many :product_scopes
  accepts_nested_attributes_for :product_scopes 
  #attr_accessible :order_scope

  # Testing utility: creates new *ProductGroup* from search permalink url.
  # Follows conventions for accessing PGs from URLs, as decoded in routes
  def self.from_url(url)
    pg = nil;
    case url
    when /\/t\/(.+?)\/s\/(.+)/  then taxons = $1; attrs = $2;
    when /\/t\/(.+?)\/pg\/(.+)/ then taxons = $1; pg_name = $2;
    when /(.*?)\/s\/(.+)/       then attrs = $2;
    when /(.*?)\/pg\/(.+)/      then pg_name = $2;
    else                        return(nil)
    end

    if pg_name && opg = ProductGroup.find_by_permalink(pg_name)
      pg = new.from_product_group(opg)
    elsif attrs
      attrs = url.split("/")
      pg = new.from_route(attrs)
    end
    taxon = taxons && taxons.split("/").last
    pg.add_scope("in_taxon", taxon) if taxon
    
    pg
  end

  def from_product_group(opg)
    self.product_scopes = opg.product_scopes.map{|ps|
      ps = ps.clone;
      ps.product_group_id = nil;
      ps.product_group = self;
      ps
    }
    self.order = opg.order
    self
  end

  def from_route(attrs)
    self.order = attrs.pop if attrs.length % 2 == 1
    attrs.each_slice(2) do |scope|
      next unless Product.condition?(scope.first)
      add_scope(scope.first, scope.last.split(","))
    end
    self
  end

  def from_search(search_hash)
    search_hash.each_pair do |scope_name, scope_attribute|
      add_scope(scope_name, scope_attribute)
    end
    
    self
  end

  def add_scope(scope_name, arguments=[])
    self.product_scopes << ProductScope.new({
        :name => scope_name.to_s,
        :arguments => [*arguments]
      })
    if scope_name =~ /^(ascend_by|descend_by)/
      self.order = scope_name
    end
    self
  end

  def apply_on(scopish)
    # There's bug in AR, it doesn't merge :order, instead it takes order
    # from first nested_scope so we have to apply ordering first.
    # see #2253 on rails LH
    if !self.order.blank? && Product.condition?(self.order)
      base_product_scope = scopish.send(self.order)
    else
      base_product_scope = scopish
    end

    return self.product_scopes.inject(base_product_scope){|result, scope|
      scope.apply_on(result)
    }
  end

  # returns chain of named scopes generated from order scope and product scopes.
  def dynamic_products
    apply_on(Product.scoped(nil))
  end

  def products
    cached_group = Product.in_cached_group(self)
    if cached_group.limit(1).blank?
      dynamic_products
    else
      product_scopes.ordering.inject(cached_group) {|res,order| order.apply_on(res)}
    end
  end

  def include?(product)
    res = apply_on(Product.id_equals(product.id))
    res.count > 0
  end

  def scopes_to_hash
    result = {}
    self.product_scopes.each do |scope|
      result[scope.name] = scope.arguments
    end
    result
  end

  # generates ProductGroup url
  def to_url
    if (new_record? || name.blank?)
      result = ""
      result+= self.product_scopes.map{|ps|
        [ps.name, ps.arguments.join(",")]
      }.flatten.join('/')
      result+= self.order if self.order
    
      result
    else
      name.to_url
    end
  end

  def set_permalink
    self.permalink = self.name.to_url
  end
  
  def update_memberships
    self.cached_products = dynamic_products
  end

  def to_s
    "<ProductGroup" + (id && "[#{id}]").to_s + ":'#{to_url}'>"
  end
  
  
  def order_scope
    if scope = product_scopes.ordering.first
      scope.name
    end
  end
  def order_scope=(scope_name)
    if scope = product_scopes.ordering.first
      scope.update_attribute(:name, scope_name)
    else
      product_scopes.build(:name => scope_name, :arguments => [])
    end    
  end
  
end
