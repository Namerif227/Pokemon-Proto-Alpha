#===============================================================================
# Proto Stat Arrows
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Adds small stat-stage arrows to each battle databox.
#
# Green arrow = raised stat stage
# Red arrow   = lowered stat stage
#
# Supports:
# - Single battles
# - Double battles
# - Optional triple battle fallback
# - Per-stat position editing
# - Per-battler position editing
#===============================================================================

module ProtoStatArrows
  #-----------------------------------------------------------------------------
  # Graphics
  #-----------------------------------------------------------------------------
  UP_ARROW_GRAPHIC   = "Graphics/UI/Battle/stat_arrow_up"
  DOWN_ARROW_GRAPHIC = "Graphics/UI/Battle/stat_arrow_down"

  ARROW_WIDTH  = 4
  ARROW_HEIGHT = 5

  # You currently use -1, which makes arrows overlap slightly.
  # Use 3 if you want a normal 3-pixel gap.
  ARROW_GAP    = -1
  ARROW_STEP   = ARROW_WIDTH + ARROW_GAP

  MAX_ARROWS = 6

  #-----------------------------------------------------------------------------
  # Stats displayed.
  #-----------------------------------------------------------------------------
  STATS = [
    :ATTACK,
    :DEFENSE,
    :SPECIAL_ATTACK,
    :SPECIAL_DEFENSE,
    :SPEED,
    :ACCURACY,
    :EVASION
  ]

  #-----------------------------------------------------------------------------
  # Overlay canvas size.
  # Increase if arrows are cut off.
  #-----------------------------------------------------------------------------
  CANVAS_WIDTH  = 250
  CANVAS_HEIGHT = 150

  #=============================================================================
  # SINGLE BATTLE SETTINGS
  #=============================================================================

  # Whole overlay position relative to the databox.
  SINGLE_PLAYER_POSITION = [6, 6]
  SINGLE_ENEMY_POSITION  = [6, 6]

  # Individual stat arrow positions inside the overlay canvas.
  SINGLE_PLAYER_STAT_POSITIONS = {
    :ATTACK          => [54,  45],
    :DEFENSE         => [135, 45],
    :SPECIAL_ATTACK  => [99,  45],
    :SPECIAL_DEFENSE => [180, 45],
    :SPEED           => [216, 45],
    :ACCURACY        => [216, 6],
    :EVASION         => [216, 0]
  }

  SINGLE_ENEMY_STAT_POSITIONS = {
    :ATTACK          => [27,  45],
    :DEFENSE         => [108, 45],
    :SPECIAL_ATTACK  => [72,  45],
    :SPECIAL_DEFENSE => [153, 45],
    :SPEED           => [189, 45],
    :ACCURACY        => [28,  6],
    :EVASION         => [28,  0]
  }

  SINGLE_PLAYER_GROW_RIGHT = true
  SINGLE_ENEMY_GROW_RIGHT  = true

  #=============================================================================
  # DOUBLE BATTLE SETTINGS
  #=============================================================================
  # Battler indexes:
  #   0 = player Pokémon 1
  #   1 = enemy Pokémon 1
  #   2 = player Pokémon 2
  #   3 = enemy Pokémon 2
  #
  # These are starter values. Adjust them once you test double battles.
  #=============================================================================

  DOUBLE_POSITIONS = {
    0 => [6, 5],   # Player Pokémon 1
    1 => [6, 5],   # Enemy Pokémon 1
    2 => [6, 5],   # Player Pokémon 2
    3 => [6, 5]    # Enemy Pokémon 2
  }

  DOUBLE_STAT_POSITIONS = {
    0 => {   # Player Pokémon 1
      :ATTACK          => [54,  35],
      :DEFENSE         => [135, 35],
      :SPECIAL_ATTACK  => [99,  35],
      :SPECIAL_DEFENSE => [180, 35],
      :SPEED           => [216, 35],
      :ACCURACY        => [216, 6],
      :EVASION         => [216, 0]
    },

    1 => {   # Enemy Pokémon 1
      :ATTACK          => [26,  36],
      :DEFENSE         => [107, 36],
      :SPECIAL_ATTACK  => [71,  36],
      :SPECIAL_DEFENSE => [152, 36],
      :SPEED           => [188, 36],
      :ACCURACY        => [27,  6],
      :EVASION         => [27,  0]
    },

    2 => {   # Player Pokémon 2
      :ATTACK          => [54,  35],
      :DEFENSE         => [135, 35],
      :SPECIAL_ATTACK  => [99,  35],
      :SPECIAL_DEFENSE => [180, 35],
      :SPEED           => [216, 35],
      :ACCURACY        => [216, 6],
      :EVASION         => [216, 0]
    },

    3 => {   # Enemy Pokémon 2
      :ATTACK          => [26,  36],
      :DEFENSE         => [107, 36],
      :SPECIAL_ATTACK  => [71,  36],
      :SPECIAL_DEFENSE => [152, 36],
      :SPEED           => [188, 36],
      :ACCURACY        => [27,  6],
      :EVASION         => [27,  0]
    }
  }

  DOUBLE_GROW_RIGHT = {
    0 => true,
    1 => true,
    2 => true,
    3 => true
  }

  #=============================================================================
  # OPTIONAL TRIPLE BATTLE FALLBACK
  #=============================================================================

  TRIPLE_POSITIONS = {
    0 => [6, 6],
    1 => [6, 6],
    2 => [6, 6],
    3 => [6, 6],
    4 => [6, 6],
    5 => [6, 6]
  }

  TRIPLE_STAT_POSITIONS = {
    0 => SINGLE_PLAYER_STAT_POSITIONS,
    1 => SINGLE_ENEMY_STAT_POSITIONS,
    2 => SINGLE_PLAYER_STAT_POSITIONS,
    3 => SINGLE_ENEMY_STAT_POSITIONS,
    4 => SINGLE_PLAYER_STAT_POSITIONS,
    5 => SINGLE_ENEMY_STAT_POSITIONS
  }

  TRIPLE_GROW_RIGHT = {
    0 => true,
    1 => true,
    2 => true,
    3 => true,
    4 => true,
    5 => true
  }

  #-----------------------------------------------------------------------------
  # Sprite layer.
  #
  # Use 20 while testing/positioning.
  # Use 2 for normal above-databox display.
  # Use -1 if you want it behind the databox.
  #-----------------------------------------------------------------------------
  Z_OFFSET = 2

  OPACITY = 255

  #-----------------------------------------------------------------------------
  # Gets the stage value for a battler stat.
  #-----------------------------------------------------------------------------
  def self.stage_value(battler, stat)
    return 0 if !battler

    stages = nil

    if battler.respond_to?(:stages)
      stages = battler.stages
    elsif battler.instance_variable_defined?(:@stages)
      stages = battler.instance_variable_get(:@stages)
    end

    return 0 if !stages
    return stages[stat] || 0
  end

  #-----------------------------------------------------------------------------
  # Makes a compact key so the overlay only redraws when stat stages change.
  #-----------------------------------------------------------------------------
  def self.stage_key(battler)
    return "" if !battler || !battler.pokemon || battler.fainted?

    values = []
    STATS.each do |stat|
      values.push(stage_value(battler, stat))
    end

    return values.join(",")
  end

  #-----------------------------------------------------------------------------
  # Gets whole overlay position depending on single/double/triple battle.
  #-----------------------------------------------------------------------------
  def self.overlay_position(battler, side_size)
    return [0, 0] if !battler

    case side_size
    when 1
      return battler.opposes?(0) ? SINGLE_ENEMY_POSITION : SINGLE_PLAYER_POSITION
    when 2
      return DOUBLE_POSITIONS[battler.index] || [0, 0]
    when 3
      return TRIPLE_POSITIONS[battler.index] || [0, 0]
    end

    return battler.opposes?(0) ? SINGLE_ENEMY_POSITION : SINGLE_PLAYER_POSITION
  end

  #-----------------------------------------------------------------------------
  # Gets individual stat position depending on single/double/triple battle.
  #-----------------------------------------------------------------------------
  def self.position_for_stat(battler, side_size, stat)
    return [0, 0] if !battler

    case side_size
    when 1
      if battler.opposes?(0)
        return SINGLE_ENEMY_STAT_POSITIONS[stat] || [0, 0]
      else
        return SINGLE_PLAYER_STAT_POSITIONS[stat] || [0, 0]
      end

    when 2
      positions = DOUBLE_STAT_POSITIONS[battler.index]
      return positions[stat] if positions && positions[stat]

    when 3
      positions = TRIPLE_STAT_POSITIONS[battler.index]
      return positions[stat] if positions && positions[stat]
    end

    if battler.opposes?(0)
      return SINGLE_ENEMY_STAT_POSITIONS[stat] || [0, 0]
    end

    return SINGLE_PLAYER_STAT_POSITIONS[stat] || [0, 0]
  end

  #-----------------------------------------------------------------------------
  # Gets arrow growth direction depending on single/double/triple battle.
  #-----------------------------------------------------------------------------
  def self.grow_right?(battler, side_size)
    return true if !battler

    case side_size
    when 1
      return battler.opposes?(0) ? SINGLE_ENEMY_GROW_RIGHT : SINGLE_PLAYER_GROW_RIGHT
    when 2
      return DOUBLE_GROW_RIGHT[battler.index] if DOUBLE_GROW_RIGHT.key?(battler.index)
    when 3
      return TRIPLE_GROW_RIGHT[battler.index] if TRIPLE_GROW_RIGHT.key?(battler.index)
    end

    return battler.opposes?(0) ? SINGLE_ENEMY_GROW_RIGHT : SINGLE_PLAYER_GROW_RIGHT
  end
