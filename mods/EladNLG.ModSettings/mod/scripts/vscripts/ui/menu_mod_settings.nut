untyped
global function AddModSettingsMenu
global function AddConVarSetting
global function AddConVarSettingEnum

const int BUTTONS_PER_PAGE = 8
const string SETTING_ITEM_TEXT = "                        " // this is long enough to be the same size as the textentry field

struct ConVarData {
	string displayName
	string conVar
	string modName
	string type
	bool isModName = false
	bool isEmptySpace = false
	bool isEnumSetting = false
	array<string> values
	var customMenu
	bool hasCustomMenu = false
}

struct {
	var menu
	int scrollOffset = 0
	bool updatingList = false

	array<ConVarData> conVarList
	// if people use searches - i hate them but it'll do :)
	array<ConVarData> filteredList
	string filterText = ""
	table< int, int > enumRealValues
	array<var> modPanels
	table settingsTable
} file

struct {
	int deltaX = 0
	int deltaY = 0
} mouseDeltaBuffer

void function AddModSettingsMenu()
{
	AddMenu( "ModSettings", $"resource/ui/menus/mod_settings.menu", InitModMenu )
}

void function InitModMenu()
{
	file.menu = GetMenu( "ModSettings" )
	//DumpStack(2)
	AddMenuFooterOption( file.menu, BUTTON_B, "#B_BUTTON_BACK", "#BACK" )

	/////////////////////////////
	// BASE NORTHSTAR SETTINGS //
	/////////////////////////////
	//ConVarData test
	//test.displayName = "Base Northstar Settings"
	//TestString(test)
	//printt("Testarr len", test.displayName)

	//file.settingsTable = NSLoadFile( "Mod Settings", "settings" )
	try
	{
		file.settingsTable = expect table( compilestring( "return NSLoadFile( \"Mod Settings\", \"settings\" )" )() )
		print("USING MY PR :D")
	}
	catch (ex)
	{
		print("NOT USING MY PR D:")
	}

	foreach (string key, var value in file.settingsTable)
	{
		printt(key, expect string( value ))
		SetConVarString(key, expect string( value ))
	}
	// most of these are overrided in the cfg, maybe ask bob to remove the cfg stuff from there?
	// at the same time, might fuck with dedis so idk.
	// these are pretty long too, might need to e x t e n d the settings menu
	AddConVarSettingEnum("ns_private_match_only_host_can_change_settings", "#NS_PRIVATE_MATCH_HOST_CHANGE_SETTINGS", "#NS_PRIVATE_MATCH_TITLE", [ "#MOD_SETTING_NO", "#MOD_SETTING_YES" ])
	AddConVarSettingEnum("ns_private_match_only_host_can_start", "#NS_PRIVATE_MATCH_HOST_CAN_START", "#NS_PRIVATE_MATCH_TITLE", [ "#MOD_SETTING_NO", "#MOD_SETTING_YES" ])
	// fixed, from 'ns_private_match_only_host_can_change_settings' to 'ns_private_match_only_host_can_start'
	AddConVarSetting("ns_private_match_countdown_length", "#NS_PRIVATE_MATCH_COUNTDOWN_DURATION", "#NS_PRIVATE_MATCH_TITLE", "float")
	AddConVarSettingEnum("ns_private_match_only_host_can_change_settings", "#NS_SERVER_MAX_PLAYERS", "#NS_SERVER_TITLE", [ "#MOD_SETTING_NO", "#MOD_SETTING_YES" ])
	AddConVarSettingEnum("ns_should_log_unknown_clientcommands", "#NS_SERVER_LOG_UNKNOWN_COMMANDS", "#NS_SERVER_TITLE", [ "#MOD_SETTING_NO", "#MOD_SETTING_YES" ])
	AddConVarSetting("ns_disallowed_tacticals", "#NS_SERVER_DISALLOWED_TACTICALS", "#NS_SERVER_TITLE")
	AddConVarSetting("ns_disallowed_tactical_replacement", "#NS_SERVER_REPLACEMENT_TACTICAL", "#NS_SERVER_TITLE")
	AddConVarSetting("ns_disallowed_weapons", "#NS_SERVER_DISALLOWED_WEAPONS", "#NS_SERVER_TITLE")
	AddConVarSetting("ns_disallowed_weapon_primary_replacement", "#NS_SERVER_REPLACEMENT_WEAPON", "#NS_SERVER_TITLE")
	AddConVarSettingEnum("ns_should_return_to_lobby", "#NS_SERVER_RETURN_TO_LOBBY", "#NS_SERVER_TITLE", [ "#MOD_SETTING_NO", "#MOD_SETTING_YES" ])

	// Nuke weird rui on filter switch :D
	//RuiSetString( Hud_GetRui( Hud_GetChild( file.menu, "SwtBtnShowFilter")), "buttonText", "")

	file.modPanels = GetElementsByClassname( file.menu, "ModButton" )

	AddMenuEventHandler( file.menu, eUIEvent.MENU_OPEN, OnModMenuOpened )
	AddMenuEventHandler( file.menu, eUIEvent.MENU_CLOSE, OnModMenuClosed )

	int len = file.modPanels.len()
	print(len)
	for (int i = 0; i < len; i++)
	{

		//AddButtonEventHandler( button, UIE_CHANGE, OnSettingButtonPressed  )
		// get panel
		var panel = file.modPanels[i]

		// reset to default nav
		var child = Hud_GetChild( panel, "BtnMod" )


		child.SetNavUp( Hud_GetChild( file.modPanels[ GetIndex( i - 1, len ) ], "BtnMod" ) )
		child.SetNavDown( Hud_GetChild( file.modPanels[ GetIndex( i + 1, len ) ], "BtnMod" ) )

		// Enum button nav
		child = Hud_GetChild( panel, "EnumSelectButton" )
		Hud_DialogList_AddListItem( child, SETTING_ITEM_TEXT, "main" )
		Hud_DialogList_AddListItem( child, SETTING_ITEM_TEXT, "next" )
		Hud_DialogList_AddListItem( child, SETTING_ITEM_TEXT, "prev" )

		child.SetNavUp( Hud_GetChild( file.modPanels[ GetIndex( i - 1, len ) ], "EnumSelectButton" ) )
		child.SetNavDown( Hud_GetChild( file.modPanels[ GetIndex( i + 1, len ) ], "EnumSelectButton" ) )
		Hud_AddEventHandler( child, UIE_CLICK, UpdateEnumSetting )

		// reset button nav

		child = Hud_GetChild( panel, "ResetModToDefault" )

		child.SetNavUp( Hud_GetChild( file.modPanels[ GetIndex( i - 1, len ) ], "ResetModToDefault" ) )
		child.SetNavDown( Hud_GetChild( file.modPanels[ GetIndex( i + 1, len ) ], "ResetModToDefault" ) )

		Hud_AddEventHandler( child, UIE_CLICK, ResetConVar )

		// text field nav
		child = Hud_GetChild( panel, "TextEntrySetting" )

		//
		Hud_AddEventHandler( child, UIE_LOSE_FOCUS, SendTextPanelChanges )

		child.SetNavUp( Hud_GetChild( file.modPanels[ GetIndex( i - 1, len ) ], "TextEntrySetting" ) )
		child.SetNavDown( Hud_GetChild( file.modPanels[ GetIndex( i + 1, len ) ], "TextEntrySetting" ) )
	}

	//Hud_AddEventHandler( Hud_GetChild( file.menu, "BtnModsSearch" ), UIE_LOSE_FOCUS, OnFilterTextPanelChanged )
	Hud_AddEventHandler( Hud_GetChild( file.menu, "BtnFiltersClear" ), UIE_CLICK, OnClearButtonPressed )
	// mouse delta
	AddMouseMovementCaptureHandler( file.menu, UpdateMouseDeltaBuffer )

	thread SearchBarUpdate()
}

