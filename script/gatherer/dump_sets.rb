require_relative '../script_util.rb'

class SetDumper
  OUTPUT = File.expand_path('../../../data/gatherer/sets.json', __FILE__)
  CODE_REPLACEMENT = {
    'al' => 'all', 'aq' => 'atq', 'ap' => 'apc', 'an' => 'arn', 'br' => 'brb',
    'bd' => 'btd', 'ch' => 'chr', '6e' => '6ed', 'ex' => 'exo', 'fe' => 'fem',
    '5e' => '5ed', '4e' => '4ed', 'hm' => 'hml', 'ia' => 'ice', 'in' => 'inv',
    'le' => 'leg', '1e' => 'lea', '2e' => 'leb', 'mm' => 'mmq', 'mi' => 'mir',
    'ne' => 'nem', 'od' => 'ody', 'ps' => 'pls', 'po' => 'por', 'p2' => 'po2',
    'pk' => 'ptk', 'pr' => 'pcy', '3e' => '3ed', '7e' => '7ed', 'p3' => 's99',
    'p4' => 's00', 'st' => 'sth', 'te' => 'tmp', 'dk' => 'drk', 'ug' => 'ugl',
    '2u' => '2ed', 'cg' => 'uds', 'gu' => 'ulg', 'uz' => 'usg', 'vi' => 'vis',
    'wl' => 'wth'
  }
  NAME_REPLACEMENT = {
    'Magic: The Gathering-Commander' => 'Commander',
    'Magic: The Gathering—Conspiracy' => 'Conspiracy',
    'From the Vault: Annihilation (2014)' => 'From the Vault: Annihilation',
    'Magic 2014 Core Set' => 'Magic 2014',
    'Magic 2015 Core Set' => 'Magic 2015'
  }
  SETS_TO_IGNORE = ['Promo set for Gatherer', 'Vanguard']

  class << self
    def sets
      page = get("http://gatherer.wizards.com/Pages/Default.aspx")
      dropdown = page.css('select').find{|s| s.id.match('_set')}
      dropdown.css('option').map do |option|
        next if option.text.empty? || option.text.in?(SETS_TO_IGNORE)
        parse_set(option.text)
      end.compact
    end

    def search(name)
      name = NAME_REPLACEMENT.invert[name] || name # use the set names that gatherer expects
      get("http://gatherer.wizards.com/Pages/Search/Default.aspx?output=compact&set=[\"#{name}\"]")
    end

    def parse_set(name)
      set_img = search(name).css('img').find{|img| img.src.match(/&set=([^&]+)/)}
      if set_img.nil?
        print "No Results for #{name}. Press Enter to Continue"; gets; nil
      else
        code = set_img.src.match(/&set=([^&]+)/)[1].downcase
        { 'name' => NAME_REPLACEMENT[name] || name,
          'code' => CODE_REPLACEMENT[code] || code }
      end
    end

    def existing
      read(OUTPUT).map{|s| [s['code'], s]}.to_h
    end
  end
end

def key(set_json); set_json['code']; end
def merge(data)
  existing = SetDumper.existing
  data.each do |set|
    existing[key(set)] = (existing[key(set)] || {}).merge(set)
  end
  existing.values.sort_by{|s| s['name']}
end

if __FILE__==$0
  write SetDumper::OUTPUT, merge( SetDumper.sets )
end
