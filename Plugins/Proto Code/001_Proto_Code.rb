#===============================================================================
# Proto Code v0.1.0
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Prototype mechanic:
# - Uses the existing Fight Menu special toggle slot for now.
# - If a Pokémon holds a Proto Capsule, the player can toggle Proto Code.
# - After choosing a move, the capsule is consumed.
# - The chosen move becomes the capsule's type until battle end or fainting.
#===============================================================================

module ProtoCode
  #-----------------------------------------------------------------------------
  # Item ID => Type ID
  #
  # These item IDs must match your PBS item IDs exactly.
  # Example PBS item ID: [FIREPROTOCAPSULE]
  # Ruby symbol:         :FIREPROTOCAPSULE
  #-----------------------------------------------------------------------------
  CAPSULE_TYPES = {
    :NORMALPROTOCAPSULE   => :NORMAL,
    :FIREPROTOCAPSULE     => :FIRE,
    :WATERPROTOCAPSULE    => :WATER,
    :ELECTRICPROTOCAPSULE => :ELECTRIC,
    :GRASSPROTOCAPSULE    => :GRASS,
    :ICEPROTOCAPSULE      => :ICE,
    :FIGHTINGPROTOCAPSULE => :FIGHTING,
    :POISONPROTOCAPSULE   => :POISON,
    :GROUNDPROTOCAPSULE   => :GROUND,
    :FLYINGPROTOCAPSULE   => :FLYING,
    :PSYCHICPROTOCAPSULE  => :PSYCHIC,
    :BUGPROTOCAPSULE      => :BUG,
    :ROCKPROTOCAPSULE     => :ROCK,
    :GHOSTPROTOCAPSULE    => :GHOST,
    :DRAGONPROTOCAPSULE   => :DRAGON,
    :DARKPROTOCAPSULE     => :DARK,
    :STEELPROTOCAPSULE    => :STEEL,
    :FAIRYPROTOCAPSULE    => :FAIRY
  }

  #-----------------------------------------------------------------------------
  # Returns the type linked to a Proto Capsule item.
  #-----------------------------------------------------------------------------
  def self.capsule_type(item_id)
    return nil if !item_id
    return CAPSULE_TYPES[item_id]
  end

#-----------------------------------------------------------------------------
# Proto Code cursor/icon graphics
#-----------------------------------------------------------------------------
# Default fallback graphic.
PROTO_CURSOR_GRAPHIC = "Graphics/UI/Battle/cursor_proto"

# Type-specific graphics.
# These files should be in Graphics/UI/Battle/
# Do not include .png in the path.
PROTO_CURSOR_GRAPHICS = {
  :NORMAL   => "Graphics/UI/Battle/cursor_proto_normal",
  :FIRE     => "Graphics/UI/Battle/cursor_proto_fire",
  :WATER    => "Graphics/UI/Battle/cursor_proto_water",
  :ELECTRIC => "Graphics/UI/Battle/cursor_proto_electric",
  :GRASS    => "Graphics/UI/Battle/cursor_proto_grass",
  :ICE      => "Graphics/UI/Battle/cursor_proto_ice",
  :FIGHTING => "Graphics/UI/Battle/cursor_proto_fighting",
  :POISON   => "Graphics/UI/Battle/cursor_proto_poison",
  :GROUND   => "Graphics/UI/Battle/cursor_proto_ground",
  :FLYING   => "Graphics/UI/Battle/cursor_proto_flying",
  :PSYCHIC  => "Graphics/UI/Battle/cursor_proto_psychic",
  :BUG      => "Graphics/UI/Battle/cursor_proto_bug",
  :ROCK     => "Graphics/UI/Battle/cursor_proto_rock",
  :GHOST    => "Graphics/UI/Battle/cursor_proto_ghost",
  :DRAGON   => "Graphics/UI/Battle/cursor_proto_dragon",
  :DARK     => "Graphics/UI/Battle/cursor_proto_dark",
  :STEEL    => "Graphics/UI/Battle/cursor_proto_steel",
  :FAIRY    => "Graphics/UI/Battle/cursor_proto_fairy"
}