void function TestString(ConVarData test)
{
	test.displayName = "test"
}

void function SearchBarUpdate()
{
	while (true)
	{
		if (file.filterText != Hud_GetUTF8Text( Hud_GetChild( file.menu, "BtnModsSearch" ) ) )
		{
			file.filterText = Hud_GetUTF8Text( Hud_GetChild( file.menu, "BtnModsSearch" ) )
			OnFiltersChange(0)
		}
		WaitFrame()
	}
}

int function GetIndex( int index, int length )
{
	if (index < 0)
		return (length - 1) - (-index - 1) % length
	return index % length
}

void function ResetConVar( var button )
{
	ConVarData conVar = file.filteredList[ int ( Hud_GetScriptID( Hud_GetParent( button ) ) ) + file.scrollOffset ]

	if (conVar.isModName)
	{
		ShowAreYouSureDialog( "#ARE_YOU_SURE", ResetAllConVarsForModEventHandler( conVar.modName ), "#WILL_RESET_ALL_SETTINGS"  )
	}
	else ShowAreYouSureDialog( "#ARE_YOU_SURE", ResetConVarEventHandler( int ( Hud_GetScriptID( Hud_GetParent( button ) ) ) + file.scrollOffset ), Localize( "#WILL_RESET_SETTING", conVar.displayName )  )
}

