require 'cgi'
require 'fileutils'
require 'multi_json'
require 'nokogiri'
require 'open-uri'

class Object
  def try(*a, &b)
    __send__(*a, &b) unless self.nil?
  end
  def in?(collection)
    collection.include?(self)
  end
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end
  def present?
    !blank?
  end
  def presence
    self if present?
  end
end

class Hash
  def slice(*keys)
    keys.each_with_object({}) do |k, hash|
      hash[k] = self[k] if has_key?(k)
    end
  end
end

class Nokogiri::XML::Element
  alias_method :_method_missing, :method_missing
  def method_missing(meth, *a, &b)
    get_attribute(meth) || _method_missing(meth, a, b)
  end
end

def get(url)
  puts "getting #{url}"
  Nokogiri::HTML(open(URI.escape url))
end

def read(path)
  puts "reading #{path}"
  File.open(path, 'r') do |file|
    return MultiJson.load(file.read)
  end
rescue
  []
end

def write(path, data)
  puts "writing #{path}"
  File.open(path, 'w') do |file|
    file.puts MultiJson.dump(data, pretty: true).gsub(/\[\s+\]/, '[]')
  end
end