end

#===============================================================================
# Databox patch
#===============================================================================
class Battle::Scene::PokemonDataBox
  #-----------------------------------------------------------------------------
  # Store sideSize so the plugin can tell single/double/triple battles apart.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_initialize initialize
  def initialize(battler, sideSize, viewport = nil)
    @protoStatArrowsSideSize = sideSize
    proto_stat_arrows_initialize(battler, sideSize, viewport)
  end

  #-----------------------------------------------------------------------------
  # Create arrow overlay after the original databox graphics are created.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    proto_stat_arrows_initializeOtherGraphics(viewport)

    @protoStatArrowUpBitmap   = AnimatedBitmap.new(ProtoStatArrows::UP_ARROW_GRAPHIC)
    @protoStatArrowDownBitmap = AnimatedBitmap.new(ProtoStatArrows::DOWN_ARROW_GRAPHIC)

    @protoStatArrowOverlay = BitmapSprite.new(
      ProtoStatArrows::CANVAS_WIDTH,
      ProtoStatArrows::CANVAS_HEIGHT,
      viewport
    )

    @protoStatArrowOverlay.opacity = ProtoStatArrows::OPACITY
    @protoStatArrowOverlay.visible = false

    @sprites["protoStatArrowOverlay"] = @protoStatArrowOverlay

    @protoLastStatArrowKey = nil
  end

  #-----------------------------------------------------------------------------
  # Dispose arrow graphics.
  # The overlay sprite itself is disposed by pbDisposeSpriteHash(@sprites).
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_dispose dispose
  def dispose
    @protoStatArrowUpBitmap&.dispose
    @protoStatArrowDownBitmap&.dispose
    proto_stat_arrows_dispose
  end

  #-----------------------------------------------------------------------------
  # Attach overlay X position to the databox.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_x_set x=
  def x=(value)
    proto_stat_arrows_x_set(value)

    return if !@protoStatArrowOverlay || @protoStatArrowOverlay.disposed?

    offset_x, _offset_y = ProtoStatArrows.overlay_position(@battler, @protoStatArrowsSideSize)
    @protoStatArrowOverlay.x = value + offset_x
  end

  #-----------------------------------------------------------------------------
  # Attach overlay Y position to the databox.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_y_set y=
  def y=(value)
    proto_stat_arrows_y_set(value)

    return if !@protoStatArrowOverlay || @protoStatArrowOverlay.disposed?

    _offset_x, offset_y = ProtoStatArrows.overlay_position(@battler, @protoStatArrowsSideSize)
    @protoStatArrowOverlay.y = value + offset_y
  end

  #-----------------------------------------------------------------------------
  # Attach overlay Z layer to the databox.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_z_set z=
  def z=(value)
    proto_stat_arrows_z_set(value)

    return if !@protoStatArrowOverlay || @protoStatArrowOverlay.disposed?

    @protoStatArrowOverlay.z = value + ProtoStatArrows::Z_OFFSET
  end

  #-----------------------------------------------------------------------------
  # Refresh visibility when databox visibility changes.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_visible_set visible=
  def visible=(value)
    proto_stat_arrows_visible_set(value)
    refresh_proto_stat_arrows if @protoStatArrowOverlay && !@protoStatArrowOverlay.disposed?
  end

  #-----------------------------------------------------------------------------
  # Reset cache when battler changes.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_battler_set battler=
  def battler=(value)
    proto_stat_arrows_battler_set(value)
    @protoLastStatArrowKey = nil
    refresh_proto_stat_arrows
  end

  #-----------------------------------------------------------------------------
  # Refresh arrows when the databox refreshes.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_refresh refresh
  def refresh
    proto_stat_arrows_refresh
    @protoLastStatArrowKey = nil
    refresh_proto_stat_arrows
  end

  #-----------------------------------------------------------------------------
  # Update arrows automatically.
  #-----------------------------------------------------------------------------
  alias proto_stat_arrows_update update
  def update
    proto_stat_arrows_update
    update_proto_stat_arrows
  end

  #-----------------------------------------------------------------------------
  # Draw the stat arrows.
  #-----------------------------------------------------------------------------
  def refresh_proto_stat_arrows
    return if !@protoStatArrowOverlay || @protoStatArrowOverlay.disposed?

    bitmap = @protoStatArrowOverlay.bitmap
    bitmap.clear

    @protoStatArrowOverlay.visible = false

    return if !self.visible
    return if !@battler
    return if !@battler.pokemon
    return if @battler.fainted?

    up_bitmap   = @protoStatArrowUpBitmap.bitmap
    down_bitmap = @protoStatArrowDownBitmap.bitmap

    return if !up_bitmap || !down_bitmap

    grow_right = ProtoStatArrows.grow_right?(@battler, @protoStatArrowsSideSize)
    any_arrows = false

    ProtoStatArrows::STATS.each do |stat|
      stage = ProtoStatArrows.stage_value(@battler, stat)
      next if stage == 0

      any_arrows = true

      arrow_count = stage.abs
      arrow_count = ProtoStatArrows::MAX_ARROWS if arrow_count > ProtoStatArrows::MAX_ARROWS

      source_bitmap = (stage > 0) ? up_bitmap : down_bitmap

      source_rect = Rect.new(
        0,
        0,
        ProtoStatArrows::ARROW_WIDTH,
        ProtoStatArrows::ARROW_HEIGHT
      )

      stat_x, stat_y = ProtoStatArrows.position_for_stat(
        @battler,
        @protoStatArrowsSideSize,
        stat
      )

      arrow_count.times do |i|
        if grow_right
          x_pos = stat_x + (i * ProtoStatArrows::ARROW_STEP)
        else
          x_pos = stat_x - (i * ProtoStatArrows::ARROW_STEP)
        end

        bitmap.blt(x_pos, stat_y, source_bitmap, source_rect)
      end
    end

    @protoStatArrowOverlay.visible = any_arrows
  end

  #-----------------------------------------------------------------------------
  # Redraw only when stat stages change.
  #-----------------------------------------------------------------------------
  def update_proto_stat_arrows
    return if !@protoStatArrowOverlay || @protoStatArrowOverlay.disposed?

    key = ProtoStatArrows.stage_key(@battler)
    return if key == @protoLastStatArrowKey

    @protoLastStatArrowKey = key
    refresh_proto_stat_arrows
  end
end