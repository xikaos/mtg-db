require_relative '../script_util.rb'
require_relative './dump_sets.rb'

class CardDumper
  OUTPUT = File.expand_path('../../../data/gatherer/cards.json', __FILE__)

  def initialize(sets)
    all_sets = SetDumper.existing
    @sets = sets.empty? ? all_sets.values : all_sets.slice(*sets).values
  end

  def cards
    @sets.each do |set|
      search_results = SetDumper.search( set['name'] )
      search_results.css('.cardItem').map do |row|
        card_name = row.css('.name').text.strip
        row.css('.printings a').map do |a|
          printing_id = a.href.match(/multiverseid=(\d+)/)[1]
          Card.new(card_name, printing_id).as_json
        end
      end#.flatten.uniq.sort_by(&:collector_num) Remove duplicates, because APC split cards
    end
  end
end

class Card
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
      split_card_name = @page.css('.contentTitle').text.strip.gsub('//', '/')
      "#{card_name} (#{split_card_name})" # ex: Fire (Fire/Ice)
    else
      card_name
    end
  end

  def mana_cost
    @content.css('.row[id*="_manaRow"] img').map do |img|
      case img.alt
      when 'White'; 'W'
      when 'Blue'; 'U'
      when 'Black'; 'B'
      when 'Red'; 'R'
      when 'Green'; 'G'
      when '500'; 'W' # Exception for Unhinged's "Little Girl"
      else img.alt
      end
    end.join
  end

  def oracle_text
    # TODO: Replace images (tap, mana, untap, etc.) with {T}, {U} etc.
    @content.css('.row[id*="_textRow"] .cardtextbox').map do |line|
      line.text.strip
    end
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
        split_card_name = @page.css('.contentTitle').text.strip.gsub(' // ', '/')
        "#{card_name} (#{split_card_name})" # ex: Ice (Fire/Ice)
      else
        card_name
      end
    end
  end

  def as_json
    load_content
    require 'pry'; binding.pry
    {
      'name'                => name,
      'set_name'            => value_of('set'),
      'collector_num'       => value_of('number'),
      'illustrator'         => value_of('artist'),
      'types'               => [],
      'supertypes'          => [],
      'subtypes'            => [],
      'rarity'              => value_of('rarity'),
      'mana_cost'           => mana_cost,
      'converted_mana_cost' => value_of('cmc').to_i,
      'oracle_text'         => oracle_text,
      'flavor_text'         => value_of('flavor'),
      'power'               => power,
      'toughness'           => toughness,
      'loyalty'             => loyalty,
      'multiverse_id'       => @multiverse_id,
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
end

if __FILE__==$0
  CardDumper.new( ARGV ).cards
end