def self.proto_cursor_graphic_for_item(item_id)
  proto_type = capsule_type(item_id)
  return PROTO_CURSOR_GRAPHIC if !proto_type
  return PROTO_CURSOR_GRAPHICS[proto_type] || PROTO_CURSOR_GRAPHIC
end

#-----------------------------------------------------------------------------
# Permanently consumes a Proto Capsule.
# This is stronger than normal pbConsumeItem because Proto Capsules should behave
# more like one-use battle items, not recoverable held items.
#-----------------------------------------------------------------------------
def self.consume_capsule_permanently(battle, battler, item_id)
  return if !battle || !battler || !item_id
  return if !capsule_type(item_id)

  pkmn = battler.pokemon

  # Save a reference so we can force-clear it again after battle cleanup.
  battle.instance_variable_set(:@protoCodeConsumedCapsules, []) if
    !battle.instance_variable_defined?(:@protoCodeConsumedCapsules)
  consumed = battle.instance_variable_get(:@protoCodeConsumedCapsules)
  consumed.push([pkmn, item_id]) if pkmn

  # Clear recovery-related battle item tracking.
  battler.setRecycleItem(nil) if battler.respond_to?(:setRecycleItem)
  battler.setInitialItem(nil) if battler.respond_to?(:setInitialItem)

  if battler.respond_to?(:effects) && battler.effects
    battler.effects[PBEffects::PickupItem] = nil if defined?(PBEffects::PickupItem)
    battler.effects[PBEffects::PickupUse]  = 0   if defined?(PBEffects::PickupUse)
  end

  # Consume without recovery, without Symbiosis, and without berry-related logic.
  if battler.respond_to?(:pbConsumeItem)
    battler.pbConsumeItem(false, false, false)
  else
    battler.item = nil
  end

  # Force the actual Pokémon object to lose the item too.
  force_remove_capsule_from_pokemon(pkmn, item_id)
end

#-----------------------------------------------------------------------------
# Directly removes the capsule from the Pokémon object.
#-----------------------------------------------------------------------------
def self.force_remove_capsule_from_pokemon(pkmn, item_id = nil)
  return if !pkmn

  current_item = nil
  current_item = pkmn.item_id if pkmn.respond_to?(:item_id)

  # Only clear if it is the same capsule, or if we can't read the current item.
  return if item_id && current_item && current_item != item_id

  if pkmn.respond_to?(:item=)
    pkmn.item = nil
  elsif pkmn.instance_variable_defined?(:@item_id)
    pkmn.instance_variable_set(:@item_id, nil)
  elsif pkmn.instance_variable_defined?(:@item)
    pkmn.instance_variable_set(:@item, nil)
  end
end

#-----------------------------------------------------------------------------
# Re-applies permanent removal after battle cleanup.
# This catches cases where Essentials restores held items at the end of battle.
#-----------------------------------------------------------------------------
def self.finalize_consumed_capsules(battle)
  return if !battle
  return if !battle.instance_variable_defined?(:@protoCodeConsumedCapsules)

  consumed = battle.instance_variable_get(:@protoCodeConsumedCapsules)
  return if !consumed

  consumed.each do |pkmn, item_id|
    force_remove_capsule_from_pokemon(pkmn, item_id)
  end

  battle.instance_variable_set(:@protoCodeConsumedCapsules, [])
