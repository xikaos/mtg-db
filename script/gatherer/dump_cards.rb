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

  def split_card?; end
  def flip_card?; end
  def rotated_card?; end

  def load_content
    @page = get("http://gatherer.wizards.com/Pages/Card/Details.aspx?multiverseid=#{@multiverse_id}")
    @content = @page.css('.cardComponentContainer').select do |container|
      container.css('.row[id*="_nameRow"] .value').text.strip == @given_name
    end
  end

  def as_json
    load_content
    {
      'name'                => '',
      'set_name'            => '',
      'collector_num'       => '',
      'illustrator'         => '',
      'types'               => [],
      'supertypes'          => [],
      'subtypes'            => [],
      'rarity'              => '',
      'mana_cost'           => '',
      'converted_mana_cost' => 0,
      'oracle_text'         => [],
      'flavor_text'         => '',
      'power'               => '',
      'toughness'           => '',
      'loyalty'             => '',
      'multiverse_id'       => @multiverse_id,
      'other_part'          => '',
      'color_indicator'     => ''
    }
  end
end

if __FILE__==$0
  CardDumper.new( ARGV ).cards
end
