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
    end
  end

end

if __FILE__==$0
  CardDumper.new( ARGV ).cards
end