end
  #-----------------------------------------------------------------------------
  # Stores Proto Code data on the Pokémon object.
  #
  # This lets the effect survive switching out and back in during the same battle.
  # It is cleared when the Pokémon faints or when the battle ends.
  #-----------------------------------------------------------------------------
  def self.apply_to_pokemon(pkmn, move_index, type, item_id)
    return if !pkmn
    pkmn.instance_variable_set(:@proto_code_active, true)
    pkmn.instance_variable_set(:@proto_code_move_index, move_index)
    pkmn.instance_variable_set(:@proto_code_type, type)
    pkmn.instance_variable_set(:@proto_code_item, item_id)
  end

  def self.clear_from_pokemon(pkmn)
    return if !pkmn
    pkmn.instance_variable_set(:@proto_code_active, false)
    pkmn.instance_variable_set(:@proto_code_move_index, -1)
    pkmn.instance_variable_set(:@proto_code_type, nil)
    pkmn.instance_variable_set(:@proto_code_item, nil)
  end

  def self.pokemon_fainted?(pkmn)
    return true if !pkn_safe?(pkmn)
    return pkmn.fainted? if pkmn.respond_to?(:fainted?)
    return pkmn.hp <= 0 if pkmn.respond_to?(:hp)
    return false
  end

  def self.pkn_safe?(pkmn)
    return !pkmn.nil?
  end

  def self.pokemon_active?(pkmn)
    return false if !pkmn
    return false if pokemon_fainted?(pkmn)
    return pkmn.instance_variable_get(:@proto_code_active) == true
  end

  #-----------------------------------------------------------------------------
  # Checks whether the passed Battle::Move is the move that was Proto-coded.
  #-----------------------------------------------------------------------------
  def self.active_type_for(battler, move)
    return nil if !battler || !move
    pkmn = battler.pokemon
    return nil if !pokemon_active?(pkmn)

    move_index = pkmn.instance_variable_get(:@proto_code_move_index)
    proto_type = pkmn.instance_variable_get(:@proto_code_type)

    return nil if move_index.nil? || move_index < 0
    return nil if !proto_type
    return nil if !GameData::Type.exists?(proto_type)
    return nil if !battler.moves[move_index]

    # Best case: same move object.
    return proto_type if battler.moves[move_index].equal?(move)

    # Fallback: same move ID. This helps if another plugin recreates move objects.
    return proto_type if battler.moves[move_index].id == move.id

    return nil
  end

  def self.each_battle_pokemon(battle)
    return if !battle
    2.times do |side|
      next if !battle.respond_to?(:pbParty)
      party = battle.pbParty(side)
      next if !party
      party.each do |pkmn|
        yield pkmn if pkmn
      end
    end
  end

  def self.clear_fainted_battle_pokemon(battle)
    each_battle_pokemon(battle) do |pkmn|
      clear_from_pokemon(pkmn) if pokemon_fainted?(pkmn)
    end
  end

  def self.reset_all_battle_pokemon(battle)
    each_battle_pokemon(battle) do |pkmn|
      clear_from_pokemon(pkmn)
    end
  end
end