void function ShowAreYouSureDialog( string header, void functionref() func, string details )
{
	DialogData dialogData
	dialogData.header = header
	dialogData.message = details

	AddDialogButton( dialogData, "#NO" )
	AddDialogButton( dialogData, "#YES", func )

	AddDialogFooter( dialogData, "#A_BUTTON_SELECT" )
	AddDialogFooter( dialogData, "#B_BUTTON_BACK" )

	OpenDialog( dialogData )
	SetBlurEnabled( false )
}

void functionref() function ResetAllConVarsForModEventHandler( string modName )
{
	return void function() : ( modName )
	{
		for (int i = 0; i < file.conVarList.len(); i++)
		{
			ConVarData c = file.conVarList[i]
			if (c.modName != modName || c.isModName || c.isEmptySpace) continue
			SetConVarToDefault(c.conVar)

			int index = file.filteredList.find(c)
			if (file.filteredList.find(c) < 0) continue

			if (min( BUTTONS_PER_PAGE, max(0, index - file.scrollOffset)) == index - file.scrollOffset)
				Hud_SetText(Hud_GetChild( file.modPanels[i - file.scrollOffset], "TextEntrySetting"), c.isEnumSetting ? c.values[GetConVarInt(c.conVar)] : GetConVarString(c.conVar))
		}
	}
}

void functionref() function ResetConVarEventHandler( int modIndex )
{
	return void function() : ( modIndex )
	{
		ConVarData c = file.filteredList[modIndex]
		SetConVarToDefault(c.conVar)
		if (min( BUTTONS_PER_PAGE, max(0, modIndex - file.scrollOffset)) == modIndex - file.scrollOffset)
			Hud_SetText(Hud_GetChild( file.modPanels[modIndex - file.scrollOffset], "TextEntrySetting"), c.isEnumSetting ? c.values[GetConVarInt(c.conVar)] : GetConVarString(c.conVar))
	}
}

////////////////////////
// slider
////////////////////////
void function UpdateMouseDeltaBuffer(int x, int y)
{
	mouseDeltaBuffer.deltaX += x
	mouseDeltaBuffer.deltaY += y

	SliderBarUpdate()
}

void function FlushMouseDeltaBuffer()
{
	mouseDeltaBuffer.deltaX = 0
	mouseDeltaBuffer.deltaY = 0
}


void function SliderBarUpdate()
{
	if ( file.filteredList.len() <= 15 )
	{
		FlushMouseDeltaBuffer()
		return
	}

	var sliderButton = Hud_GetChild( file.menu , "BtnModListSlider" )
	var sliderPanel = Hud_GetChild( file.menu , "BtnModListSliderPanel" )
	var movementCapture = Hud_GetChild( file.menu , "MouseMovementCapture" )

	Hud_SetFocused(sliderButton)

	float minYPos = -40.0 * (GetScreenSize()[1] / 1080.0)
	float maxHeight = 320.0  * (GetScreenSize()[1] / 1080.0)
	float maxYPos = minYPos - (maxHeight - Hud_GetHeight( sliderPanel ))
	float useableSpace = (maxHeight - Hud_GetHeight( sliderPanel ))

	float jump = minYPos - (useableSpace / ( float( file.filteredList.len())))

	// got local from official respaw scripts, without untyped throws an error
	local pos =	Hud_GetPos(sliderButton)[1]
	local newPos = pos - mouseDeltaBuffer.deltaY
	FlushMouseDeltaBuffer()

	if ( newPos < maxYPos ) newPos = maxYPos
	if ( newPos > minYPos ) newPos = minYPos

	Hud_SetPos( sliderButton , 2, newPos )
	Hud_SetPos( sliderPanel , 2, newPos )
	Hud_SetPos( movementCapture , 2, newPos )

	file.scrollOffset = -int( ( (newPos - minYPos) / useableSpace ) * ( file.filteredList.len() - BUTTONS_PER_PAGE) )
	UpdateList()
}

