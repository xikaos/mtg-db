require 'multi_json'
require_relative './script_util.rb'

send def run(*set_codes)
  sets_to_include = read('data/gatherer/sets.json').select{|s| s['code'].in? set_codes}

  mgci_cards = read('data/mgci/cards_mod.json')
    .select{|c| sets_to_include.any?{|s| s['name']==c['set_name']}}
    .map{|c| c.merge('sort_key' => [c['set_name'], c['collector_num'].to_i, c['collector_num']])}
    .sort_by{|c| c['sort_key']}
    .map{|c| c.except('sort_key', 'flavor_text')}

  gath_cards = sets_to_include.inject([]){|cards,set| cards+read("data/gatherer/sets/#{set['code']}.json")}
    .map{|c| c.merge('sort_key' => [c['set_name'], c['collector_num'].to_i, c['collector_num']])}
    .sort_by{|c| c['sort_key']}
    .map{|c| c.except('sort_key', 'flavor_text')}

  puts "Found #{mgci_cards.count} MGCI cards."
  puts "Found #{gath_cards.count} GATH cards."
  if mgci_cards.count > 0 && mgci_cards.count == gath_cards.count
    codes = sets_to_include.map{|s| s['code']}.join('.')
    write("compare/sorted-mgci-#{codes}.json", mgci_cards)
    write("compare/sorted-gath-#{codes}.json", gath_cards)
  end
end, *ARGV
