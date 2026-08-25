#===============================================================================
# Pokemon Proto Pokedex Quest Helpers
#===============================================================================

def pbProtoOwnedSpeciesCount
  return 0 if !$player
  return 0 if !$player.pokedex

  dex = $player.pokedex

  # Essentials usually supports this.
  return dex.owned_count if dex.respond_to?(:owned_count)

  # Backup method if owned_count is not available.
  count = 0
  checked_species = {}

  GameData::Species.each do |species_data|
    species = species_data.respond_to?(:species) ? species_data.species : species_data.id
    next if checked_species[species]
    checked_species[species] = true

    if dex.respond_to?(:owned?)
      count += 1 if dex.owned?(species)
    elsif dex.respond_to?(:caught?)
      count += 1 if dex.caught?(species)
    end
  end

  return count
end