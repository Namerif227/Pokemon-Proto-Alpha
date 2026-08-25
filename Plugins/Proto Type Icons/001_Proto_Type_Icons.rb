#===============================================================================
# Proto Type Icons
# For Pokémon Essentials v21.1
#-------------------------------------------------------------------------------
# Adds 16x16 Pokémon type icons to the battle databox.
#
# Features:
# - Player and enemy databox support
# - Single and dual type support
# - Separate single/double battle positions
# - Separate first/second icon positions
# - Safer type detection
# - Debug mode for missing icon files
#===============================================================================

module ProtoTypeIcons
  #-----------------------------------------------------------------------------
  # Debug options
  #-----------------------------------------------------------------------------
  DEBUG_MESSAGES = false

  # Set this to something like [:FIRE] or [:FIRE, :FLYING] to test drawing.
  # Set back to nil when done.
  FORCE_TEST_TYPES = nil
  # FORCE_TEST_TYPES = [:FIRE]
  # FORCE_TEST_TYPES = [:FIRE, :FLYING]

  #-----------------------------------------------------------------------------
  # Icon folder
  #-----------------------------------------------------------------------------
  TYPE_ICON_FOLDER = "Graphics/UI/Battle/type_icons"

  # Graphic used in the second slot for single-type Pokémon.
  NULL_ICON_FILE = "null"

  #-----------------------------------------------------------------------------
  # Icon size
  #-----------------------------------------------------------------------------
  ICON_WIDTH  = 16
  ICON_HEIGHT = 16

  #-----------------------------------------------------------------------------
  # Overlay canvas size.
  # Increase if icons are cut off.
  #-----------------------------------------------------------------------------
  CANVAS_WIDTH  = 250
  CANVAS_HEIGHT = 80

  #-----------------------------------------------------------------------------
  # Single battle whole icon group positions.
  #
  # These are your current working single battle values.
  #-----------------------------------------------------------------------------
  SINGLE_PLAYER_POSITION = [29, 32]
  SINGLE_ENEMY_POSITION  = [193, 32]

  #-----------------------------------------------------------------------------
  # Double battle whole icon group positions.
  #
  # Battler indexes:
  #   0 = player's first Pokémon
  #   1 = enemy's first Pokémon
  #   2 = player's second Pokémon
  #   3 = enemy's second Pokémon
  #
  # These are starter values. You will tweak them.
  #-----------------------------------------------------------------------------
  DOUBLE_POSITIONS = {
    0 => [34, 21],    # Player Pokémon 1
    1 => [194, 23],   # Enemy Pokémon 1
    2 => [34, 21],    # Player Pokémon 2
    3 => [194, 23]    # Enemy Pokémon 2
  }

  #-----------------------------------------------------------------------------
  # Optional triple battle positions.
  # Not needed unless you use triples, but this prevents weird fallback behavior.
  #-----------------------------------------------------------------------------
  TRIPLE_POSITIONS = {
    0 => [26, 32],
    1 => [195, 32],
    2 => [26, 32],
    3 => [195, 32],
    4 => [26, 32],
    5 => [195, 32]
  }

  #-----------------------------------------------------------------------------
  # Single battle first/second type icon positions inside overlay canvas.
  #-----------------------------------------------------------------------------
  SINGLE_PLAYER_TYPE_SLOT_POSITIONS = [
    [0,  0],   # First type
    [17, 0]    # Second type
  ]

  SINGLE_ENEMY_TYPE_SLOT_POSITIONS = [
    [0,  0],   # First type
    [17, 0]    # Second type
  ]

  #-----------------------------------------------------------------------------
  # Double battle first/second type icon positions.
  #
  # Use this if double-battle databoxes need different internal spacing.
  #-----------------------------------------------------------------------------
  DOUBLE_TYPE_SLOT_POSITIONS = {
    0 => [[0, 0], [17, 0]],   # Player Pokémon 1
    1 => [[0, 0], [17, 0]],   # Enemy Pokémon 1
    2 => [[0, 0], [17, 0]],   # Player Pokémon 2
    3 => [[0, 0], [17, 0]]    # Enemy Pokémon 2
  }

  #-----------------------------------------------------------------------------
  # Triple battle slot positions.
  #-----------------------------------------------------------------------------
  TRIPLE_TYPE_SLOT_POSITIONS = {
    0 => [[0, 0], [18, 0]],
    1 => [[0, 0], [18, 0]],
    2 => [[0, 0], [18, 0]],
    3 => [[0, 0], [18, 0]],
    4 => [[0, 0], [18, 0]],
    5 => [[0, 0], [18, 0]]
  }

  #-----------------------------------------------------------------------------
  # Sprite layer.
  #
  # Use 20 while positioning so you can clearly see the icons.
  # Once positioned, try 2.
  #-----------------------------------------------------------------------------
  Z_OFFSET = 2

  #-----------------------------------------------------------------------------
  # Icon opacity.
  #-----------------------------------------------------------------------------
  OPACITY = 255

  #-----------------------------------------------------------------------------
  # File names.
  # Do not include .png.
  #-----------------------------------------------------------------------------
  TYPE_FILES = {
    :NORMAL   => "normal",
    :FIRE     => "fire",
    :WATER    => "water",
    :ELECTRIC => "electric",
    :GRASS    => "grass",
    :ICE      => "ice",
    :FIGHTING => "fighting",
    :POISON   => "poison",
    :GROUND   => "ground",
    :FLYING   => "flying",
    :PSYCHIC  => "psychic",
    :BUG      => "bug",
    :ROCK     => "rock",
    :GHOST    => "ghost",
    :DRAGON   => "dragon",
    :DARK     => "dark",
    :STEEL    => "steel",
    :FAIRY    => "fairy"
  }

  def self.debug(message)
    return if !DEBUG_MESSAGES
    echoln("[Proto Type Icons] #{message}") if defined?(echoln)
  end

  def self.normalize_type(type)
    return nil if !type

    type = type.id if type.respond_to?(:id)

    if type.is_a?(String)
      type = type.upcase.to_sym
    elsif type.is_a?(Symbol)
      type = type.to_s.upcase.to_sym
    else
      return nil
    end

    return nil if !TYPE_FILES.key?(type)
    return type
  end

  def self.battler_types(battler)
    return FORCE_TEST_TYPES if FORCE_TEST_TYPES
    return [] if !battler

    raw_types = []

    if battler.respond_to?(:pbTypes)
      begin
        arity = battler.method(:pbTypes).arity
        raw_types = (arity == 0) ? battler.pbTypes : battler.pbTypes(true)
      rescue
        begin
          raw_types = battler.pbTypes
        rescue
          raw_types = []
        end
      end
    end

    if raw_types.nil? || raw_types.empty?
      if battler.respond_to?(:types)
        begin
          raw_types = battler.types
        rescue
          raw_types = []
        end
      end
    end

    if raw_types.nil? || raw_types.empty?
      if battler.respond_to?(:pbHasType?)
        TYPE_FILES.keys.each do |type|
          begin
            raw_types.push(type) if battler.pbHasType?(type)
          rescue
          end
        end
      end
    end

    if raw_types.nil? || raw_types.empty?
      pkmn = nil
      begin
        pkmn = battler.pokemon if battler.respond_to?(:pokemon)
      rescue
        pkmn = nil
      end

      if pkmn
        if pkmn.respond_to?(:types)
          begin
            raw_types = pkmn.types
          rescue
            raw_types = []
          end
        elsif pkmn.respond_to?(:species_data) && pkmn.species_data.respond_to?(:types)
          begin
            raw_types = pkmn.species_data.types
          rescue
            raw_types = []
          end
        end
      end
    end

    raw_types = [] if !raw_types
    raw_types = [raw_types] if !raw_types.is_a?(Array)

    types = []
    raw_types.each do |type|
      normalized = normalize_type(type)
      types.push(normalized) if normalized
    end

    types.uniq!

    debug("Types for #{battler.name}: #{types.inspect}") if battler.respond_to?(:name)

    return types
  end

  def self.type_key(battler)
    return "" if !battler || !battler.pokemon || battler.fainted?
    return battler_types(battler).join(",")
  end

  #-----------------------------------------------------------------------------
  # Returns the whole overlay position depending on single/double/triple battle.
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
  # Returns first/second type slot position depending on single/double/triple.
  #-----------------------------------------------------------------------------
  def self.slot_position(battler, side_size, index)
    return [index * 18, 0] if !battler

    positions = nil

    case side_size
    when 1
      positions = battler.opposes?(0) ? SINGLE_ENEMY_TYPE_SLOT_POSITIONS : SINGLE_PLAYER_TYPE_SLOT_POSITIONS
    when 2
      positions = DOUBLE_TYPE_SLOT_POSITIONS[battler.index]
    when 3
      positions = TRIPLE_TYPE_SLOT_POSITIONS[battler.index]
    end

    positions ||= battler.opposes?(0) ? SINGLE_ENEMY_TYPE_SLOT_POSITIONS : SINGLE_PLAYER_TYPE_SLOT_POSITIONS
    return positions[index] || [index * 18, 0]
  end

  def self.icon_path_candidates(type)
    # :NULL is a display-only placeholder, not an actual Pokémon type.
    file = (type == :NULL) ? NULL_ICON_FILE : TYPE_FILES[type]
    return [] if !file

    candidates = []
    candidates.push("#{TYPE_ICON_FOLDER}/#{file}")
    candidates.push("#{TYPE_ICON_FOLDER}/#{file.downcase}")
    candidates.push("#{TYPE_ICON_FOLDER}/#{file.upcase}")
    candidates.push("#{TYPE_ICON_FOLDER}/#{file.capitalize}")
    candidates.uniq!

    return candidates
  end

  def self.resolved_icon_path(type)
    icon_path_candidates(type).each do |path|
      return path if pbResolveBitmap(path)
    end
    return nil
  end