#===============================================================================
# Battle hooks
#===============================================================================
class Battle
  #-----------------------------------------------------------------------------
  # Set up Proto Code registration storage.
  #-----------------------------------------------------------------------------
  alias proto_code_initialize initialize
  def initialize(*args)
    proto_code_initialize(*args)
    @protoCode = {}
  end

  #-----------------------------------------------------------------------------
  # Can this battler currently activate Proto Code?
  #-----------------------------------------------------------------------------
  def pbCanProtoCode?(idxBattler)
    battler = @battlers[idxBattler]
    return false if !battler
    return false if battler.fainted?
    return false if !battler.pokemon
    return false if ProtoCode.pokemon_active?(battler.pokemon)
    return false if pbRegisteredProtoCode?(idxBattler)

    item_id = battler.item_id
    proto_type = ProtoCode.capsule_type(item_id)
    return false if !proto_type
    return false if !GameData::Type.exists?(proto_type)

    # Prevent stacking Proto Code with already-registered Mega Evolution.
    if respond_to?(:proto_code_original_pbRegisteredMegaEvolution?)
      return false if proto_code_original_pbRegisteredMegaEvolution?(idxBattler)
    end

    return true
  end

  def pbRegisteredProtoCode?(idxBattler)
    @protoCode = {} if !@protoCode
    return @protoCode[idxBattler] == true
  end

  def pbToggleRegisteredProtoCode(idxBattler)
    @protoCode = {} if !@protoCode
    @protoCode[idxBattler] = !@protoCode[idxBattler]
  end

  def pbUnregisterProtoCode(idxBattler)
    @protoCode = {} if !@protoCode
    @protoCode.delete(idxBattler)
  end

  #-----------------------------------------------------------------------------
  # This makes the existing Fight Menu special button look "pressed" when Proto
  # Code is registered.
  #
  # Important:
  # This temporarily borrows the Mega button display state.
  # A later UI version should replace this with real Proto UI.
  #-----------------------------------------------------------------------------
  if method_defined?(:pbRegisteredMegaEvolution?) &&
     !method_defined?(:proto_code_original_pbRegisteredMegaEvolution?)
    alias proto_code_original_pbRegisteredMegaEvolution? pbRegisteredMegaEvolution?
  end

  def pbRegisteredMegaEvolution?(idxBattler)
    mega_registered = false
    if respond_to?(:proto_code_original_pbRegisteredMegaEvolution?)
      mega_registered = proto_code_original_pbRegisteredMegaEvolution?(idxBattler)
    end
    return true if mega_registered
    return true if pbRegisteredProtoCode?(idxBattler)
    return false
  end

  #-----------------------------------------------------------------------------
  # Clear pending Proto registration when a command is cancelled.
  #-----------------------------------------------------------------------------
  alias proto_code_pbCancelChoice pbCancelChoice
  def pbCancelChoice(idxBattler)
    proto_code_pbCancelChoice(idxBattler)
    pbUnregisterProtoCode(idxBattler)
  end

  #-----------------------------------------------------------------------------
  # Clear pending registrations at the start of each command phase.
  # Also clear Proto effects from fainted Pokémon.
  #-----------------------------------------------------------------------------
  alias proto_code_pbCommandPhase pbCommandPhase
  def pbCommandPhase
    @protoCode = {}
    ProtoCode.clear_fainted_battle_pokemon(self)
    proto_code_pbCommandPhase
  end

  #-----------------------------------------------------------------------------
  # After attacks resolve, clear Proto effects from fainted Pokémon.
  #-----------------------------------------------------------------------------
  alias proto_code_pbAttackPhase pbAttackPhase
  def pbAttackPhase
    ret = proto_code_pbAttackPhase
    ProtoCode.clear_fainted_battle_pokemon(self)
    return ret
  end

  #-----------------------------------------------------------------------------
  # Clear Proto effects when battle ends.
  #-----------------------------------------------------------------------------
alias proto_code_pbEndOfBattle pbEndOfBattle
def pbEndOfBattle
  ret = proto_code_pbEndOfBattle

  # Force permanent Proto Capsule loss after Essentials finishes battle cleanup.
  ProtoCode.finalize_consumed_capsules(self)

  # Clear temporary Proto move-type data.
  ProtoCode.reset_all_battle_pokemon(self)

  @protoCode = {}
  return ret