void function UpdateListSliderHeight()
{
	var sliderButton = Hud_GetChild( file.menu , "BtnModListSlider" )
	var sliderPanel = Hud_GetChild( file.menu , "BtnModListSliderPanel" )
	var movementCapture = Hud_GetChild( file.menu , "MouseMovementCapture" )

	float mods = float ( file.filteredList.len() )

	float maxHeight = 320.0 * (GetScreenSize()[1] / 1080.0)
	float minHeight = 80.0 * (GetScreenSize()[1] / 1080.0)

	float height = maxHeight * ( float( BUTTONS_PER_PAGE ) / mods )

	if ( height > maxHeight ) height = maxHeight
	if ( height < minHeight ) height = minHeight

	Hud_SetHeight( sliderButton , height )
	Hud_SetHeight( sliderPanel , height )
	Hud_SetHeight( movementCapture , height )
}

void function UpdateList()
{
	Hud_SetFocused(Hud_GetChild(file.menu, "BtnModsSearch"))
	file.updatingList = true

	array<ConVarData> filteredList = []

	string lastModNameInFilter = ""
	ConVarData curModConVar = file.conVarList[0]
	for (int i = 0; i < file.conVarList.len(); i++)
	{
		ConVarData c = file.conVarList[i]
		if (c.isModName) {
			curModConVar = c
		}
		string displayName = c.isModName ? c.modName : c.displayName

		if (c.isModName) printt(displayName, "|", displayName.tolower().find(file.filterText.tolower()))
		if (file.filterText == "" || displayName.tolower().find(file.filterText.tolower()) != null)
		{
			if (c.isModName) {
				filteredList.extend(GetAllVarsInMod(i))
				//print(i + " | " + (i + GetAllVarsInMod(i).len() - 1))
				i += GetAllVarsInMod(i).len() - 1// -1 because we already incremented i
				// we don't want to pass over the mod's convars since we're already including all of them =-=
			}
			else
			{
				if (c.modName != lastModNameInFilter)
				{
					filteredList.append(curModConVar)
					filteredList.append(c)
					lastModNameInFilter = c.modName
				}
				else filteredList.append(c)
			}
		}
	}

	file.filteredList = filteredList

	int j = int( min( file.filteredList.len() + file.scrollOffset, 15 ) )

	for ( int i = 0; i < BUTTONS_PER_PAGE; i++ )
	{
		Hud_SetEnabled( file.modPanels[ i ], i < j )
		Hud_SetVisible( file.modPanels[ i ], i < j )

		if (i < j)
			SetModMenuNameText( file.modPanels[ i ] )
	}
	file.updatingList = false
}

array<ConVarData> function GetAllVarsInMod(int modNameIndex)
{
	array<ConVarData> vars = []
	for (int i = 0; i < file.conVarList.len(); i++)
	{
		ConVarData c = file.conVarList[i]
		if (c.modName == file.conVarList[modNameIndex]	.modName)
		{
			vars.append(file.conVarList[i])
			//printt(file.conVarList[i].conVar + " is in mod " + file.conVarList[i].modName)
		}
	}
	ConVarData empty
	empty.isEmptySpace = true
	vars.append(empty)
	return vars
}

