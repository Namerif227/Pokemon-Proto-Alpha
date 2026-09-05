#===============================================================================
# Proto Code NPC AI v0.1.0
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Requires the main Proto Code script to be loaded first.
#
# This file lets opposing trainers use Proto Capsules automatically.
#
# AI Levels:
#   0 = Never uses Proto Code
#   1 = Noob AI
#       - Uses Proto Code as soon as possible
#       - Can waste it on status moves like Tail Whip
#       - Will not use it if the move is already the capsule's type
#
#   2 = Competent AI
#       - Only uses Proto Code on damaging moves
#       - Only uses it if the capsule type is super effective
#       - Avoids obvious waste moves like Tail Whip/Growl/Leer
#
#   3 = Expert AI
#       - Can hold the capsule instead of using it immediately
#       - Prefers strong damaging moves that become super effective
#       - Can be allowed to use special status-move tricks
#
# Important:
# This version makes the NPC decide whether to activate Proto Code on the move
# it has already chosen. It does not yet teach Essentials' battle AI to choose
# moves with Proto Code in mind. That can be added later.
#===============================================================================

module ProtoCode
  #-----------------------------------------------------------------------------
  # Default NPC Proto Code level.
  #
  # 0 = no trainers use Proto Code unless listed below.
  # 1 = every opposing trainer with a Proto Capsule can use it like a noob.
  #-----------------------------------------------------------------------------
  NPC_DEFAULT_AI_LEVEL = 0

  #-----------------------------------------------------------------------------
  # Wild Pokémon with Proto Capsules.
  # Usually keep this at 0 unless you want wild Pokémon to use Proto Code.
  #-----------------------------------------------------------------------------
  WILD_NPC_AI_LEVEL = 0

  #-----------------------------------------------------------------------------
  # Trainer type based AI levels.
  #
  # Add your trainer types here.
  # These names must match PBS/trainer_types.txt symbols.
  #-----------------------------------------------------------------------------
  TRAINER_TYPE_AI_LEVELS = {
    :YOUNGSTER           => 1,
    :LASS                => 1,
    :BUGCATCHER          => 1,
    :AROMALADY           => 1,
    :ROCKER              => 1,
    :RATBOSS             => 1,

    :YELLOWJACKETGRUNT   => 2,
    :YELLOWJACKETADMIN   => 2,
    :POKEMONRANGER_F     => 2,
    :POKEMONRANGER_M     => 2,

    :ETHAN               => 2,
    :KRISTEN             => 2,

    :BIX                 => 2,
    :CALIX               => 3
  }

  #-----------------------------------------------------------------------------
  # Specific trainer name overrides.
  #
  # Format:
  #   [:TRAINERTYPE, "Trainer Name"] => level
  #
  # This is useful if one trainer of a type should be smarter than others.
  #-----------------------------------------------------------------------------
  TRAINER_NAME_AI_LEVELS = {
    [:BIX,   "Bix"]   => 2,
    [:CALIX, "Calix"] => 3
  }

  #-----------------------------------------------------------------------------
  # Level 3 status move tricks.
  #
  # These moves are allowed for expert AI even if they are not damaging moves.
  #
  # Note:
  # Changing a status move's type does not automatically make every possible
  # "type trick" work. This only tells the AI it is allowed to try these moves.
  # Any special behavior still depends on how the move itself is coded.
  #-----------------------------------------------------------------------------
  LEVEL3_STATUS_TRICK_MOVES = [
    :DESTINYBOND
  ]

  #-----------------------------------------------------------------------------
  # One-battle override.
  #
  # Use before a trainer battle if you want to force that battle's Proto AI level:
  #
  #   ProtoCode.set_next_npc_ai_level(3)
  #   TrainerBattle.start(:BIX, "Bix")
  #-----------------------------------------------------------------------------
  @next_npc_ai_level = nil

  def self.set_next_npc_ai_level(level)
    @next_npc_ai_level = clamp_npc_ai_level(level)
  end

  def self.consume_next_npc_ai_level
    level = @next_npc_ai_level
    @next_npc_ai_level = nil
    return level
  end

  def self.clamp_npc_ai_level(level)
    level = level.to_i
    level = 0 if level < 0
    level = 3 if level > 3
    return level
  end

  #-----------------------------------------------------------------------------
  # Main entry point.
  # Called before the attack phase starts.
  #-----------------------------------------------------------------------------
  def self.try_npc_proto_code_for_all(battle)
    return if !battle
    battlers = get_battlers(battle)
    return if !battlers

    battlers.each_with_index do |battler, idxBattler|
      next if !battler
      next if battler.fainted?
      next if !npc_proto_side?(idxBattler)

      try_npc_proto_code_for_battler(battle, idxBattler)
    end
  end

  #-----------------------------------------------------------------------------
  # For now, NPC Proto Code only applies to the opposing side.
  # Essentials battle indexes are usually:
  #   0, 2 = player side
  #   1, 3 = opposing side
  #-----------------------------------------------------------------------------
  def self.npc_proto_side?(idxBattler)
    return idxBattler.odd?
  end

  def self.try_npc_proto_code_for_battler(battle, idxBattler)
    return false if !battle.respond_to?(:pbCanProtoCode?)
    return false if !battle.pbCanProtoCode?(idxBattler)

    battler = get_battler(battle, idxBattler)
    return false if !battler
    return false if !battler.pokemon

    ai_level = npc_ai_level_for_battler(battle, idxBattler)
    return false if ai_level <= 0

    idxMove = selected_move_index(battle, idxBattler)
    return false if idxMove.nil?
    return false if !battler.moves[idxMove]

    move = battler.moves[idxMove]
    item_id = battler.item_id
    proto_type = capsule_type(item_id)
    return false if !proto_type

    original_type = move_type(move, battler)

    # Even noob AI knows not to waste a capsule on a move that is already
    # the capsule's type.
    return false if original_type == proto_type

    use_proto = false
    case ai_level
    when 1
      use_proto = level_1_should_use?(battle, battler, move, idxMove, proto_type)
    when 2
      use_proto = level_2_should_use?(battle, battler, move, idxMove, proto_type)
    when 3
      use_proto = level_3_should_use?(battle, battler, move, idxMove, proto_type)
    end

    return false if !use_proto

    battle.pbActivateProtoCode(idxBattler, idxMove)
    return true
  end

  #-----------------------------------------------------------------------------
  # Level 1:
  # Use immediately on almost anything.
  #-----------------------------------------------------------------------------
  def self.level_1_should_use?(_battle, _battler, _move, _idxMove, _proto_type)
    return true
  end

  #-----------------------------------------------------------------------------
  # Level 2:
  # Only damaging moves, and only if the Proto type is super effective.
  #-----------------------------------------------------------------------------
  def self.level_2_should_use?(battle, battler, move, idxMove, proto_type)
    return false if !damaging_move?(move)

    targets = selected_targets(battle, battler, idxMove)
    return false if targets.empty?

    targets.each do |target|
      next if !target
      next if target.fainted?
      return true if type_super_effective?(proto_type, target)
    end

    return false
  end

  #-----------------------------------------------------------------------------
  # Level 3:
  # Smarter and more patient.
  #-----------------------------------------------------------------------------
  def self.level_3_should_use?(battle, battler, move, idxMove, proto_type)
    targets = selected_targets(battle, battler, idxMove)

    # Allow special expert-only status tricks.
    if status_trick_move?(move)
      return level_3_status_trick_good?(battle, battler, move, proto_type, targets)
    end

    return false if !damaging_move?(move)
    return false if targets.empty?

    original_type = move_type(move, battler)
    power = move_power(move)

    best_target = nil
    best_gain = 0

    targets.each do |target|
      next if !target
      next if target.fainted?

      original_score = type_effectiveness_score(original_type, target)
      proto_score    = type_effectiveness_score(proto_type, target)
      gain = proto_score - original_score

      if gain > best_gain
        best_gain = gain
        best_target = target
      end
    end

    return false if !best_target
    return false if best_gain <= 0
    return false if !type_super_effective?(proto_type, best_target)

    # If the move is strong, expert AI will usually take the opportunity.
    return true if power >= 70

    # If the battler is getting low on HP, stop waiting and use it.
    if battler.respond_to?(:hp) && battler.respond_to?(:totalhp)
      return true if battler.hp <= battler.totalhp / 2
    end

    # Otherwise, expert AI may hold the capsule for later.
    return random_chance(battle, 55)
  end

  #-----------------------------------------------------------------------------
  # Status move trick behavior.
  #-----------------------------------------------------------------------------
  def self.status_trick_move?(move)
    return false if !move
    return false if !move.respond_to?(:id)
    return LEVEL3_STATUS_TRICK_MOVES.include?(move.id)
  end

  def self.level_3_status_trick_good?(battle, battler, move, proto_type, targets)
    original_type = move_type(move, battler)
    return false if original_type == proto_type

    # If the original type would be ineffective against a target, but the Proto
    # type would not be, expert AI may try the trick.
    targets.each do |target|
      next if !target
      next if target.fainted?

      original_bad = type_ineffective?(original_type, target)
      proto_bad    = type_ineffective?(proto_type, target)

      return true if original_bad && !proto_bad
    end

    # Small chance to use an allowed trick anyway.
    return random_chance(battle, 25)
  end

  #-----------------------------------------------------------------------------
  # Get the trainer's AI level.
  #-----------------------------------------------------------------------------
  def self.npc_ai_level_for_battler(battle, idxBattler)
    override = nil
    override = battle.instance_variable_get(:@protoCodeNPCAILevelOverride) if
      battle.instance_variable_defined?(:@protoCodeNPCAILevelOverride)

    return clamp_npc_ai_level(override) if !override.nil?

    trainer = trainer_for_battler(battle, idxBattler)

    # Wild Pokémon or unknown owner.
    return WILD_NPC_AI_LEVEL if !trainer

    trainer_type = nil
    trainer_name = nil

    trainer_type = trainer.trainer_type if trainer.respond_to?(:trainer_type)
    trainer_name = trainer.name if trainer.respond_to?(:name)

    trainer_type = normalize_symbol(trainer_type)

    if trainer_type && trainer_name
      key = [trainer_type, trainer_name]
      return clamp_npc_ai_level(TRAINER_NAME_AI_LEVELS[key]) if
        TRAINER_NAME_AI_LEVELS.key?(key)
    end

    if trainer_type && TRAINER_TYPE_AI_LEVELS.key?(trainer_type)
      return clamp_npc_ai_level(TRAINER_TYPE_AI_LEVELS[trainer_type])
    end

    return clamp_npc_ai_level(NPC_DEFAULT_AI_LEVEL)
  end

  def self.trainer_for_battler(battle, idxBattler)
    return nil if !battle

    owner_index = 0
    begin
      owner_index = battle.pbGetOwnerIndexFromBattlerIndex(idxBattler)
    rescue
      owner_index = 0
    end

    opponent = nil
    opponent = battle.instance_variable_get(:@opponent) if
      battle.instance_variable_defined?(:@opponent)

    if opponent.is_a?(Array)
      return opponent[owner_index] if opponent[owner_index]
      return opponent[0]
    end

    return opponent
  end

  #-----------------------------------------------------------------------------
  # Battle choice helpers.
  #-----------------------------------------------------------------------------
  def self.selected_move_index(battle, idxBattler)
    choices = nil
    choices = battle.instance_variable_get(:@choices) if
      battle.instance_variable_defined?(:@choices)
    return nil if !choices

    choice = choices[idxBattler]
    return nil if !choice
    return nil if choice[0] != :UseMove

    battler = get_battler(battle, idxBattler)
    return nil if !battler

    idxMove = choice[1]

    if idxMove.is_a?(Integer)
      return idxMove if idxMove >= 0 && battler.moves[idxMove]
    end

    # Fallback in case another plugin stores the move object instead.
    if idxMove && idxMove.respond_to?(:id)
      battler.moves.each_with_index do |move, i|
        next if !move
        return i if move.equal?(idxMove)
        return i if move.respond_to?(:id) && move.id == idxMove.id
      end
    end

    return nil
  end

  def self.selected_targets(battle, battler, _idxMove)
    targets = []

    choices = nil
    choices = battle.instance_variable_get(:@choices) if
      battle.instance_variable_defined?(:@choices)

    if choices && choices[battler.index]
      choice = choices[battler.index]
      target_data = choice[3]

      if target_data.is_a?(Integer) && target_data >= 0
        target = get_battler(battle, target_data)
        targets.push(target) if target && !target.fainted?
      elsif target_data && target_data.respond_to?(:index)
        targets.push(target_data) if !target_data.fainted?
      end
    end

    return targets if !targets.empty?

    # Fallback: check all living opposing battlers.
    battlers = get_battlers(battle)
    return targets if !battlers

    battlers.each_with_index do |target, i|
      next if !target
      next if target.fainted?
      next if same_side?(battler.index, i)
      targets.push(target)
    end

    return targets
  end

  def self.same_side?(idx1, idx2)
    return idx1.even? == idx2.even?
  end

  #-----------------------------------------------------------------------------
  # Move helpers.
  #-----------------------------------------------------------------------------
  def self.damaging_move?(move)
    return false if !move

    if move.respond_to?(:damagingMove?)
      return move.damagingMove?
    end

    if move.respond_to?(:statusMove?)
      return !move.statusMove?
    end

    return move_power(move) > 0
  end

  def self.move_power(move)
    return 0 if !move

    if move.respond_to?(:baseDamage)
      return move.baseDamage.to_i
    end

    if move.respond_to?(:base_damage)
      return move.base_damage.to_i
    end

    if move.instance_variable_defined?(:@baseDamage)
      return move.instance_variable_get(:@baseDamage).to_i
    end

    return 0
  end

  def self.move_type(move, battler)
    return nil if !move

    begin
      return move.pbCalcType(battler) if move.respond_to?(:pbCalcType)
    rescue
    end

    begin
      return move.display_type(battler) if move.respond_to?(:display_type)
    rescue
    end

    return move.type if move.respond_to?(:type)
    return move.type_id if move.respond_to?(:type_id)

    return nil
  end

  #-----------------------------------------------------------------------------
  # Type effectiveness helpers.
  #-----------------------------------------------------------------------------
  def self.type_super_effective?(attack_type, target)
    score = type_effectiveness_score(attack_type, target)
    neutral = neutral_effectiveness_score
    return score > neutral
  end

  def self.type_ineffective?(attack_type, target)
    score = type_effectiveness_score(attack_type, target)
    return score <= 0
  end

  def self.type_effectiveness_score(attack_type, target)
    return neutral_effectiveness_score if !attack_type
    return neutral_effectiveness_score if !target

    types = battler_types(target)
    return neutral_effectiveness_score if types.empty?

    begin
      return Effectiveness.calculate(attack_type, *types).to_f
    rescue
    end

    return neutral_effectiveness_score
  end

  def self.neutral_effectiveness_score
    if defined?(Effectiveness::NORMAL_EFFECTIVE)
      return Effectiveness::NORMAL_EFFECTIVE.to_f
    end

    # Essentials commonly uses a neutral value that still compares correctly
    # against its own super-effective and not-very-effective values.
    return 8.0
  end

  def self.battler_types(battler)
    return [] if !battler

    begin
      types = battler.pbTypes(true) if battler.respond_to?(:pbTypes)
      return types.compact if types && types.is_a?(Array)
    rescue
    end

    begin
      types = battler.pbTypes if battler.respond_to?(:pbTypes)
      return types.compact if types && types.is_a?(Array)
    rescue
    end

    return battler.types.compact if battler.respond_to?(:types)

    return []
  end

  #-----------------------------------------------------------------------------
  # General helpers.
  #-----------------------------------------------------------------------------
  def self.get_battlers(battle)
    return battle.battlers if battle.respond_to?(:battlers)
    return battle.instance_variable_get(:@battlers) if
      battle.instance_variable_defined?(:@battlers)
    return nil
  end

  def self.get_battler(battle, idxBattler)
    battlers = get_battlers(battle)
    return nil if !battlers
    return battlers[idxBattler]
  end

  def self.normalize_symbol(value)
    return nil if value.nil?
    return value if value.is_a?(Symbol)
    return value.to_s.upcase.gsub(/\s+/, "").to_sym
  end

  def self.random_chance(battle, percent)
    percent = percent.to_i
    percent = 0 if percent < 0
    percent = 100 if percent > 100

    roll = 0
    begin
      roll = battle.pbRandom(100)
    rescue
      roll = rand(100)
    end

    return roll < percent
  end
end

#===============================================================================
# Battle hooks
#===============================================================================
class Battle
  #-----------------------------------------------------------------------------
  # Store one-battle AI override, if one was set before the battle started.
  #-----------------------------------------------------------------------------
  if !method_defined?(:proto_code_npc_ai_initialize)
    alias proto_code_npc_ai_initialize initialize
  end

  def initialize(*args)
    proto_code_npc_ai_initialize(*args)
    @protoCodeNPCAILevelOverride = ProtoCode.consume_next_npc_ai_level
  end

  #-----------------------------------------------------------------------------
  # Activate NPC Proto Code after all commands have been chosen but before moves
  # begin resolving.
  #-----------------------------------------------------------------------------
  if !method_defined?(:proto_code_npc_ai_pbAttackPhase)
    alias proto_code_npc_ai_pbAttackPhase pbAttackPhase
  end

  def pbAttackPhase
    ProtoCode.try_npc_proto_code_for_all(self)
    return proto_code_npc_ai_pbAttackPhase
  end
end