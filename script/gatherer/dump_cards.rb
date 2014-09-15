require_relative '../script_util.rb'
require_relative './dump_sets.rb'

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
      num_results = results.css('[id*="_searchTermDisplay"]').text.scan(/\((\d+)\)/).join.to_i
      num_pages = (num_results / 100.0).ceil; page += 1
    end; processed.flatten!

    # For older sets without collector_nums, assign numbers based on multiverse_id
    if processed.any?{|c| c['collector_num'].blank?}
      if processed.any?{|c| c['collector_num'].present?}
        raise "Some cards have collector_num, some don't."
      end
      processed.sort_by{|c| c['multiverse_id']}.each_with_index do |card, i|
        card['collector_num'] = (i+1).to_s
      end
    end

    processed.sort_by do |card|
      [card['collector_num'].to_i, card['collector_num']]
    end
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
    end.join.presence
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
    when 'Plains';   ['({T}: Add {W} to your mana pool.)']
    when 'Island';   ['({T}: Add {U} to your mana pool.)']
    when 'Swamp';    ['({T}: Add {B} to your mana pool.)']
    when 'Mountain'; ['({T}: Add {R} to your mana pool.)']
    when 'Forest';   ['({T}: Add {G} to your mana pool.)']
    end

    @content.css('.row[id*="_textRow"] .cardtextbox').map do |line|
      line.css('img').each do |img|
        img.content = translate_icon(img.alt)
      end
      line.text.strip.presence
    end.compact
  end

  def power
    case @given_name # Exceptions
    when 'Little Girl'; return '1/2'
    end

    row = @content.css('.row[id*="_ptRow"]')
    if row.css('.label').text.strip == "P/T:"
      value = row.css('.value').text
      value.split('/')[0].strip
    end
  end

  def toughness
    case @given_name # Exceptions
    when 'Little Girl'; return '1/2'
    end

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
      'illustrator'         => value_of('artist'), # TODO: Fix for split cards with different illustrators
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
    dumper = CardDumper.new(set)
    write dumper.output, merge(dumper.cards, dumper.output)
  end
end
