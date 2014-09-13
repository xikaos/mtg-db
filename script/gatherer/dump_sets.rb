require_relative '../script_util.rb'

FILE_PATH = File.expand_path('../../../data/gatherer/_sets.json', __FILE__)

class SetDumper
  class << self
    def sets
      page = get("http://gatherer.wizards.com/Pages/Default.aspx")
      dropdown = page.css('select').find{|s| s.id.match('_set')}
      dropdown.css('option').map do |option|
        next if option.text.empty?
        parse_set(option.text)
      end.compact
    end

    def parse_set(name)
      results = get("http://gatherer.wizards.com/Pages/Search/Default.aspx?output=compact&set=[\"#{name}\"]")
      set_img = results.css('img').find{|img| img.src.match(/&set=/)}
      if set_img.nil?
        print "No Results for #{name}. Press Enter to Continue"; gets; nil
      else
        set_code = set_img.src.match(/&set=([^&]+)/)[1]
        {'name' => name, 'gatherer_code' => set_code}
      end
    end
  end
end

def key(set_json); set_json['gatherer_code']; end
def merge(data)
  existing = read(FILE_PATH).map{|s| [key(s), s]}.to_h
  data.each do |set|
    existing[key(set)] = (existing[key(set)] || {}).merge(set)
  end
  existing.values.sort_by{|s| s['name']}
end

write FILE_PATH, merge(SetDumper.sets)
