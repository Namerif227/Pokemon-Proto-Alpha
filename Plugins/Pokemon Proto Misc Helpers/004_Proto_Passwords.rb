#===============================================================================
# Pokemon Proto Password System
# For Pokemon Essentials v21.1
#-------------------------------------------------------------------------------
# Call with:
#   pbProtoPasswordSetup
#
# Recommended placement:
#   Run this once during the intro, after the player chooses their name/gender.
#===============================================================================

module ProtoPasswords
  # Change this switch ID to the switch you want to use to unlock the
  # Unreal Time Pokégear feature.
  UNREAL_TIME_UNLOCK_SWITCH = 80

  PASSWORDS = {
    "ALLLIGHT" => {
      :id      => :ALLLIGHT,
      :name    => "All Light",
      :message => "The flow of time will always appear as daytime."
    },

    "ALLDARK" => {
      :id      => :ALLDARK,
      :name    => "All Dark",
      :message => "The flow of time will always appear as nighttime."
    },

    "UNREALTIME" => {
      :id      => :UNREALTIME,
      :name    => "Unreal Time",
      :message => "The Pokégear's time controls have been unlocked."
    }
  }

  # Passwords listed in the same group cannot be active together.
  # Later, you can add more groups for other password conflicts.
  #
  # Example:
  # CONFLICT_GROUPS = [
  #   [:ALLLIGHT, :ALLDARK, :UNREALTIME],
  #   [:HARDMODE, :EASYMODE]
  # ]
  CONFLICT_GROUPS = [
    [:ALLLIGHT, :ALLDARK, :UNREALTIME]
  ]

  def self.data
    return {} if !$PokemonGlobal
    if !$PokemonGlobal.instance_variable_defined?(:@proto_passwords)
      $PokemonGlobal.instance_variable_set(:@proto_passwords, {})
    end
    return $PokemonGlobal.instance_variable_get(:@proto_passwords)
  end

  def self.setup_done?
    return false if !$PokemonGlobal
    return $PokemonGlobal.instance_variable_get(:@proto_password_setup_done) == true
  end

  def self.finish_setup
    return if !$PokemonGlobal
    $PokemonGlobal.instance_variable_set(:@proto_password_setup_done, true)
  end

  def self.active?(id)
    return data[id] == true
  end

  def self.normalize(text)
    return "" if !text
    return text.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def self.info_for_id(id)
    PASSWORDS.each_value do |info|
      return info if info[:id] == id
    end
    return nil
  end

  def self.conflicting_active_password(id)
    CONFLICT_GROUPS.each do |group|
      next if !group.include?(id)

      group.each do |other_id|
        next if other_id == id
        return other_id if active?(other_id)
      end
    end

    return nil
  end

  def self.deactivate(id)
    data[id] = false
  end

  def self.activate(id)
    data[id] = true
  end

  def self.replace_password(old_id, new_id)
    deactivate(old_id)
    activate(new_id)
  end

  def self.try_password(text)
    password = normalize(text)
    return [:blank, nil, nil] if password.empty?

    info = PASSWORDS[password]
    return [:invalid, nil, nil] if !info

    id = info[:id]
    return [:already_active, info, nil] if active?(id)

    conflict_id = conflicting_active_password(id)
    if conflict_id
      conflict_info = info_for_id(conflict_id)
      return [:conflict, info, conflict_info]
    end

    activate(id)
    return [:activated, info, nil]
  end

  def self.fixed_time_mode
    return :day if active?(:ALLLIGHT)
    return :night if active?(:ALLDARK)
    return nil
  end

  def self.unreal_time_unlocked?
    return active?(:UNREALTIME)
  end
end

#===============================================================================
# Password entry screen
#===============================================================================

def pbProtoPasswordSetup
  return if ProtoPasswords.setup_done?

  loop do
    break if !pbConfirmMessage(_INTL("Would you like to enter a password?"))

    password = pbEnterText(_INTL("Enter a password."), 0, 16)
    result, info, conflict_info = ProtoPasswords.try_password(password)

    case result
    when :blank
      pbMessage(_INTL("No password was entered."))

    when :invalid
      pbMessage(_INTL("That password was not recognized."))

    when :already_active
      pbMessage(_INTL("That password is already active."))

    when :conflict
      pbMessage(_INTL("That password conflicts with another."))

      if conflict_info
        pbMessage(_INTL("{1} conflicts with {2}.", info[:name], conflict_info[:name]))
      end

      if conflict_info && pbConfirmMessage(_INTL("Would you like to replace the previous entry with this one?"))
        ProtoPasswords.replace_password(conflict_info[:id], info[:id])
        pbMessage(_INTL("Password accepted!"))
        pbMessage(_INTL("{1} activated.", info[:name]))
        pbMessage(_INTL(info[:message]))
      else
        pbMessage(_INTL("The previous password was kept."))
      end

    when :activated
      pbMessage(_INTL("Password accepted!"))
      pbMessage(_INTL("{1} activated.", info[:name]))
      pbMessage(_INTL(info[:message]))
    end
  end

  ProtoPasswords.finish_setup
end

#===============================================================================
# Fixed time override
#-------------------------------------------------------------------------------
# Put this plugin after Unreal Time System if you want ALLLIGHT/ALLDARK to take
# priority over Unreal Time's normal clock.
#===============================================================================

if Object.private_method_defined?(:pbGetTimeNow) &&
   !Object.private_method_defined?(:proto_passwords_original_pbGetTimeNow)
  Object.send(:alias_method, :proto_passwords_original_pbGetTimeNow, :pbGetTimeNow)
end

def pbGetTimeNow
  base_time = nil

  if Object.private_method_defined?(:proto_passwords_original_pbGetTimeNow)
    base_time = proto_passwords_original_pbGetTimeNow
  else
    base_time = Time.now
  end

  mode = ProtoPasswords.fixed_time_mode

  case mode
  when :day
    return Time.local(base_time.year, base_time.month, base_time.day, 12, 0, 0)
  when :night
    return Time.local(base_time.year, base_time.month, base_time.day, 22, 0, 0)
  end

  return base_time
end
