require_relative '../script_util.rb'
require_relative './dump_sets.rb'
require_relative './exceptions.rb'

class CardDumper
  def self.read_file(input)
    read(input).map{|c| [[c['set_name'], c['collector_num']], c]}.to_h
  end

  def initialize(set)
    @set = set
  end

  def output
    folder = File.expand_path('../../../data/gatherer/sets', __FILE__)
    File.join(folder, "#{@set['code']}.json")
  end

  def cards
    processed = []; page = 1; num_pages = 1
    while num_pages >= page
      results = SetDumper.search(@set['name'], page-1)
      processed += process_page(results)
      num_results = results.css('[id*="_searchTermDisplay"]').text.scan(/\((\d+)\)/).last.join.to_i
      num_pages = (num_results / 100.0).ceil; page += 1
    end; processed.flatten!

    processed.sort_by do |card|
      [card['collector_num'].to_i, card['collector_num']]
    end
  end

  def process_page(page)
    page.css('.cardItem').map do |row|
      card_name = row.css('.name').text.strip
      row.css('.printings a').map do |a|
        printing_id = a.href.match(/multiverseid=(\d+)/)[1]
        next if printing_id.in?(CARDS_TO_SKIP)
        Card.new(card_name, printing_id).as_json
      end.compact
    end
  end

end

class Card
  def initialize(name, id)
    # Newer split cards are given as "Down // Dirty (Down)"
    if name.match(/\w+ \/\/ \w+ \(\w+\)/)
      name = name.scan(/\((\w+)\)/).join
    end
    @given_name = name
    @multiverse_id = id
  end

  def load_content
    @page = get("http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=#{@multiverse_id}")
    @content = @page.css('.cardComponentContainer').find do |container|
      container.css('.row[id*="_nameRow"] .value').text.strip == @given_name
    end
  end

  def name
    card_name = value_of('name')
    if split_card?
      "#{card_name} (#{split_card_name})" # ex: Fire (Fire/Ice)
    else
      card_name
    end
  end

  def collector_num
    return COLLECTOR_NUMS[@multiverse_id] if @multiverse_id.in?(COLLECTOR_NUMS)

    # Gatherer does some weird shit with the numbers for split cards. Calculate
    # the correct number using the order of the "(Fire // Ice)" name
    if split_card?
      available_numbers = @page.css('.row[id*="_numberRow"] .value').map{|div| div.text.strip}.sort
      return available_numbers[ split_card_name.split('/').index(@given_name) ]
    end
    value_of('number').tap do |val|
      raise "Found a card without a collector_num: #{@given_name}" if val.blank?
    end
  end

  def illustrator
    # TODO: Fix for split cards with separate illustrators
    case artist = value_of('artist')
    when 'Brian Snoddy'; 'Brian Snõddy'
    else; artist
    end
  end

  SUPERTYPES = %w[Basic Legendary World Snow]
  def types
    value_of('type').split("—").map(&:strip)[0].split(' ') - SUPERTYPES
  end
  def supertypes
    (value_of('type').split("—").map(&:strip)[0].split(' ') & SUPERTYPES) || []
  end
  def subtypes
    vals = value_of('type').split("—").map(&:strip)[1].split(' ') rescue []
    vals.map{|val| val == "Urza’s" ? "Urza's" : val}
  end

  def mana_cost
    return MANA_COST[@multiverse_id] if @multiverse_id.in?(MANA_COST)

    @content.css('.row[id*="_manaRow"] img').map do |img|
      cost = translate_icon(img.alt)
      cost.match(/^\{(\w{1}|\d+)\}$/) ? cost.gsub( /^\{|\}$/, '') : cost #/# this line fucks with syntax highlighting
    end.join.presence
  end

  def oracle_text
    return ORACLE_TEXT[@multiverse_id] if @multiverse_id.in?(ORACLE_TEXT)

    case @given_name
    when 'Plains';   return ['({T}: Add {W} to your mana pool.)']
    when 'Island';   return ['({T}: Add {U} to your mana pool.)']
    when 'Swamp';    return ['({T}: Add {B} to your mana pool.)']
    when 'Mountain'; return ['({T}: Add {R} to your mana pool.)']
    when 'Forest';   return ['({T}: Add {G} to your mana pool.)']
    end

    @content.css('.row[id*="_textRow"] .cardtextbox').map do |line|
      line.css('img').each do |img|
        img.content = translate_icon(img.alt)
      end
      line.text.strip.presence
    end.compact
  end

  def flavor_text
    return FLAVOR_TEXT[@multiverse_id] if @multiverse_id.in?(FLAVOR_TEXT)
    value_of('flavor').to_s.gsub('"—', '" —').gsub('‘', "'").gsub('""', '" "').presence
  end

  def power
    return POWER[@multiverse_id] if @multiverse_id.in?(POWER)

    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "P/T:"
      value = row.css('.value').text
      value.split('/')[0].strip
    end
  end

  def toughness
    return TOUGHNESS[@multiverse_id] if @multiverse_id.in?(TOUGHNESS)

    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "P/T:"
      value = row.css('.value').text
      value.split('/')[1].strip
    end
  end

  def loyalty
    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "Loyalty:"
      row.css('.value').text.strip
    end
  end

  def other_part
    name_rows = @page.css('.row[id*="_nameRow"] .value')
    if name_rows.count > 1
      names = name_rows.map{|row| row.text.strip}
      other_name = names.find{|name| name != @given_name}
      if split_card?
        "#{other_name} (#{split_card_name})" # ex: Ice (Fire/Ice)
      else
        other_name
      end
    end
  end

  def as_json
    load_content
    {
      'name'                => name,
      'set_name'            => value_of('set'),
      'collector_num'       => collector_num,
      'illustrator'         => illustrator,
      'types'               => types,
      'supertypes'          => supertypes,
      'subtypes'            => subtypes,
      'rarity'              => value_of('rarity'),
      'mana_cost'           => mana_cost,
      'converted_mana_cost' => value_of('cmc').to_i,
      'oracle_text'         => oracle_text,
      'flavor_text'         => flavor_text,
      'power'               => power,
      'toughness'           => toughness,
      'loyalty'             => loyalty,
      'multiverse_id'       => @multiverse_id.to_i, # TODO: Fix for split cards with different ids. APC, INV, etc.
      'other_part'          => other_part,
      'color_indicator'     => value_of('colorIndicator')
    }
  end

