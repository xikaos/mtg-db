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

  CARDS_TO_SKIP = [
    '47784', '47787', '47785', '47786', '49056', '47788', '47789', # Eighth Edition Box Set
    '83064', '83319', '84073', '83104', '94912', '94911', '94910', '83075', '94914' # Ninth Edition Box Set
  ]
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

  COLLECTOR_NUMS = {
    # Classic Sixth Edition
    '15358'=>'14','14472'=>'15','11530'=>'289','14777'=>'290','14761'=>'291','14759'=>'292',
    '11355'=>'293','14778'=>'294','14780'=>'295','15407'=>'296','15439'=>'297','15441'=>'298',
    '14781'=>'299','14782'=>'300','15442'=>'301','15435'=>'302','15401'=>'303','14767'=>'304',
    '15408'=>'305','14784'=>'306','15436'=>'307','11454'=>'308','14768'=>'309','11503'=>'310',
    '15443'=>'311','15409'=>'312','14769'=>'313','15402'=>'314','15410'=>'315'
  }.freeze
  def collector_num
    return COLLECTOR_NUMS[@multiverse_id] if @multiverse_id.in?(COLLECTOR_NUMS)

    # Gatherer does some weird shit with the numbers for split cards. Calculate
    # the correct number using the order of the "(Fire // Ice)" name
    if split_card?
      available_numbers = @page.css('.row[id*="_numberRow"] .value').map{|div| div.text.strip}.sort
      return available_numbers[ split_card_name.split('/').index(@given_name) ]
    end
    value_of('number')
  end

  def illustrator
    # TODO: Fix for split cards with different illustrators
    case artist = value_of('artist')
    when 'Brian Snoddy'; 'Brian Snõddy'
    else; artist
    end
  end

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

  FLAVOR_TEXT = {
    '11212' => "\"Why do we trade with those despicable elves? You don't live in forests, you burn them!\" —Avram Garrisson,Leader of the Knights of Stromgald",
    '11303' => "\"O! it is excellent / To have a giant's strength, but it is tyrannous / To use it like a giant.\" —William Shakespeare,Measure for Measure",
    '11340' => "\"Some have said there is no subtlety to destruction. You know what? They're dead.\" —Jaya Ballard, task mage",
    '11476' => "\"I fear anything with teeth measured in handspans!\" —Norin the Wary",
    '14490' => "\"Hold your position! Leave doubt for the dying!\" —Tahngarth of the Weatherlight",
    '14538' => "\"Leviathan, too! Can you catch him with a fish-hook or run a line round his tongue?\" —The Bible, Job 41:1",
    '14604' => "\"But I signed nothing!\" —Taraneh, Suq'Ata mage",
    '14611' => "\"Hi! ni! ya! Behold the man of flint, that's me! / Four lightnings zigzag from me, strike and return.\" —Navajo war chant",
    '14618' => "\"From down here we can make the whole wall collapse!\"\"Uh, yeah, boss, but how do we get out?\"",
    '14648' => "\"If your blood doesn't run hot, I will make it run in the sands!\" —Maraxus of Keld",
    '14716' => "\"I tell you, there was so many arrows flying about you couldn't hardly see the sun. So I says to young Angus, ‘Well, at least now we're fighting in the shade!'\"",
    '15415' => "\"When you're a goblin, you don't have to step forward to be a hero—everyone else just has to step back!\" —Biggum Flodrot, goblin veteran",
    '15417' => "\"Next!\"",
    '15421' => "\"Goblins bred underground, their numbers hidden from the enemy until it was too late.\" —Sarpadian Empires, vol. IV",
    '15445' => "\"Ahh! Opposable digits!\"",
    '16441' => "\"The shamans? Ha! They are craven cows not capable of true magic.\" —Irini Sengir",
    '16629' => "\"Angels are simply extensions of truth upon the fabric of life—and there is far more dark than light.\" —Baron Sengir",
    '45187' => "\"Over the silver mountains, Where spring the nectar fountains, There will I kiss The bowl of bliss; And drink my everlasting fill. . . .\" —Sir Walter Raleigh, \"The Pilgrimage\"",
    '83121' => "\"The day of Spirits; my soul's calm retreat / Which none disturb!\" —Henry Vaughan, \"The Night\"",
    '83145' => "\"Catch!\"",
    '83167' => "\"Guess where I'm gonna plant this!\"",
    '83240' => "\"Over the silver mountains, Where spring the nectar fountains, There will I kiss The bowl of bliss; And drink my everlasting fill. . . .\" —Sir Walter Raleigh, \"The Pilgrimage\"",
    '83292' => "\"Rats, rats, rats! Hundreds, thousands, millions of them, and every one a life.\" —Bram Stoker, Dracula",
    '83446' => "\"Who's the crazy one now!?\" —Torgle, mountaintop boatmaker",
    '84552' => "\"The hour of your redemption is here. . . . Rally to me. . . . rise and strike. Strike at every favorable opportunity. For your homes and hearths, strike!\" —General Douglas MacArthur, to the people of the Philippines"
  }.freeze
  def flavor_text
    return FLAVOR_TEXT[@multiverse_id] if @multiverse_id.in?(FLAVOR_TEXT)
    value_of('flavor')#.gsub('"—', '" —').gsub('""', '" "')
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

  ICONS = {
    'White' => '{W}',
    'Blue' =>  '{U}',
    'Black' => '{B}',
    'Red' =>   '{R}',
    'Green' => '{G}',
    'White or Blue' =>  '{W/U}',
    'White or Black' => '{W/B}',
    'Blue or Black' =>  '{U/B}',
    'Blue or Red' =>    '{U/R}',
    'Black or Red' =>   '{B/R}',
    'Black or Green' => '{B/G}',
    'Red or White' =>   '{R/W}',
    'Red or Green' =>   '{R/G}',
    'Green or White' => '{G/W}',
    'Green or Blue' =>  '{G/U}',
    'Two or White' => '{2/W}',
    'Two or Blue' =>  '{2/U}',
    'Two or Black' => '{2/B}',
    'Two or Red' =>   '{2/R}',
    'Two or Green' => '{2/G}',
    'Phyrexian' =>       '{P}',
    'Phyrexian White' => '{WP}',
    'Phyrexian Blue' =>  '{UP}',
    'Phyrexian Black' => '{BP}',
    'Phyrexian Red' =>   '{RP}',
    'Phyrexian Green' => '{GP}',
    'Snow' =>  '{S}',
    'Tap' =>   '{T}',
    'Untap' => '{Q}',
    'Variable Colorless' => '{X}'
  }.freeze
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
    dumper = CardDumper.new(set)
    write dumper.output, merge(dumper.cards, dumper.output)
  end
end
