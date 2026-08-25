#===============================================================================
# Pokémon Proto Misc Helpers
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# A collection of small reusable event helper methods for Pokémon Proto.
#===============================================================================

module PokemonProtoMisc
  #-----------------------------------------------------------------------------
  # Vending Machine
  #-----------------------------------------------------------------------------
  def self.vending_machine(items)
    valid_items = []

    items.each do |item_data|
      item_id = item_data[0]
      price   = item_data[1]

      next if !GameData::Item.exists?(item_id)
      valid_items.push([item_id, price])
    end

    if valid_items.empty?
      pbMessage(_INTL("The vending machine is empty."))
      return
    end

    loop do
      commands = []

      valid_items.each do |item_data|
        item_id = item_data[0]
        price   = item_data[1]

        item_name = GameData::Item.get(item_id).name
        commands.push(_INTL("{1} - ${2}", item_name, price))
      end

      commands.push(_INTL("Cancel"))

      choice = pbMessage(
        _INTL("It's a vending machine!\nWhat would you like to buy?"),
        commands,
        commands.length
      )

      break if choice < 0
      break if choice >= valid_items.length

      item_id = valid_items[choice][0]
      price   = valid_items[choice][1]
      item_name = GameData::Item.get(item_id).name

      if $player.money < price
        pbMessage(_INTL("You don't have enough money."))
        next
      end

      if !$bag.add(item_id, 1)
        pbMessage(_INTL("Your Bag is full."))
        next
      end

      $player.money -= price
      pbSEPlay("Mart buy item") rescue nil

      pbMessage(_INTL("Clang!\n{1} popped out of the vending machine!", item_name))
    end
  end
end

#===============================================================================
# Event shortcut
#-------------------------------------------------------------------------------
# This makes pbProtoVendingMachine usable directly inside RPG Maker XP event
# Script commands.
#===============================================================================
class Interpreter
  def pbProtoVendingMachine(items)
    PokemonProtoMisc.vending_machine(items)
  end
end

#===============================================================================
# Skulius Starter Machine
#-------------------------------------------------------------------------------
# Lets the player replace the first Pokémon in their party with a starter.
# Organized by generation, plus a Proto Pokémon category.
#===============================================================================