void function SetModMenuNameText( var button )
{
	ConVarData conVar = file.filteredList[ int ( Hud_GetScriptID( button ) ) + file.scrollOffset ]
	if (conVar.isEmptySpace)
	{
		Hud_SetVisible( file.modPanels[ int ( Hud_GetScriptID( button ) ) ], false )
		return
	}

	var panel = file.modPanels[ int ( Hud_GetScriptID( button ) ) ]

	var label = Hud_GetChild( panel, "BtnMod" )
	var textField = Hud_GetChild( panel, "TextEntrySetting" )
	var enumButton = Hud_GetChild( panel, "EnumSelectButton" )
	var resetButton = Hud_GetChild( panel, "ResetModToDefault" )

	// should be localisation at some point
	Hud_SetVisible(textField, !conVar.isModName)
	Hud_SetVisible(Hud_GetChild(panel, "BottomLine"), conVar.isModName)
	Hud_SetVisible( enumButton, !conVar.isModName && conVar.isEnumSetting )
	float scaleX = GetScreenSize()[1] / 1080.0
	float scaleY = GetScreenSize()[1] / 1080.0
	if ( conVar.isModName ) {
		Hud_SetText( label, conVar.modName )
		Hud_SetText( resetButton, "#RESET_ALL" )
		Hud_SetSize( resetButton, int(120 * scaleX), int(40 * scaleY) )
		Hud_SetPos( label, 0, 0 )
		Hud_SetSize( label, int(scaleX * (800 - 120 - 85)), int(scaleY * 40) )
		Hud_SetSize( Hud_GetChild(panel, "OpenCustomMenu"), int(85 * scaleX), int(40 * scaleY) )
		Hud_SetVisible( Hud_GetChild(panel, "OpenCustomMenu"), conVar.hasCustomMenu )
	}
	else {
		Hud_SetText( label, conVar.displayName )
		Hud_SetText( textField, conVar.isEnumSetting ? conVar.values[GetConVarInt(conVar.conVar)] : GetConVarString(conVar.conVar))
		Hud_SetPos( label, int(scaleX * 25), 0 )
		Hud_SetText( resetButton, "#RESET" )
		Hud_SetSize( resetButton, int(scaleX * 90), int(scaleY * 40) )
		Hud_SetSize( label, int(scaleX * (375 + 85)), int(scaleY * 40) )
		Hud_SetSize( Hud_GetChild(panel, "OpenCustomMenu"), 0, 40 )
	}
}

void function OnScrollDown( var button )
{
	if ( file.filteredList.len() <= BUTTONS_PER_PAGE ) return
	file.scrollOffset += 5
	if (file.scrollOffset + BUTTONS_PER_PAGE > file.filteredList.len()) {
		file.scrollOffset = file.filteredList.len() - BUTTONS_PER_PAGE
	}
	UpdateList()
	UpdateListSliderPosition()
}

void function OnScrollUp( var button )
{
	file.scrollOffset -= 5
	if (file.scrollOffset < 0) {
		file.scrollOffset = 0
	}
	UpdateList()
	UpdateListSliderPosition()
}

void function UpdateListSliderPosition()
{
	var sliderButton = Hud_GetChild( file.menu , "BtnModListSlider" )
	var sliderPanel = Hud_GetChild( file.menu , "BtnModListSliderPanel" )
	var movementCapture = Hud_GetChild( file.menu , "MouseMovementCapture" )

	float mods = float ( file.filteredList.len() )

	float minYPos = -40.0 * (GetScreenSize()[1] / 1080.0)
	float useableSpace = (320.0 * (GetScreenSize()[1] / 1080.0) - Hud_GetHeight( sliderPanel ))

	float jump = minYPos - (useableSpace / ( mods - float( BUTTONS_PER_PAGE ) ) * file.scrollOffset)

	//jump = jump * (GetScreenSize()[1] / 1080.0)

	if ( jump > minYPos ) jump = minYPos

	Hud_SetPos( sliderButton , 2, jump )
	Hud_SetPos( sliderPanel , 2, jump )
	Hud_SetPos( movementCapture , 2, jump )
}