end

  #-----------------------------------------------------------------------------
  # Activates Proto Code after the player selects a move.
  #-----------------------------------------------------------------------------
  def pbActivateProtoCode(idxBattler, idxMove)
    battler = @battlers[idxBattler]
    return false if !battler
    return false if battler.fainted?
    return false if !battler.pokemon
    return false if !battler.moves[idxMove]

    item_id = battler.item_id
    proto_type = ProtoCode.capsule_type(item_id)
    return false if !proto_type
    return false if !GameData::Type.exists?(proto_type)

    item_name = GameData::Item.get(item_id).name
    type_name = GameData::Type.get(proto_type).name
    move_name = battler.moves[idxMove].name

    ProtoCode.apply_to_pokemon(battler.pokemon, idxMove, proto_type, item_id)

    pbDisplay(_INTL("{1}'s {2} activated!", battler.pbThis, item_name))
    pbDisplay(_INTL("{1}'s {2} became {3}-type!", battler.pbThis, move_name, type_name))

  # Permanently consume the held Proto Capsule.
  ProtoCode.consume_capsule_permanently(self, battler, item_id)

    pbUnregisterProtoCode(idxBattler)
    return true
  end

  #-----------------------------------------------------------------------------
  # Replaces the vanilla player Fight Menu command flow so Proto Code can use the
  # existing special toggle command.
  #
  # This is based on Essentials v21.1's Battle#pbFightMenu structure.
  #-----------------------------------------------------------------------------
  alias proto_code_original_pbFightMenu pbFightMenu
  def pbFightMenu(idxBattler)
    return pbAutoChooseMove(idxBattler) if !pbCanShowFightMenu?(idxBattler)
    return true if pbAutoFightMenu(idxBattler)

    ret = false
    mega_possible  = pbCanMegaEvolve?(idxBattler)
    proto_possible = pbCanProtoCode?(idxBattler)
    special_possible = mega_possible || proto_possible

# Tell the Fight Menu which special-button graphic to use.
# Proto takes priority here, matching the toggle logic below.
proto_item_id = nil
proto_item_id = @battlers[idxBattler].item_id if @battlers[idxBattler]

@scene.pbSetProtoCodeButton(
  proto_possible || pbRegisteredProtoCode?(idxBattler),
  proto_item_id
)

@scene.pbFightMenu(idxBattler, special_possible) do |cmd|
      case cmd
      when -1   # Cancel
        pbUnregisterProtoCode(idxBattler)

      when -2   # Special toggle button
        # If your game does not use Mega Evolution, Proto Code will own this slot.
        if proto_possible && !mega_possible
          pbToggleRegisteredProtoCode(idxBattler)
        elsif mega_possible && !proto_possible
          pbToggleRegisteredMegaEvolution(idxBattler)
        elsif proto_possible && mega_possible
          # For now, Proto Code takes priority if both are possible.
          # You can change this later if your game allows both mechanics.
          pbToggleRegisteredProtoCode(idxBattler)
        end
        next false

      when -3   # Shift
        pbUnregisterProtoCode(idxBattler)
        pbUnregisterMegaEvolution(idxBattler) if respond_to?(:pbUnregisterMegaEvolution)
        pbRegisterShift(idxBattler)
        ret = true

      else      # Move selected
        next false if cmd < 0
        next false if !@battlers[idxBattler].moves[cmd]
        next false if !pbRegisterMove(idxBattler, cmd)

        if !singleBattle?
          next false if !pbChooseTarget(@battlers[idxBattler], @battlers[idxBattler].moves[cmd])
        end

        if pbRegisteredProtoCode?(idxBattler)
          pbActivateProtoCode(idxBattler, cmd)
        end

        ret = true
      end
      next true
    end

    return ret
  end
end

#===============================================================================
# Move type hooks
#===============================================================================
class Battle::Move
  #===============================================================================
# Proto Code Fight Menu cursor
#-------------------------------------------------------------------------------
# Loads cursor_proto.png separately instead of globally replacing cursor_mega.
#
# cursor_proto.png must contain two vertically stacked frames:
#   Top half    = available/unpressed
#   Bottom half = selected/pressed
#===============================================================================

class Battle::Scene::FightMenu
  unless method_defined?(:proto_code_cursor_initialize)
    alias proto_code_cursor_initialize initialize
  end

  def initialize(viewport, z)
    proto_code_cursor_initialize(viewport, z)

  @protoCodeBitmap     = nil
  @protoCodeBitmapPath = nil
  @protoCodeButton     = false

  set_proto_code_bitmap_from_item(nil)
  end

  unless method_defined?(:proto_code_cursor_dispose)
    alias proto_code_cursor_dispose dispose
  end

  def set_proto_code_bitmap_from_item(item_id)
  proto_path = ProtoCode.proto_cursor_graphic_for_item(item_id)

  # Fall back to the default Proto graphic if the type-specific one is missing.
  proto_path = ProtoCode::PROTO_CURSOR_GRAPHIC if !pbResolveBitmap(proto_path)

  # Fall back to the Mega graphic instead of crashing if no Proto graphic exists.
  proto_path = "Graphics/UI/Battle/cursor_mega" if !pbResolveBitmap(proto_path)

  return if @protoCodeBitmapPath == proto_path

  @protoCodeBitmap.dispose if @protoCodeBitmap
  @protoCodeBitmap = AnimatedBitmap.new(proto_path)
  @protoCodeBitmapPath = proto_path
