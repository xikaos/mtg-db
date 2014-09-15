require_relative '../script_util.rb'
require_relative './dump_sets.rb'

class CardDumper
  OUTPUT = File.expand_path('../../../data/gatherer/cards.json', __FILE__)

  def self.existing
    read(OUTPUT).map{|c| [[c['set_name'], c['collector_num']], c]}.to_h
  end

  def initialize(sets)
    all_sets = SetDumper.existing
    @sets = sets.empty? ? all_sets.values : all_sets.slice(*sets).values
  end

  def cards
    @sets.map do |set|
      processed_cards = []; page = 1; num_pages = 1
      while num_pages >= page
        results = SetDumper.search(set['name'], page-1)
        processed_cards += process_page(results)
        num_results = results.css('[id*="_searchTermDisplay"]').text.scan(/\((\d+)\)/).join.to_i
        num_pages = (num_results / 100.0).ceil; page += 1
      end
      # TODO: Filter out duplicate cards. See: APC Fire/Ice duplicate printings
      processed_cards.flatten.sort_by{|card| card['collector_num'].to_i}
    end.flatten
  end

  def process_page(page)
    page.css('.cardItem').map do |row|
      card_name = row.css('.name').text.strip
      row.css('.printings a').map do |a|
        printing_id = a.href.match(/multiverseid=(\d+)/)[1]
        Card.new(card_name, printing_id).as_json
      end
    end
  end

end

class Card
  SUPERTYPES = %w[Basic Legendary World Snow]

  def initialize(name, id)
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
    # Gatherer does some weird shit with the numbers for split cards. Calculate
    # the correct number using the order of the "(Fire // Ice)" name
    if split_card?
      available_numbers = @page.css('.row[id*="_numberRow"] .value').map{|div| div.text.strip}.sort
      return available_numbers[ split_card_name.split('/').index(@given_name) ]
    end
    value_of('number')
  end

  def types
    value_of('type').split("—").map(&:strip)[0].split(' ') - SUPERTYPES
  end
  def supertypes
    (value_of('type').split("—").map(&:strip)[0].split(' ') & SUPERTYPES) || []
  end
  def subtypes
    value_of('type').split("—").map(&:strip)[1].split(' ') rescue []
  end

  def mana_cost
    case @given_name # Exceptions
    when 'Little Girl'; return 'W'
    end

    @content.css('.row[id*="_manaRow"] img').map do |img|
      cost = translate_icon(img.alt)
      cost.match(/^\{(\w{1}|\d+)\}$/) ? cost.gsub( /^\{|\}$/, '') : cost #/# this line fucks with syntax highlighting
    end.join
  end

  def oracle_text
    case @given_name # Exceptions
    when 'Cheap Ass'
      return ["Spells you play cost {½} less to play."]
    when 'Flaccify'
      return ["Counter target spell unless its controller pays {3}{½}."]
    when 'Mox Lotus'
      return ["{T}: Add {∞} to your mana pool.",
              "{100}: Add one mana of any color to your mana pool.",
              "You don't lose life due to mana burn."]
    end

    @content.css('.row[id*="_textRow"] .cardtextbox').map do |line|
      line.css('img').each do |img|
        img.content = translate_icon(img.alt)
      end
      line.text.strip.presence
    end.compact
  end

  def power
    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "P/T:"
      value = row.css('.value').text
      return "1/2" if value == "{1/2} / {1/2}" # Exception for Unhinged's "Little Girl"
      value.split('/')[0].strip
    end
  end

  def toughness
    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "P/T:"
      value = row.css('.value').text
      return "1/2" if value == "{1/2} / {1/2}" # Exception for Unhinged's "Little Girl"
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
      card_name = names.find{|name| name != @given_name}
      if split_card?
        "#{card_name} (#{split_card_name})" # ex: Ice (Fire/Ice)
      else
        card_name
      end
    end
  end

  def as_json
    load_content
    {
      'name'                => name,
      'set_name'            => value_of('set'),
      'collector_num'       => collector_num,
      'illustrator'         => value_of('artist'),
      'types'               => types,
      'supertypes'          => supertypes,
      'subtypes'            => subtypes,
      'rarity'              => value_of('rarity'),
      'mana_cost'           => mana_cost,
      'converted_mana_cost' => value_of('cmc').to_i,
      'oracle_text'         => oracle_text,
      'flavor_text'         => value_of('flavor'),
      'power'               => power,
      'toughness'           => toughness,
      'loyalty'             => loyalty,
      'multiverse_id'       => @multiverse_id.to_i,
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

  def translate_icon(name)
    case name
    when 'White'; '{W}'
    when 'Blue';  '{U}'
    when 'Black'; '{B}'
    when 'Red';   '{R}'
    when 'Green'; '{G}'
    when 'White or Blue';  '{W/U}'
    when 'White or Black'; '{W/B}'
    when 'Blue or Black';  '{U/B}'
    when 'Blue or Red';    '{U/R}'
    when 'Black or Red';   '{B/R}'
    when 'Black or Green'; '{B/G}'
    when 'Red or White';   '{R/W}'
    when 'Red or Green';   '{R/G}'
    when 'Green or White'; '{G/W}'
    when 'Green or Blue';  '{G/U}'
    when 'Two or White'; '{2/W}'
    when 'Two or Blue';  '{2/U}'
    when 'Two or Black'; '{2/B}'
    when 'Two or Red';   '{2/R}'
    when 'Two or Green'; '{2/G}'
    when 'Phyrexian';       '{P}'
    when 'Phyrexian White'; '{WP}'
    when 'Phyrexian Blue';  '{UP}'
    when 'Phyrexian Black'; '{BP}'
    when 'Phyrexian Red';   '{RP}'
    when 'Phyrexian Green'; '{GP}'
    when 'Snow';  '{S}'
    when 'Tap';   '{T}'
    when 'Untap'; '{Q}'
    when 'Variable Colorless'; '{X}'
    when /^(\d+)$/
      "{#{$1}}"
    else
      raise "Unknown icon: #{name}"
    end
  end
end

def merge(data)
  existing = CardDumper.existing
  data.each do |card|
    key = [card['set_name'], card['collector_num']]
    existing[key] = (existing[key] || {}).merge(card)
  end
  existing.values
end

if __FILE__==$0
  write CardDumper::OUTPUT, merge( CardDumper.new(ARGV).cards )
end