end

#===============================================================================
# Databox patch
#===============================================================================
class Battle::Scene::PokemonDataBox
  #-----------------------------------------------------------------------------
  # Store sideSize so the plugin can tell single/double/triple battles apart.
  #-----------------------------------------------------------------------------
  alias proto_type_icons_initialize initialize
  def initialize(battler, sideSize, viewport = nil)
    @protoTypeIconsSideSize = sideSize
    proto_type_icons_initialize(battler, sideSize, viewport)
  end

  alias proto_type_icons_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    proto_type_icons_initializeOtherGraphics(viewport)

    @protoTypeIconOverlay = BitmapSprite.new(
      ProtoTypeIcons::CANVAS_WIDTH,
      ProtoTypeIcons::CANVAS_HEIGHT,
      viewport
    )

    @protoTypeIconOverlay.opacity = ProtoTypeIcons::OPACITY
    @protoTypeIconOverlay.visible = false

    @sprites["protoTypeIconOverlay"] = @protoTypeIconOverlay

    @protoTypeIconBitmaps = {}
    @protoLastTypeIconKey = nil
  end

  alias proto_type_icons_dispose dispose
  def dispose
    if @protoTypeIconBitmaps
      @protoTypeIconBitmaps.each_value do |bitmap|
        bitmap.dispose if bitmap
      end
      @protoTypeIconBitmaps.clear
    end

    proto_type_icons_dispose
  end

  alias proto_type_icons_x_set x=
  def x=(value)
    proto_type_icons_x_set(value)

    return if !@protoTypeIconOverlay || @protoTypeIconOverlay.disposed?

    offset_x, _offset_y = ProtoTypeIcons.overlay_position(@battler, @protoTypeIconsSideSize)
    @protoTypeIconOverlay.x = value + offset_x
  end

  alias proto_type_icons_y_set y=
  def y=(value)
    proto_type_icons_y_set(value)

    return if !@protoTypeIconOverlay || @protoTypeIconOverlay.disposed?

    _offset_x, offset_y = ProtoTypeIcons.overlay_position(@battler, @protoTypeIconsSideSize)
    @protoTypeIconOverlay.y = value + offset_y
  end

  alias proto_type_icons_z_set z=
  def z=(value)
    proto_type_icons_z_set(value)

    return if !@protoTypeIconOverlay || @protoTypeIconOverlay.disposed?

    @protoTypeIconOverlay.z = value + ProtoTypeIcons::Z_OFFSET
  end

  alias proto_type_icons_visible_set visible=
  def visible=(value)
    proto_type_icons_visible_set(value)
    refresh_proto_type_icons if @protoTypeIconOverlay && !@protoTypeIconOverlay.disposed?
  end

  alias proto_type_icons_battler_set battler=
  def battler=(value)
    proto_type_icons_battler_set(value)
    @protoLastTypeIconKey = nil
    refresh_proto_type_icons
  end

  alias proto_type_icons_refresh refresh
  def refresh
    proto_type_icons_refresh
    @protoLastTypeIconKey = nil
    refresh_proto_type_icons
  end

  alias proto_type_icons_update update
  def update
    proto_type_icons_update
    update_proto_type_icons
  end

  def proto_type_icon_bitmap(type)
    return nil if !type

    @protoTypeIconBitmaps ||= {}
    return @protoTypeIconBitmaps[type] if @protoTypeIconBitmaps[type]

    path = ProtoTypeIcons.resolved_icon_path(type)

    if !path
      ProtoTypeIcons.debug("Missing icon for #{type}. Tried: #{ProtoTypeIcons.icon_path_candidates(type).inspect}")
      return nil
    end

    ProtoTypeIcons.debug("Loaded icon for #{type}: #{path}")

    @protoTypeIconBitmaps[type] = AnimatedBitmap.new(path)
    return @protoTypeIconBitmaps[type]
  end

  def refresh_proto_type_icons
    return if !@protoTypeIconOverlay || @protoTypeIconOverlay.disposed?

    bitmap = @protoTypeIconOverlay.bitmap
    bitmap.clear

   @protoTypeIconOverlay.visible = false

    return if !self.visible
    return if !@battler
    return if !@battler.pokemon
    return if @battler.fainted?

    types = ProtoTypeIcons.battler_types(@battler)
    return if types.empty?

    # Always prepare two display slots.
    #
    # Dual type:
    #   [:FIRE, :FLYING]
    #
    # Single type:
    #   [:FIRE, :NULL]
    display_types = [
      types[0],
      types[1] || :NULL
    ]

    drew_icon = false

    display_types.each_with_index do |type, index|
      icon_bitmap = proto_type_icon_bitmap(type)
      next if !icon_bitmap || !icon_bitmap.bitmap

      x_pos, y_pos = ProtoTypeIcons.slot_position(
        @battler,
        @protoTypeIconsSideSize,
        index
      )

      source_rect = Rect.new(
        0,
        0,
        ProtoTypeIcons::ICON_WIDTH,
        ProtoTypeIcons::ICON_HEIGHT
      )

      bitmap.blt(x_pos, y_pos, icon_bitmap.bitmap, source_rect)
      drew_icon = true
    end

    @protoTypeIconOverlay.visible = drew_icon
  end

  def update_proto_type_icons
    return if !@protoTypeIconOverlay || @protoTypeIconOverlay.disposed?

    key = ProtoTypeIcons.type_key(@battler)
    return if key == @protoLastTypeIconKey

    @protoLastTypeIconKey = key
    refresh_proto_type_icons
  end
end