#===============================================================================
# Pokémon Proto - Pokégear Time/Weather App
# For Pokémon Essentials v21.1
#===============================================================================

module ProtoPokegearWeather
  # Use the same switch as your UNREALTIME password.
  # Change this if your password system uses a different switch.
  UNREAL_TIME_UNLOCK_SWITCH = 80

  # Set this variable to control the displayed weather.
  #
  # Examples:
  #   $game_variables[90] = :SUN
  #   $game_variables[90] = :RAIN
  #   $game_variables[90] = :SNOW
  CURRENT_WEATHER_VARIABLE = 90

  WEATHER_DATA = {
    :SUN      => { :name => "Sunny",    :icon => "mapSun" },
    :RAIN     => { :name => "Rain",     :icon => "mapRain" },
    :STORM    => { :name => "Storm",    :icon => "mapStorm" },
    :SNOW     => { :name => "Snow",     :icon => "mapSnow" },
    :BLIZZARD => { :name => "Blizzard", :icon => "mapBlizzard" },
    :FOG      => { :name => "Fog",      :icon => "mapFog" },
    :SAND     => { :name => "Sandstorm",:icon => "mapSand" }
  }

  def self.unreal_time_unlocked?
    if defined?(ProtoPasswords) &&
       ProtoPasswords.respond_to?(:unreal_time_unlocked?)
      return ProtoPasswords.unreal_time_unlocked?
    end
    return $game_switches[UNREAL_TIME_UNLOCK_SWITCH]
  end

  def self.time_text
    time = pbGetTimeNow
    hour = time.hour
    minute = time.min

    suffix = (hour >= 12) ? "PM" : "AM"
    display_hour = hour % 12
    display_hour = 12 if display_hour == 0

    return sprintf("%d:%02d %s", display_hour, minute, suffix)
  end

  def self.weather_key
    value = $game_variables[CURRENT_WEATHER_VARIABLE]

    return :SUN if value.nil? || value == 0 || value == ""

    if value.is_a?(Symbol)
      key = value
    else
      key = value.to_s.upcase.to_sym
    end

    return :SUN if !WEATHER_DATA[key]
    return key
  end

  def self.current_weather_name
    key = weather_key
    return WEATHER_DATA[key][:name]
  end

  def self.current_weather_icon
    key = weather_key
    return WEATHER_DATA[key][:icon]
  end

  def self.advance_time_by_hours(hours)
    hours = hours.to_i
    return false if hours <= 0

    if defined?(UnrealTime) && UnrealTime.respond_to?(:add_hours)
      UnrealTime.add_hours(hours)
      return true
    elsif defined?(UnrealTime) && UnrealTime.respond_to?(:add_seconds)
      UnrealTime.add_seconds(hours * 3600)
      return true
    end

    return false
  end
end

def pbProtoPokegearWeather
  loop do
    time_text = ProtoPokegearWeather.time_text
    weather_text = ProtoPokegearWeather.current_weather_name

    pbMessage(_INTL("Time: {1}\nWeather: {2}", time_text, weather_text))

    commands = []
    cmdAdvance = -1
    cmdExit = -1

    if ProtoPokegearWeather.unreal_time_unlocked?
      cmdAdvance = commands.length
      commands.push(_INTL("Advance Time"))
    end

    cmdExit = commands.length
    commands.push(_INTL("Exit"))

    command = pbMessage(_INTL("What would you like to do?"), commands, cmdExit)

    if command == cmdAdvance
      hour_commands = []

      12.times do |i|
        hour_commands.push(_INTL("+{1} hour", i + 1))
      end

      hour_commands.push(_INTL("Cancel"))

      cancel_index = hour_commands.length - 1
      hour_choice = pbMessage(
        _INTL("Advance time by how many hours?"),
        hour_commands,
        cancel_index
      )

      next if hour_choice == cancel_index || hour_choice < 0

      hours = hour_choice + 1

      if ProtoPokegearWeather.advance_time_by_hours(hours)
        pbMessage(_INTL("Time was advanced by {1} hour(s).", hours))
      else
        pbMessage(_INTL("The time system is not available right now."))
      end
    else
      break
    end
  end
end

#===============================================================================
# Add app to Pokégear
#===============================================================================

MenuHandlers.add(:pokegear_menu, :proto_weather, {
  "name"      => _INTL("Weather"),
  "icon_name" => "mapSun",
  "order"     => 40,
  "effect"    => proc { |menu|
    pbFadeOutIn {
      pbProtoPokegearWeather
    }
    next false
  }
})