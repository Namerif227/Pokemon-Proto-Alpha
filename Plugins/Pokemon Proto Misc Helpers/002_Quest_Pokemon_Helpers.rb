#===============================================================================
# Pokemon Proto Quest Pokemon Helpers
#===============================================================================
# Lets you choose and remove a specific species from the player's party.
#
# Event examples:
#   pbTakeQuestPokemon(:ODDISH)
#   pbTakeQuestPokemon(:GEODUDE)
#===============================================================================

module PokemonProtoQuestPokemon
  CHOICE_VARIABLE = 31
  NAME_VARIABLE   = 32

  def self.species_list(species)
    return species if species.is_a?(Array)
    return [species]
  end

  def self.can_give_pokemon?(pkmn, species, allow_last = false)
    return false if !pkmn
    return false if pkmn.egg?
    return false if !$player
    return false if !$player.party
    return false if !allow_last && $player.party.length <= 1

    valid_species = self.species_list(species)
    return valid_species.include?(pkmn.species)
  end

  def self.choose_pokemon(species, choice_var = CHOICE_VARIABLE, name_var = NAME_VARIABLE, allow_last = false)
    # -1 means no Pokémon selected/canceled.
    $game_variables[choice_var] = -1
    $game_variables[name_var] = ""

    pbChoosePokemon(
      choice_var,
      name_var,
      proc { |pkmn|
        PokemonProtoQuestPokemon.can_give_pokemon?(pkmn, species, allow_last)
      }
    )
  end

  def self.take_pokemon(species, choice_var = CHOICE_VARIABLE, name_var = NAME_VARIABLE, allow_last = false)
    self.choose_pokemon(species, choice_var, name_var, allow_last)

    idx = $game_variables[choice_var].to_i

    # Cancel/no selection.
    return false if idx < 0

    # pbChoosePokemon uses the party index directly:
    # 0 = first Pokémon, 1 = second Pokémon, etc.
    pkmn = $player.party[idx]

    return false if !self.can_give_pokemon?(pkmn, species, allow_last)

    $game_variables[name_var] = pkmn.name
    $player.party.delete_at(idx)

    return true
  end
end

def pbChooseQuestPokemon(species, choice_var = 31, name_var = 32, allow_last = false)
  PokemonProtoQuestPokemon.choose_pokemon(species, choice_var, name_var, allow_last)
end

def pbTakeQuestPokemon(species, choice_var = 31, name_var = 32, allow_last = false)
  PokemonProtoQuestPokemon.take_pokemon(species, choice_var, name_var, allow_last)
end