end

def set_proto_code_button(value, item_id = nil)
  value = !!value

  set_proto_code_bitmap_from_item(item_id) if value

  changed = (@protoCodeButton != value)
  @protoCodeButton = value

  refreshMegaEvolutionButton if changed || value
end

def proto_code_button=(value)
  set_proto_code_button(value, nil)
end

  def dispose
    @protoCodeBitmap&.dispose
    @protoCodeBitmap = nil
    proto_code_cursor_dispose
  end

  #---------------------------------------------------------------------------
  # Changes whether the special button uses the Proto or Mega graphic.
  #---------------------------------------------------------------------------
  def proto_code_button=(value)
    value = !!value
    return if @protoCodeButton == value

    @protoCodeButton = value
    refreshMegaEvolutionButton
  end

  #---------------------------------------------------------------------------
  # Replaces only the special button's refresh logic.
  #---------------------------------------------------------------------------
  def refreshMegaEvolutionButton
    return if !Battle::Scene::FightMenu::USE_GRAPHICS
    return if !@megaButton

    special_bitmap = if @protoCodeButton && @protoCodeBitmap
                       @protoCodeBitmap
                     else
                       @megaEvoBitmap
                     end

    return if !special_bitmap

    @megaButton.bitmap = special_bitmap.bitmap

    # Both cursor images contain two vertically stacked states.
    button_height = special_bitmap.height / 2
    frame = (@mode == 2) ? 1 : 0

    @megaButton.src_rect.x      = 0
    @megaButton.src_rect.y      = frame * button_height
    @megaButton.src_rect.width  = special_bitmap.width
    @megaButton.src_rect.height = button_height

    @megaButton.x = self.x + ((@shiftMode > 0) ? 204 : 120)
    @megaButton.y = self.y - button_height
    @megaButton.z = self.z - 1

    @visibility["megaButton"] = (@mode > 0)
  end
end

#===============================================================================
# Battle scene helper
#===============================================================================
class Battle::Scene
  def pbSetProtoCodeButton(value, item_id = nil)
    fight_window = @sprites["fightWindow"]
    return if !fight_window

    if fight_window.respond_to?(:set_proto_code_button)
      fight_window.set_proto_code_button(value, item_id)
    elsif fight_window.respond_to?(:proto_code_button=)
      fight_window.proto_code_button = value
    end
  end
end
  #-----------------------------------------------------------------------------
  # Fight Menu display type.
  #-----------------------------------------------------------------------------
  if method_defined?(:display_type) && !method_defined?(:proto_code_display_type)
    alias proto_code_display_type display_type
  end

  def display_type(battler)
    proto_type = ProtoCode.active_type_for(battler, self)
    return proto_type if proto_type
    return proto_code_display_type(battler)
  end

  #-----------------------------------------------------------------------------
  # Actual battle calculation type.
  #-----------------------------------------------------------------------------
  if method_defined?(:pbCalcType) && !method_defined?(:proto_code_pbCalcType)
    alias proto_code_pbCalcType pbCalcType
  end

  def pbCalcType(user)
    ret = proto_code_pbCalcType(user)
    proto_type = ProtoCode.active_type_for(user, self)
    return ret if !proto_type

    # Prevents type-changing effects from treating this as a power boost.
    @powerBoost = false
    return proto_type
  end
end