private

  def value_of(attr)
    @content.css(".row[id*=\"_#{attr}Row\"] .value").text.strip.presence
  end

  def split_card?
    @page.css('.contentTitle').text.match(/\/\//)
  end
  def split_card_name
    @page.css('.contentTitle').text.strip.gsub(' // ', '/')
  end

  def translate_icon(icon_alt)
    if icon_alt.in?(ICONS)
      ICONS[icon_alt]
    elsif icon_alt =~ /^(\d+)$/
      "{#{$1}}"
    else
      raise "Unknown icon: #{icon}"
    end
  end
end

def merge(data, input)
  existing = CardDumper.read_file(input)
  data.each do |card|
    key = [card['set_name'], card['collector_num']]
    existing[key] = (existing[key] || {}).merge(card)
  end
  existing.values
end

if __FILE__==$0
  @sets = ARGV.empty? ? SetDumper.existing.values
                      : SetDumper.existing.slice(*ARGV).values
  @sets.each do |set|
    next if File.exists?("data/gatherer/sets/#{set['code']}.json")
    begin
      dumper = CardDumper.new(set)
      write dumper.output, merge(dumper.cards, dumper.output)
    rescue => e
      puts "rescued #{e}";folder = File.expand_path('../../../data/gatherer/err', __FILE__)
      puts "writing #{path=File.join(folder, "#{set['code']}.err")}"
      File.open(path, 'w'){|file| file.puts "#{e}\n#{e.backtrace.join("\n")}"}
    end
  end
end