module PokemonProtoMisc
  STARTER_CHOICE_VARIABLE = 27

  STARTER_MACHINE_GROUPS = [
    ["Gen 1", [
      ["Bulbasaur",  :BULBASAUR,  0],
      ["Charmander", :CHARMANDER, 0],
      ["Squirtle",   :SQUIRTLE,   0]
    ]],

    ["Gen 2", [
      ["Chikorita", :CHIKORITA, 0],
      ["Cyndaquil", :CYNDAQUIL, 0],
      ["Totodile",  :TOTODILE,  0]
    ]],

    ["Gen 3", [
      ["Treecko",  :TREECKO,  0],
      ["Torchic",  :TORCHIC,  0],
      ["Mudkip",   :MUDKIP,   0]
    ]],

    ["Gen 4", [
      ["Turtwig",  :TURTWIG,  0],
      ["Chimchar", :CHIMCHAR, 0],
      ["Piplup",   :PIPLUP,   0]
    ]],

    ["Gen 5", [
      ["Snivy",    :SNIVY,    0],
      ["Tepig",    :TEPIG,    0],
      ["Oshawott", :OSHAWOTT, 0]
    ]],

    ["Gen 6", [
      ["Chespin",  :CHESPIN,  0],
      ["Fennekin", :FENNEKIN, 0],
      ["Froakie",  :FROAKIE,  0]
    ]],

    ["Gen 7", [
      ["Rowlet",  :ROWLET,  0],
      ["Litten",  :LITTEN,  0],
      ["Popplio", :POPPLIO, 0]
    ]],

    ["Gen 8", [
      ["Grookey",  :GROOKEY,  0],
      ["Scorbunny",:SCORBUNNY,0],
      ["Sobble",   :SOBBLE,   0]
    ]],

    ["Gen 9", [
      ["Sprigatito", :SPRIGATITO, 0],
      ["Fuecoco",    :FUECOCO,    0],
      ["Quaxly",     :QUAXLY,     0]
    ]],

    ["Proto Pokémon", [
      # These assume your Proto starters are forms.
      # Change the form number if your PBS uses a different form.
      ["Proto Snivy",    :SNIVY,    1],
      ["Proto Tepig",    :TEPIG,    1],
      ["Proto Oshawott", :OSHAWOTT, 1]

      # If a Proto Pokémon is its own species instead of a form, use form 0:
      # ["Proto Example", :PROTOEXAMPLE, 0]
    ]]
  ]

  def self.confirm_starter_with_preview(species, form, display_name, old_name)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999

    sprite = PokemonSprite.new(viewport)

    preview_pokemon = Pokemon.new(species, 5)
    preview_pokemon.form = form if form && form > 0
    preview_pokemon.calc_stats

    sprite.setPokemonBitmap(preview_pokemon)
    sprite.x = Graphics.width / 2
    sprite.y = 130
    sprite.z = 99999

    if sprite.bitmap
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height / 2
    end

    begin
      GameData::Species.play_cry_from_species(species, form)
    rescue
      GameData::Species.play_cry_from_species(species) rescue nil
    end

    result = pbConfirmMessage(_INTL("Switch {1} for {2}?", old_name, display_name))

    sprite.dispose
    viewport.dispose

    return result
  end

  def self.starter_machine
    if !$player || $player.party.length == 0
      pbMessage(_INTL("The machine needs to scan your current Pokémon first."))
      return false
    end

    loop do
      group_commands = STARTER_MACHINE_GROUPS.map { |group| group[0] }
      group_commands.push(_INTL("Cancel"))

      group_choice = pbMessage(
        _INTL("Select a starter category."),
        group_commands,
        group_commands.length - 1
      )

      return false if group_choice < 0
      return false if group_choice >= STARTER_MACHINE_GROUPS.length

      group_name = STARTER_MACHINE_GROUPS[group_choice][0]
      starters   = STARTER_MACHINE_GROUPS[group_choice][1]

      valid_starters = starters.select { |starter|
        GameData::Species.exists?(starter[1])
      }

      if valid_starters.empty?
        pbMessage(_INTL("No valid Pokémon were found in that category."))
        next
      end

      starter_commands = valid_starters.map { |starter| starter[0] }
      starter_commands.push(_INTL("Back"))

      starter_choice = pbMessage(
        _INTL("Select a Pokémon from {1}.", group_name),
        starter_commands,
        starter_commands.length - 1
      )

      next if starter_choice < 0
      next if starter_choice >= valid_starters.length

      display_name = valid_starters[starter_choice][0]
      species      = valid_starters[starter_choice][1]
      form         = valid_starters[starter_choice][2] || 0

    old_pokemon = $player.party[0]
    old_name    = old_pokemon.name
    level       = old_pokemon.level

   if !PokemonProtoMisc.confirm_starter_with_preview(species, form, display_name, old_name)
    next
  end

      old_pokemon = $player.party[0]
      old_name    = old_pokemon.name
      level       = old_pokemon.level

      if !pbConfirmMessage(_INTL("Switch {1} for {2}?", old_name, display_name))
        next
      end

      kept_original = (old_pokemon.species == species && old_pokemon.form == form)

      new_pokemon = Pokemon.new(species, level)
      new_pokemon.form = form if form > 0
      new_pokemon.calc_stats
      new_pokemon.heal

      $player.party[0] = new_pokemon

      if kept_original
        $game_variables[PokemonProtoMisc::STARTER_CHOICE_VARIABLE] = 1
     else
        $game_variables[PokemonProtoMisc::STARTER_CHOICE_VARIABLE] = 2
     end

     pbMessage(_INTL("{1} was switched for {2}!", old_name, display_name))
     return true
    end
  end
end

class Interpreter
  def pbSkuliusStarterMachine
    return PokemonProtoMisc.starter_machine
  end

  def pbRattataIntroBattle(partner_type, partner_name)
    rattata1 = Pokemon.new(:RATTATA, 4)
    rattata1.moves = [
      Pokemon::Move.new(:TACKLE),
      Pokemon::Move.new(:TAILWHIP)
    ]

    rattata2 = Pokemon.new(:RATTATA, 4)
    rattata2.moves = [
      Pokemon::Move.new(:TACKLE),
      Pokemon::Move.new(:TAILWHIP)
    ]

    pbRegisterPartner(partner_type, partner_name)
    setBattleRule("canLose")
    setBattleRule("double")
    result = WildBattle.start(rattata1, rattata2)
    pbDeregisterPartner

    return result
  end
