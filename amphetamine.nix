{ primaryUser }:
{ pkgs, ... }:

let
  powerProtectScript = pkgs.writeText "amphetamine-power-protect.applescript" ''
    on enableDisablePowerProtect(inputString)
      if inputString is "enable" then
        try
          do shell script "sudo /usr/bin/pmset -a disablesleep 1"
          return "success"
        on error
          return "fail"
        end try
      end if

      if inputString is "disable" then
        try
          do shell script "sudo /usr/bin/pmset -a disablesleep 0"
          return "success"
        on error
          return "fail"
        end try
      end if

      return "fail"
    end enableDisablePowerProtect

    on installPowerProtectSudoOverride(inputString)
      if powerProtectSudoFileExists() then
        return "success"
      end if

      return "fail"
    end installPowerProtectSudoOverride

    on powerProtectSudoFileExists()
      tell application "System Events"
        return exists file "/etc/sudoers.d/amphetamine_PowerProtect"
      end tell
    end powerProtectSudoFileExists
  '';
in
{
  homebrew.masApps.Amphetamine = 937984704;

  system.activationScripts.postActivation.text = ''
    echo "configuring Amphetamine..."
    (
      set -e

      user_id=$(/usr/bin/id -u ${primaryUser})
      application_scripts="/Users/${primaryUser}/Library/Application Scripts/com.if.Amphetamine"
      temporary_directory=$(/usr/bin/mktemp -d /private/tmp/amphetamine-power-protect.XXXXXX)
      trap '/bin/rm -rf "$temporary_directory"' EXIT

      as_user() {
        /bin/launchctl asuser "$user_id" \
          /usr/bin/sudo -u ${primaryUser} -H -- "$@"
      }

      /usr/bin/osacompile \
        -o "$temporary_directory/powerProtect.scpt" \
        "${powerProtectScript}"
      /usr/bin/install \
        -d -o ${primaryUser} -g staff -m 0755 \
        "$application_scripts"
      /usr/bin/install \
        -o ${primaryUser} -g staff -m 0644 \
        "$temporary_directory/powerProtect.scpt" \
        "$application_scripts/powerProtect.scpt"

      /bin/cat > "$temporary_directory/amphetamine_PowerProtect" <<'EOF'
    Cmnd_Alias PMSET_AMPHETAMINE = /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
    ${primaryUser} ALL = (root) NOPASSWD: PMSET_AMPHETAMINE
    EOF
      /bin/chmod 0440 "$temporary_directory/amphetamine_PowerProtect"
      /usr/sbin/visudo -cf "$temporary_directory/amphetamine_PowerProtect"
      /usr/bin/install \
        -o root -g wheel -m 0440 \
        "$temporary_directory/amphetamine_PowerProtect" \
        /private/etc/sudoers.d/amphetamine_PowerProtect

      settings_are_current=true
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'Allow Closed-Display Sleep' 2>/dev/null || true)" = 0 ] || settings_are_current=false
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'Allow Display Sleep' 2>/dev/null || true)" = 1 ] || settings_are_current=false
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'Default Duration' 2>/dev/null || true)" = 0 ] || settings_are_current=false
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'End Session On Low Battery' 2>/dev/null || true)" = 1 ] || settings_are_current=false
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'Ignore Battery on AC' 2>/dev/null || true)" = 1 ] || settings_are_current=false
      [ "$(as_user /usr/bin/defaults read com.if.Amphetamine 'Low Battery Percent' 2>/dev/null || true)" = 20 ] || settings_are_current=false

      if [ "$settings_are_current" = false ]; then
        was_running=false
        session_was_active=false

        if /usr/bin/pgrep -xu "$user_id" Amphetamine >/dev/null; then
          was_running=true
          session_was_active=$(as_user /usr/bin/osascript -e 'tell application "Amphetamine" to session is active')

          if [ "$session_was_active" = true ]; then
            as_user /usr/bin/osascript -e 'tell application "Amphetamine" to end session'
          fi

          /usr/bin/pkill -TERM -xu "$user_id" Amphetamine
          for _ in {1..50}; do
            /usr/bin/pgrep -xu "$user_id" Amphetamine >/dev/null || break
            /bin/sleep 0.1
          done

          if /usr/bin/pgrep -xu "$user_id" Amphetamine >/dev/null; then
            echo "Amphetamine did not terminate in time" >&2
            exit 1
          fi
        fi

        as_user /usr/bin/defaults write com.if.Amphetamine 'Allow Closed-Display Sleep' -bool false
        as_user /usr/bin/defaults write com.if.Amphetamine 'Allow Display Sleep' -bool true
        as_user /usr/bin/defaults write com.if.Amphetamine 'Default Duration' -int 0
        as_user /usr/bin/defaults write com.if.Amphetamine 'End Session On Low Battery' -bool true
        as_user /usr/bin/defaults write com.if.Amphetamine 'Ignore Battery on AC' -bool true
        as_user /usr/bin/defaults write com.if.Amphetamine 'Low Battery Percent' -int 20

        if [ "$was_running" = true ]; then
          as_user /usr/bin/open -gja Amphetamine
          for _ in {1..50}; do
            /usr/bin/pgrep -xu "$user_id" Amphetamine >/dev/null && break
            /bin/sleep 0.1
          done

          if ! /usr/bin/pgrep -xu "$user_id" Amphetamine >/dev/null; then
            echo "Amphetamine did not relaunch in time" >&2
            exit 1
          fi

          if [ "$session_was_active" = true ]; then
            as_user /usr/bin/osascript -e 'tell application "Amphetamine" to start new session'
          fi
        fi
      fi
    )
  '';
}