void function OnModMenuOpened()
{
	file.scrollOffset = 0
	file.filterText = ""

	RegisterButtonPressedCallback(MOUSE_WHEEL_UP , OnScrollUp)
	RegisterButtonPressedCallback(MOUSE_WHEEL_DOWN , OnScrollDown)
	RegisterButtonPressedCallback(KEY_F1, ToggleHideMenu)

	SetBlurEnabled( false )
	UI_SetPresentationType( ePresentationType.INACTIVE )
	Hud_SetVisible( file.menu, true )
	isVisible = true

	OnFiltersChange(0)
}

void function OnFiltersChange( var n )
{
	file.scrollOffset = 0

	//HideAllButtons()

	//RefreshModsArray()

	UpdateList()

	UpdateListSliderHeight()
}

bool isVisible = true
void function ToggleHideMenu( var button )
{
	Hud_SetVisible( file.menu, !isVisible )
	isVisible = !isVisible
}

void function OnModMenuClosed()
{
	try
	{
		DeregisterButtonPressedCallback(MOUSE_WHEEL_UP , OnScrollUp)
		DeregisterButtonPressedCallback(MOUSE_WHEEL_DOWN , OnScrollDown)
		DeregisterButtonPressedCallback(KEY_F1 , ToggleHideMenu)
	}
	catch ( ex ) {}

	UI_SetPresentationType( ePresentationType.DEFAULT )
	SetBlurEnabled( !IsMultiplayer() )
	Hud_SetVisible( file.menu, false )
}

void function AddConVarSetting( string conVar, string displayName, string modName, string type = "" )
{
	if (file.conVarList.len() < 1)
	{
		ConVarData modData

		modData.modName = modName
		modData.displayName = modName
		modData.isModName = true

		file.conVarList.append(modData)
	}
	else if (modName != file.conVarList[file.conVarList.len() - 1].modName)
	{
		ConVarData space
		space.isEmptySpace = true
		file.conVarList.append(space)

		ConVarData modData

		modData.modName = modName
		modData.displayName = modName
		modData.isModName = true

		file.conVarList.append(modData)
	}

	ConVarData data

	data.modName = modName
	data.conVar = conVar
	data.displayName = displayName
	data.type = type

	file.conVarList.append(data)
}

void function AddConVarSettingEnum( string conVar, string displayName, string modName, array<string> values )
{
	if (file.conVarList.len() < 1)
	{
		ConVarData modData

		modData.modName = modName
		modData.isModName = true

		file.conVarList.append(modData)
	}
	else if (modName != file.conVarList[file.conVarList.len() - 1].modName)
	{
		ConVarData space
		space.isEmptySpace = true
		file.conVarList.append(space)

		ConVarData modData

		modData.modName = modName
		modData.isModName = true

		file.conVarList.append(modData)
	}

	ConVarData data

	data.modName = modName
	data.conVar = conVar
	data.displayName = displayName
	data.values = values
	data.isEnumSetting = true

	file.conVarList.append(data)
}

void function SetCategoryCustomMenu( string category, var menu )
{
	foreach (ConVarData c in file.conVarList)
	{
		if (!c.isModName) continue
		if (c.isEmptySpace) continue
		if (c.modName != category) continue

		c.customMenu = menu
		c.hasCustomMenu = true
		break
	}
}