end
#===============================================================================
# Pokemon Proto Badge-Based Level Cap
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Controls the player's level cap based on badge count.
# If the cap is 10, player Pokémon can reach Lv. 10, but cannot reach Lv. 11.
#===============================================================================

module PokemonProtoLevelCap
  # Badge count => level cap
  # Example: 0 badges = Lv. 10 cap, 1 badge = Lv. 18 cap, etc.
  BADGE_LEVEL_CAPS = [
    15,    # 0 badges
    20,    # 1 badge
    25,    # 2 badges
    30,    # 3 badges
    35,    # 4 badges
    40,    # 5 badges
    45,    # 6 badges
    55,    # 7 badges
    60,    # 8 badges
    65,    # 9 badges
    75,    # 10 badges
    80,    # 11 badges
    85,    # 12 badges
    95,    # 13 badges
    100    # 14 badges
  ]

  def self.max_level
    return Settings::MAXIMUM_LEVEL if defined?(Settings::MAXIMUM_LEVEL)
    return 100
  end

  def self.badge_count
    return 0 if !$player
    return $player.badge_count if $player.respond_to?(:badge_count)
    return $player.badges.count { |badge| badge } if $player.respond_to?(:badges)
    return 0
  end

  def self.current_cap
    badges = self.badge_count
    badges = [[badges, 0].max, BADGE_LEVEL_CAPS.length - 1].min
    cap = BADGE_LEVEL_CAPS[badges]
    cap = [[cap, 1].max, self.max_level].min
    return cap
  end

  def self.should_cap?(pkmn)
    return false if !pkmn
    return false if !$player
    return false if !$player.party

    # Important:
    # Do this check BEFORE checking pkmn.egg?
    # Newly created Pokémon are not fully initialized yet and are not in the party.
    return false if !$player.party.any? { |party_pkmn| party_pkmn.equal?(pkmn) }

    begin
      return false if pkmn.egg?
    rescue
      return false
    end

    return true
  end

  def self.exp_for_level(pkmn, level)
    growth_rate = GameData::GrowthRate.get(pkmn.growth_rate)
    return growth_rate.minimum_exp_for_level(level)
  end

  def self.max_exp_for_cap(pkmn)
    cap = self.current_cap
    return self.exp_for_level(pkmn, self.max_level) if cap >= self.max_level
    return self.exp_for_level(pkmn, cap + 1) - 1
  end

  def self.clamp_exp_value(pkmn, value)
    return value if !self.should_cap?(pkmn)
    return [value, self.max_exp_for_cap(pkmn)].min
  end

  def self.clamp_level_value(pkmn, value)
    return value if !self.should_cap?(pkmn)
    return [value, self.current_cap].min
  end

  def self.apply_to_pokemon(pkmn)
    return if !self.should_cap?(pkmn)
    pkmn.exp = self.max_exp_for_cap(pkmn) if pkmn.level > self.current_cap
    pkmn.calc_stats
    pkmn.hp = [pkmn.hp, pkmn.totalhp].min
  end

  def self.apply_to_party
    return if !$player
    return if !$player.party
    $player.party.each { |pkmn| self.apply_to_pokemon(pkmn) }
  end
end

class Pokemon
  if !method_defined?(:proto_level_cap_old_exp_set)
    alias_method :proto_level_cap_old_exp_set, :exp=
  end

  if !method_defined?(:proto_level_cap_old_level_set)
    alias_method :proto_level_cap_old_level_set, :level=
  end

  def exp=(value)
    value = PokemonProtoLevelCap.clamp_exp_value(self, value)
    proto_level_cap_old_exp_set(value)
  end

  def level=(value)
    value = PokemonProtoLevelCap.clamp_level_value(self, value)
    proto_level_cap_old_level_set(value)
  end
end
