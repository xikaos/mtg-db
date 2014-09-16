CARDS_TO_SKIP = [
  '47784', '47787', '47785', '47786', '49056', '47788', '47789', # Eighth Edition Box Set
  '83064', '83319', '84073', '83104', '94912', '94911', '94910', '83075', '94914' # Ninth Edition Box Set
].freeze

COLLECTOR_NUMS = {
  # Classic Sixth Edition
  '15358'=>'14','14472'=>'15','11530'=>'289','14777'=>'290','14761'=>'291','14759'=>'292',
  '11355'=>'293','14778'=>'294','14780'=>'295','15407'=>'296','15439'=>'297','15441'=>'298',
  '14781'=>'299','14782'=>'300','15442'=>'301','15435'=>'302','15401'=>'303','14767'=>'304',
  '15408'=>'305','14784'=>'306','15436'=>'307','11454'=>'308','14768'=>'309','11503'=>'310',
  '15443'=>'311','15409'=>'312','14769'=>'313','15402'=>'314','15410'=>'315'
}.freeze

MANA_COST = {
  '74257' => 'W' # Unhinged's Little Girl
}.freeze

ORACLE_TEXT = {
  '74220' => ["Spells you play cost {½} less to play."],
  '74330' => ["Counter target spell unless its controller pays {3}{½}."],
  '74323' => ["{T}: Add {∞} to your mana pool.",
              "{100}: Add one mana of any color to your mana pool.",
              "You don't lose life due to mana burn."]
}.freeze

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
  '84552' => "\"The hour of your redemption is here. . . . Rally to me. . . . rise and strike. Strike at every favorable opportunity. For your homes and hearths, strike!\" —General Douglas MacArthur, to the people of the Philippines",
  '106473' => "\"Some goblins are expendable. Some are impossible to get rid of. But he's both—at the same time!\" —Starke",
  '129579' => "\"Boss told us to try and train 'em. Trained it to attack—it ate Flugg. Trained it to run fast—it got away. Success!\" —Dlig, goblin spelunker",
  '129596' => "\"Hmm . . . It looks kinda like a bug. Let's crack it open an' see if it tastes like one!\" —Squee, goblin cabin hand",
  '129620' => "\"Catch!\"",
  '129642' => "\"Guess where I'm gonna plant this!\"",
  '129908' => "\"Nature? Fire? Bah! Both are chaotic and difficult to control. Ice is structured, latticed, light as a feather, massive as a glacier. In ice, there is power!\" —Heidar, Rimewind master",
  '134748' => "\"I got it! I got it! I—\"",
  '135282' => "\"Let the forest spread! From salt, stone, and fen, let the new trees rise.\" —Molimo, maro-sorcerer"
}.freeze

POWER = {
  '74257' => '1/2' # Unhinged's Little Girl
}.freeze

TOUGHNESS = {
  '74257' => '1/2' # Unhinged's Little Girl
}.freeze

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