void function SendTextPanelChanges( var textPanel )
{
	ConVarData c = file.filteredList[ int( Hud_GetScriptID( Hud_GetParent( textPanel ) ) ) + file.scrollOffset ]
	if (c.conVar == "") return
	// enums don't need to do this
	if ( !c.isEnumSetting )
	{
		string newSetting = Hud_GetUTF8Text( textPanel )

		switch (c.type)
		{
			case "int":
				try
				{
					SetConVarInt(c.conVar, newSetting.tointeger())
					file.settingsTable[c.conVar] <- newSetting
				}
				catch (ex)
				{
					ThrowInvalidValue("This setting is an integer, and only accepts whole numbers.")
					Hud_SetText( textPanel, GetConVarString(c.conVar))
				}
			case "bool":
				if (newSetting != "0" && newSetting != "1")
				{
					ThrowInvalidValue("This setting is a boolean, and only accepts values of 0 or 1.")

					// set back to previous value :)
					Hud_SetText( textPanel, GetConVarString(c.conVar))

					break
				}
				SetConVarBool(c.conVar, newSetting == "1")
				file.settingsTable[c.conVar] <- newSetting
				break
			case "float":
				try
				{
					SetConVarFloat(c.conVar, newSetting.tofloat())
					file.settingsTable[c.conVar] <- newSetting
				}
				catch (ex)
				{
					printt(ex)
					ThrowInvalidValue("This setting is a float, and only accepts a number - we could not parse this!\n\n(Use \".\" for the floating point, not \",\".)")
				}
				break
			case "float2":
				try
				{
					array<string> split = split( newSetting, " " )
					if (split.len() != 2)
					{
						ThrowInvalidValue("This setting is a float2, and only accepts a pair of numbers - you put in " + split.len() + "!")
						Hud_SetText( textPanel, GetConVarString(c.conVar))
						break
					}
					vector settingTest = <split[0].tofloat(), split[1].tofloat(), 0>

					SetConVarString(c.conVar, newSetting)
					file.settingsTable[c.conVar] <- newSetting
				}
				catch (ex)
				{
					ThrowInvalidValue("This setting is a float2, and only accepts a pair of numbers - you put something we could not parse!\n\n(Use \".\" for the floating point, not \",\".)")
					Hud_SetText( textPanel, GetConVarString(c.conVar))
				}
				break
			// idk sometimes it's called Float3 most of the time it's called vector, I am not complaining.
			case "vector":
			case "float3":
				try
				{
					array<string> split = split( newSetting, " " )
					if (split.len() != 3)
					{
						ThrowInvalidValue("This setting is a float3, and only accepts a trio of numbers - you put in " + split.len() + "!")
						Hud_SetText( textPanel, GetConVarString(c.conVar))
						break
					}
					vector settingTest = <split[0].tofloat(), split[1].tofloat(), 0>

					SetConVarString(c.conVar, newSetting)
					file.settingsTable[c.conVar] <- newSetting
				}
				catch (ex)
				{
					ThrowInvalidValue("This setting is a float3, and only accepts a trio of numbers - you put something we could not parse!\n\n(Use \".\" for the floating point, not \",\".)")
					Hud_SetText( textPanel, GetConVarString(c.conVar))
				}
				break
			default:
				SetConVarString(c.conVar, newSetting)
				file.settingsTable[c.conVar] <- newSetting
				break;
		}
		try
		{
			compilestring( "return function ( t ) : () { NSSaveFile( \"Mod Settings\", \"settings\", t ) }" )() ( file.settingsTable )
		}
		catch (ex)
		{

		}
	}
	else Hud_SetText( textPanel, c.values[GetConVarInt(c.conVar)])
}

void function ThrowInvalidValue( string desc )
{
	DialogData dialogData
	dialogData.header = "Invalid Value"
	dialogData.image = $"ui/menu/common/dialog_error"
	dialogData.message = desc
	AddDialogButton( dialogData, "#OK" )
	OpenDialog( dialogData )
	SetBlurEnabled( false )
}

void function UpdateEnumSetting( var button )
{
	int scriptId = int( Hud_GetScriptID( Hud_GetParent( button ) ) )
	ConVarData c = file.filteredList[ scriptId + file.scrollOffset ]

	var panel = file.modPanels[scriptId]

	var textPanel = Hud_GetChild( panel, "TextEntrySetting")

	string selectionVal = Hud_GetDialogListSelectionValue( button )

	if ( selectionVal == "main" )
		return

	int enumVal = GetConVarInt(c.conVar)
	if ( selectionVal == "next" ) // enum val += 1
			enumVal = ( enumVal + 1 ) % c.values.len()
	else // enum val -= 1
	{
		enumVal--
		if ( enumVal == -1 )
			enumVal = c.values.len() - 1
	}

	SetConVarInt(c.conVar, enumVal)
	Hud_SetText( textPanel, c.values[ enumVal ] )

	Hud_SetDialogListSelectionValue( button, "main" )
}

void function OnClearButtonPressed( var button )
{
	file.filterText = ""

	Hud_SetText( Hud_GetChild( file.menu, "BtnModsSearch" ), "" )

	OnFiltersChange(0)
}