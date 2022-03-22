# ModSettings
A mod that adds a settings menu for modders to add their own settings in - with a filter to find certain ones easily.

<hr>

# Modder's Guide

Use these functions in an UI script which receives the `Before` UI Callback.

## Normal Settings
```cs
void function AddConVarSetting( string conVar, string displayName, string modName, string type = "" )
```
Adds a setting to the menu.

### Parameters
- `conVar` - the ConVar to change.
- `displayName` - the text to display as the label for the setting.
- `modName` - the category. Change this when adding a new setting to separate the categories.
- `type` - the type of the ConVar - can be: `float`, `float2`, `float3`/`vector` or `int`.
### Example
```cs
AddConVarSetting("ns_private_match_countdown_length", "Private Match Countdown Duration", "Northstar - Private Match", "float")
```

## Enum Settings

```cs
void function AddConVarSettingEnum( string conVar, string displayName, string modName, array<string> values )
```
Adds an enum setting to the menu. 

### Parameters
- `conVar` - the ConVar to change.
- `displayName` - the text to display as the label for the setting.
- `modName` - the category. Change this when adding a new setting to separate the categories.
- `values` - the labels for the values in the enum. The ConVar will be set to the index of the value in the array.

### Example 
```cs
// The array is set so that No is in the 0th index and Yes is in the 1st.
// The mod will set ns_should_return_to_lobby to 0 when No is selected and to 1 when Yes is selected.
// The mod will let the player switch between values using the arrow keys instead of typing the value in.
AddConVarSettingEnum("ns_should_return_to_lobby", "Return To Lobby After Match End", "Northstar - Server", [ "No", "Yes" ])
```
