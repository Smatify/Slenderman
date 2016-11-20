/*__________________________________________________________________________________________________
| Slender Mod
|___________________________________________________________________________________________________
| Credits:
| xPaw    - For his NewSlender-Function (xPaw's Deathrun Manager)
| v3x     - For the get_msg_block - Fix
|___________________________________________________________________________________________________
| CVars:
| slender_light // (default: a) <changes the brightness of the map>
| slender_teleport_delay // (default: 7) <changes the delay between 2 teleports in seconds>
| slender_speed // (default: 85) <changes the speed of slender>
| slender_damage // (default: 15) <specifies the amount of damage when you a next to slender>
| slender_pages // (default : 8) <specifies the amount of pages generated each round>
| slender_sky // (default : black) <specifies the name of the sky>
|___________________________________________________________________________________________________
| Commands:
| reloadlights // reload the lightsettings
| say /editor // Opens the spawnmenu
|___________________________________________________________________________________________________
| Made by:
| Smatify - https://smatify.com
|___________________________________________________________________________________________________
| Changelog:
| 
| Version 1.0.8
|      - Fixed "One-Sprite-too-much"-Bug
|      - Added function so game gets restarted after Slender disconnects
|
| Version 1.0.7
|      - Added Multi-Language
|
| Version 1.0.6.3
|      - Added Boolean to prevent multiple spawning of Editor Sprites
|      - Fixed get_msg_block - Bug
|  
| Version 1.0.6.2
|      - Fixed "Invalid message id"-Bug
|
| Version 1.0.6.1
|     - Optimized Code
|
| Version 1.0.6
|      - Added Spawn Editor
|
| Version 1.0.5 
|      - Added Team Manager
|      - Added Knife for CTs
| 
| Version 1.0.4.1
|      - Removed unused ressources.
|
| Version 1.0.4
|      - Rearranged code in fw_PlayerPreThink
| 
| Version 1.0.3
|      - Edited Touch Hook.
|      - Added new Method of getting Slender near player (Thanks to pokemonmaster).
|      - Added is_in_viewcone to make damage only if Slender is visible on your screen.
|      - Renamed some functions.
|      - Replaced looped Task with Player_PreThink.
|      - Removed cur_weapon Event as it isn't required.
|      - Added cvar "slender_sky"
|      - Removed HamTakeDamage and replaced with set_user_health so you can escape easier.
|  
| Version 1.0.2
|      - Changed teleport command to flashlight Command
|      - Changed from find_ent_in_sphere to is_in_viewcone
|      - Some Code improvements 
|
| Version 1.0.1
|      - Added some commands
|      - Added some help for T
|
| Version 1.0.0
|      - First Release
|_________________________________________________________________________________________________*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>

#define PLUGIN "Slender Mod"
#define VERSION "1.0.8"
#define AUTHOR "Smatify"

#define SLENDER_RADIUS 250.0
#define SLENDER_DELAY 0.32
#define SLENDER_L_DELAY 15.0
#define SLENDER_EDITOR_ACCESS ADMIN_BAN


#define SetAlive(%1) ( gBitAlive |= (1<<%1) ) 
#define SetDead(%1) ( gBitAlive &= ~(1<<%1) ) 
#define IsAlive(%1) ( gBitAlive & (1<<%1) ) 

#define m_iVGUI         510
#define m_fGameHUDInitialized   349


/* CVars */

new cvar_light,cvar_damage,cvar_speed,cvar_pages,cvar_delay,cvar_sky

/* Constants */

new const g_szGamePrefix[]            =    "[SlenderMod]"

stock const FIRST_JOIN_MSG[]          =   "#Team_Select"
stock const FIRST_JOIN_MSG_SPEC[]    =   "#Team_Select_Spect"
stock const INGAME_JOIN_MSG[]       =   "#IG_Team_Select"
stock const INGAME_JOIN_MSG_SPEC[]    =   "#IG_Team_Select_Spect"
stock const VGUI_JOIN_TEAM_NUM       =   2
const iMaxLen                   =    sizeof(INGAME_JOIN_MSG_SPEC);

new CTCount,TCount,g_MsgShowMenu

/* Sounds */
new const g_szTeleportSound[]      = "slenderman/bassdrum.wav"
new const g_szSlenderLaugh[]       = "slenderman/slenderlaugh.wav"

/* Model */
new const g_szSlenderModel[]       = "models/player/slenderman/slenderman.mdl"

/* Sprite */
new const g_szPageSprite[]         = "sprites/slenderpage.spr"
new const g_szEditorSprite[]	   = "sprites/editorsprite.spr"

/* Floats */

new Float:g_flLastTeleportTime[33]
new Float:g_flSlayDelay[33]
new Float:g_flLaughDelay[33]

/* Integer */

new g_iPages,g_iLastTerr,gBitAlive,g_iSlenderId

/* Booleans */

new g_bAllPagesShow

/* Precache */

public plugin_precache()
{
	precache_sound(g_szTeleportSound)
	precache_sound(g_szSlenderLaugh)
	precache_model(g_szSlenderModel)
	precache_model(g_szPageSprite)
	precache_model(g_szEditorSprite)
}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("slender_version", VERSION, FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	register_dictionary("slender.txt")
	
	/* Register Stuff */
	
	RegisterHam(Ham_Spawn,                     	"player", "fw_Spawn", 1)
	RegisterHam(Ham_Player_PreThink,             "player", "fw_PlayerPreThink")
	
	register_forward( FM_Spawn,                  "fw_SpawnPost",1)
	register_forward( FM_Touch,                  "fw_Touch")
	register_forward( FM_GetGameDescription,     "GameDesc")
	
	/* Events */
	
	register_event("DeathMsg",                   "ev_Death", "a")
	register_event("HLTV",                       "ev_HLTV", "a", "1=0", "2=0")
	
	/* Touch */
	
	register_touch("slenderpage",               	"player","player_touch_slenderpage")
	
	/* Messages */
	
	register_message(get_user_msgid("ShowMenu"), "message_ShowMenu")
	register_message(get_user_msgid("VGUIMenu"), "message_VGUIMenu")
	
	
	/* Commands */
	
	register_clcmd("reloadlights",               "ApplyEnvironment")
	
	register_clcmd("chooseteam",                 "show_team_menu")
	register_clcmd("jointeam",                   "jointeam")
	register_clcmd("joinclass",                  "jointeam")
	register_clcmd("say /editor",				 "origin_2_file_menu")
	
	register_impulse(100,                        "OnFlashLight")
	
	/* Cvars */
	
	cvar_light      = register_cvar               ("slender_light","a")
	cvar_delay      = register_cvar               ("slender_teleport_delay","7")
	cvar_speed      = register_cvar               ("slender_speed","85.0")
	cvar_damage     = register_cvar               ("slender_damage","1")
	cvar_pages      = register_cvar               ("slender_pages","8")
	cvar_sky        = register_cvar               ("slender_sky","black")
	
	/* Misc */
	g_MsgShowMenu = get_user_msgid("ShowMenu");
	ApplyEnvironment()
	
}

public client_disconnect(id)
{
	if(id == g_iSlenderId)
	{
		server_cmd("sv_restartround 1")
		g_iSlenderId = 0
	}
}

/* Fowards */

public fw_PlayerPreThink(id)
{
	if(!IsAlive(id) 
		|| cs_get_user_team(id) != CS_TEAM_CT 
	|| !is_user_connected(id) 
	|| !is_user_alive(id) 
	|| !is_user_connected(g_iSlenderId) 
	|| !is_user_alive(g_iSlenderId)) 
	return; 
	
	new Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	
	if(ExecuteHam(Ham_FVisible, g_iSlenderId, id) 
	&& entity_range(g_iSlenderId, id) <= SLENDER_RADIUS 
	&& is_in_viewcone(g_iSlenderId,origin) 
	&& get_gametime() > g_flSlayDelay[id] ) 
	{
		set_user_health(id, get_user_health(id) - get_pcvar_num(cvar_damage))
		g_flSlayDelay[id] = get_gametime() + SLENDER_DELAY
		if(get_gametime() > g_flLaughDelay[id])
		{
			emit_sound( id, CHAN_ITEM, g_szSlenderLaugh, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
			g_flLaughDelay[id] = get_gametime() + SLENDER_L_DELAY
		}
	}
}

public fw_SpawnPost( iEntity )
{
	new szClassname[ 32 ];
	pev(iEntity,pev_classname,szClassname,charsmax( szClassname ) );
	
	static const g_szObjectives[ ][ ] = 
	{
		"func_bomb_target",
		"info_bomb_target",
		"hostage_entity",
		"monster_scientist",
		"func_hostage_rescue",
		"info_hostage_rescue",
		"info_vip_start",
		"func_vip_safetyzone",
		"func_escapezone"
	}  
	
	for(new i=0;i<sizeof g_szObjectives;i++)
	{
		if(equali(szClassname,g_szObjectives[i]))
		{
			remove_entity( iEntity );
			break;
		}
	}
}

public fw_Touch( ent , id )
{
	new g_MaxPlayers = get_maxplayers()
	
	static const models[][] =
	{
		"models/w_backpack.mdl",
		"models/w_flashbang.mdl",
		"models/w_hegrenade.mdl",
		"models/w_smokegrenade.mdl"
	}
	
	if (!(1 <= id <= g_MaxPlayers) || !pev_valid(ent) || !(pev(ent , pev_flags) & FL_ONGROUND))
		return FMRES_IGNORED;
	
	static szEntModel[32];
	pev(ent , pev_model , szEntModel , 31);
	
	return equal(szEntModel , models[random(sizeof(models))]) ? FMRES_IGNORED : FMRES_SUPERCEDE;
}
public fw_Spawn(id)
{
	if(is_user_alive(id))
	{
		SetAlive(id) 
		switch(cs_get_user_team(id))
		{
			case CS_TEAM_T    : set_task(0.1,"slenderstuff",id)
			case CS_TEAM_CT   : set_task(0.1,"humanstuff",id)
		}
	}
}
public ev_Death()
{
	new iAttacker = read_data(1)
	new id = read_data(2)
	SetDead(id)
	new user_name[33]
	get_user_name(id, user_name, charsmax(user_name))
	if(is_user_connected(id) && cs_get_user_team(id) == CS_TEAM_CT && is_user_connected(id) && cs_get_user_team(iAttacker) == CS_TEAM_T)
	{
		print_color(0, id, 0, "%L", LANG_PLAYER, "SLENDER_DEATH", g_szGamePrefix, user_name)
	}
}

public ev_HLTV(id) 
{
	g_iPages = 1
	new i, iPlayers[ 32 ], iNum, iPlayer;
	get_players( iPlayers, iNum, "c")
	
	if( iNum <= 1 )
		return PLUGIN_CONTINUE;
	
	for( i = 0; i < iNum; i++ ) 
	{
		iPlayer = iPlayers[ i ];
		if( cs_get_user_team( iPlayer ) == CS_TEAM_T )
		{
			cs_set_user_team( iPlayer, CS_TEAM_CT )
		}
	}
	
	new iRandomPlayer, CsTeams:iTeam;
	while( ( iRandomPlayer = iPlayers[ random_num( 0, iNum - 1 ) ] ) == g_iLastTerr ) { }
	
	g_iLastTerr = iRandomPlayer;
	
	iTeam = cs_get_user_team( iRandomPlayer );
	
	if( iTeam == CS_TEAM_T || iTeam == CS_TEAM_CT ) 
	{
		new szName[ 32 ];
		get_user_name( iRandomPlayer, szName, 31 );
		
		print_color(0,id,0, "%L", LANG_PLAYER, "SLENDER_CHOICE", g_szGamePrefix, szName)
		
		create_sprite(iRandomPlayer)
		g_iSlenderId = iRandomPlayer
		
		cs_set_user_team(iRandomPlayer, CS_TEAM_T);
	} 
	else 
	{
		ev_HLTV(id);
	}
	
	return PLUGIN_CONTINUE;
}

/* Gameplay Stuff */

public slenderstuff(id)
{
	strip_user_weapons(id);
	cs_set_user_money(id,0);
	cs_set_user_nvg(id,1)
	
	set_user_footsteps(id, 1)
	set_user_godmode(id, 1)
	
	engfunc(EngFunc_SetClientMaxspeed, id, get_pcvar_float(cvar_speed))
	
	cs_set_user_model(id, "slenderman")
	
}
public humanstuff(id)
{
	strip_user_weapons( id );
	give_item(id, "weapon_knife")
	cs_set_user_money( id, 0 );
	cs_set_user_nvg(id,0)
	
	set_user_footsteps(id, 0)
	set_user_godmode(id, 0)
	
	cs_set_user_model(id, "gsg9")
	
	set_hudmessage(255, 255, 255, -0.5, 0.5, 0, 6.0, 12.0, 0.1)
	show_hudmessage(id, "%L", LANG_PLAYER, "SLENDER_COLLECT", get_pcvar_num(cvar_pages))
	
}
public ApplyEnvironment()
{
	static light_cvar[3]
	get_pcvar_string(cvar_light,light_cvar,charsmax(light_cvar))
	set_lights(light_cvar)
	
	static sky_cvar[33]
	get_pcvar_string(cvar_sky,sky_cvar,charsmax(sky_cvar))
	
	set_cvar_string("sv_skyname",sky_cvar)
	
}
public OnFlashLight(id)
{
	switch(cs_get_user_team(id))
	{
		case CS_TEAM_T: TeleportPlayer(id)
		case CS_TEAM_CT: return PLUGIN_CONTINUE
	}
	return PLUGIN_HANDLED
}

public TeleportPlayer(id)
{
	if(!is_user_alive(id) || !is_user_connected(id) || cs_get_user_team(id) != CS_TEAM_T)
		return PLUGIN_HANDLED
	
	new Float:flGameTime = get_gametime();
	
	new iDelay = get_pcvar_num( cvar_delay );
	
	if( flGameTime - g_flLastTeleportTime[ id ] < iDelay )
	{
		print_color(id,id,0, "%L", LANG_PLAYER, "SLENDER_DELAY",g_szGamePrefix,iDelay)
		return PLUGIN_HANDLED
	}
	
	new vOldLocation[3], vNewLocation[3]
	
	get_user_origin( id, vOldLocation );
	get_user_origin( id, vNewLocation, 3 );
	
	emit_sound( 0, CHAN_ITEM, g_szTeleportSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
	
	vOldLocation[2] += 15;
	vNewLocation[0] += ( ( vNewLocation[0] - vOldLocation[0] > 0 ) ? -50 : 50 );
	vNewLocation[1] += ( ( vNewLocation[1] - vOldLocation[1] > 0 ) ? -50 : 50 );
	vNewLocation[2] += 40;         
	
	set_user_origin( id, vNewLocation );
	g_flLastTeleportTime[ id ] = get_gametime();
	
	new parm[5];
	parm[0] = id;
	parm[1] = vOldLocation[0];
	parm[2] = vOldLocation[1];
	parm[3] = vOldLocation[2];
	parm[4] = vNewLocation[2];
	
	set_task( 0.1, "CheckStuck", 1337 + id, parm, 5 );
	return PLUGIN_HANDLED
}

public CheckStuck(parm[])
{
	new id = parm[0]   
	
	new vOldLocation[3], vOrigin[3];
	
	vOldLocation[0] = parm[1];
	vOldLocation[1] = parm[2];
	vOldLocation[2] = parm[3];
	
	get_user_origin( id, vOrigin );
	
	if ( parm[4] == vOrigin[2] )
	{
		set_user_origin( id, vOldLocation );
	}
}

/* Misc */

public GameDesc( )
{ 
	new szVersName[64]
	formatex(szVersName,charsmax(szVersName),"SlenderMod %s by Smatify",VERSION)
	
	forward_return( FMV_STRING, szVersName ); 
	return FMRES_SUPERCEDE; 
}

/* Origin2File */
public origin_2_file_menu(id)
{
	new menu = menu_create("SlenderMod Spawn Editor","origin_2_file_handler")
	new save[64],show[64],remove[64]
	
	formatex(save, charsmax(save), "%L", LANG_PLAYER, "SLENDER_SPAWNSAVE")
	formatex(show, charsmax(show), "%L", LANG_PLAYER, "SLENDER_SPAWNSHOW")
	formatex(remove, charsmax(remove),"%L", LANG_PLAYER, "SLENDER_SPAWNREMOVE")

	menu_additem(menu,save,			"1",0);
	
	if(g_bAllPagesShow)
		menu_additem(menu,show, 	"2",1<<31);
	else
		menu_additem(menu,show,		"2",0)
	
	if(!g_bAllPagesShow)
		menu_additem(menu,remove,	"3",1<<31);
	else
		menu_additem(menu,remove,   "3",0)
	
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED
}
public origin_2_file_handler(id, menu, item)
{
	static filename[256]
	get_configsdir(filename,charsmax(filename))
	
	static map[32]
	get_mapname(map, charsmax(map))
	
	formatex(filename, charsmax(filename), "%s\slenderman\maps\%s.cfg",filename,map)
	
	new data[6], szName[64];
	new access, callback;
	menu_item_getinfo(menu, item, access, data,charsmax(data), szName,charsmax(szName), callback);
	new key = str_to_num(data);
	switch(key)
	{
		case 1:
		{	
			new iOrigin[3]
			get_user_origin(id, iOrigin, 0)
			
			new origincontent[256]
			formatex(origincontent, charsmax(origincontent), "%d %d %d", iOrigin[0],iOrigin[1],iOrigin[2])
			
			write_file(filename, origincontent)
		}
		case 2:
		{
			new lines = file_size(filename, 1);
			for (new line=0; line <=lines; line++)
			{
				static iOrigin[3][8]
				static Float:origin[3]
				static lineBuffer[256], len;
				read_file(filename, line, lineBuffer, charsmax(lineBuffer), len);
				
				parse(lineBuffer,iOrigin[0],7,iOrigin[1],7,iOrigin[2],7)
				
				origin[0] = str_to_float(iOrigin[0])
				origin[1] = str_to_float(iOrigin[1])
				origin[2] = str_to_float(iOrigin[2])
				
				new ent = create_entity("env_sprite")
				
				entity_set_string(ent, EV_SZ_classname, "editorpage")
				entity_set_model(ent, g_szEditorSprite)
				entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
				entity_set_float(ent, EV_FL_framerate, 30.0)
				
				DispatchSpawn(ent)
				
				entity_set_origin(ent, origin)
				entity_set_size(ent, Float:{-25.0, -25.0, -25.0}, Float:{25.0, 25.0, 25.0})
				entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
				entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY)
				entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
				entity_set_float(ent, EV_FL_renderamt, 255.0)
				entity_set_float(ent, EV_FL_scale, 1.0)
				entity_set_float(ent, EV_FL_gravity,0.0) 
				
			}
			g_bAllPagesShow = true
		}
		case 3:
		{
			new ent = -1
			while((ent = find_ent_by_class(ent,"editorpage")))
			{
				remove_entity(ent)
			}
			g_bAllPagesShow = false
			
		}	
	}
	origin_2_file_menu(id)
}

/* Pages Stuff */

public DeleteAllSprites()
{
	new ent = -1
	while((ent = find_ent_by_class(ent,"slenderpage")))
	{
		remove_entity(ent)
	}
}

public create_sprite(id)
{
	new map[32],config[32],file[64]
	
	get_mapname(map, charsmax(map))
	get_localinfo("amxx_configsdir",config,charsmax(config))
	
	formatex(file,charsmax(file),"%s\slenderman\maps\%s.cfg",config,map)
	
	if(file_exists(file))
	{
		DeleteAllSprites()
		
		new iOrigin[3][8]
		new Float:origin[3]
		
		new lines = file_size(file, 1);
		new randomLine = random(lines);
		
		new lineBuffer[256], len;
		read_file(file, randomLine, lineBuffer, charsmax(lineBuffer), len);
		
		parse(lineBuffer,iOrigin[0],7,iOrigin[1],7,iOrigin[2],7)
		
		origin[0] = str_to_float(iOrigin[0])
		origin[1] = str_to_float(iOrigin[1])
		origin[2] = str_to_float(iOrigin[2])
		
		new ent = create_entity("env_sprite")
		
		entity_set_string(ent, EV_SZ_classname, "slenderpage")
		entity_set_model(ent,g_szPageSprite)
		entity_set_int(ent, EV_INT_spawnflags, SF_SPRITE_STARTON)
		entity_set_float(ent, EV_FL_framerate, 30.0)
		
		DispatchSpawn(ent)
		
		entity_set_origin(ent, origin)
		entity_set_size(ent, Float:{-25.0, -25.0, -25.0}, Float:{25.0, 25.0, 25.0})
		entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER)
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY)
		entity_set_int(ent, EV_INT_rendermode, kRenderTransAdd)
		entity_set_float(ent, EV_FL_renderamt, 255.0)
		entity_set_float(ent, EV_FL_scale, 1.0)
		entity_set_float(ent, EV_FL_gravity,0.0)   
		
		print_color(0, id, 0, "%L", LANG_PLAYER, "SLENDER_PGEN",g_szGamePrefix,g_iPages)
	}
	else
	{
		print_color(0, id, 0, "%L", LANG_PLAYER, "SLENDER_NOLOC",g_szGamePrefix)
	}
}

public player_touch_slenderpage(ent, id)
{
	if(cs_get_user_team(id) == CS_TEAM_CT)
	{
		remove_entity(ent)
		
		new szName[32];
		get_user_name(id, szName, 31);
		
		set_hudmessage(255, 255, 255, -0.5, 0.5, 0, 6.0, 12.0, 0.1)
		show_hudmessage(id, "%L", LANG_PLAYER, "SLENDER_PFOUNDHUD", g_iPages, get_pcvar_num(cvar_pages))
		
		print_color(0, id, 0, "%L", LANG_PLAYER, "SLENDER_PFOUND",g_szGamePrefix,szName,g_iPages,get_pcvar_num(cvar_pages))
		
		if(g_iPages >= get_pcvar_num(cvar_pages))
		{
			user_kill(g_iSlenderId)
			g_iPages = 1
		}
		
		g_iPages++	
		create_sprite(id)
	}
}

/* Color Chat */

public print_color(id, cid, color, const message[], any:...)
{
	new msg[192]
	vformat(msg, charsmax(msg), message, 5)
	new param
	if (!cid) 
		return
	else 
		param = cid
	
	new team[32]
	get_user_team(param, team, 31)
	switch (color)
	{
		case 0: msg_teaminfo(param, team)
		case 1: msg_teaminfo(param, "TERRORIST")
		case 2: msg_teaminfo(param, "CT")
		case 3: msg_teaminfo(param, "SPECTATOR")
	}
	if (id) msg_saytext(id, param, msg)
	else msg_saytext(0, param, msg)
		
	if (color != 0) msg_teaminfo(param, team)
}

msg_saytext(id, cid, msg[])
{
	message_begin(id?MSG_ONE:MSG_ALL, get_user_msgid("SayText"), {0,0,0}, id)
	write_byte(cid)
	write_string(msg)
	message_end()
}

msg_teaminfo(id, team[])
{
	message_begin(MSG_ONE, get_user_msgid("TeamInfo"), {0,0,0}, id)
	write_byte(id)
	write_string(team)
	message_end()
}

/* Team Manager */

public message_ShowMenu(iMsgid, iDest, id)
{
	static sMenuCode[iMaxLen];
	get_msg_arg_string(4, sMenuCode, sizeof(sMenuCode) - 1)
	if(equal(sMenuCode, FIRST_JOIN_MSG) || equal(sMenuCode, FIRST_JOIN_MSG_SPEC))
	{
		show_team_menu(id)
		return PLUGIN_HANDLED
		
	}
	return PLUGIN_CONTINUE;
}

public message_VGUIMenu(iMsgid, iDest, id)
{
	if(get_msg_arg_int(1) != VGUI_JOIN_TEAM_NUM)
	{
		return PLUGIN_CONTINUE;
	}
	
	show_team_menu(id)
	return PLUGIN_HANDLED;
}

public count_teams()
{
	CTCount = 0
	TCount = 0
	
	new Players[32] 
	new playerCount, i 
	get_players(Players, playerCount, "") 
	for (i=0; i<playerCount; i++) 
	{
		if (is_user_connected(Players[i])) 
		{
			if (cs_get_user_team(Players[i]) == CS_TEAM_CT) CTCount++
			if (cs_get_user_team(Players[i]) == CS_TEAM_T) TCount++
		}
	}
}

public team_choice(id, menu, item)
{
	static dst[32], data[5], access, callback
	static restore, vgui, msgblock
	
	if(item == MENU_EXIT)
	{
		msgblock = get_msg_block(g_MsgShowMenu)
		set_msg_block(g_MsgShowMenu, BLOCK_ONCE)
		engclient_cmd(id, "jointeam", "2")
		engclient_cmd(id, "joinclass", "2")
		set_msg_block(g_MsgShowMenu, msgblock)
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	
	restore = get_pdata_int(id, m_iVGUI)
	vgui = restore & (1<<0)
	if(vgui)
		set_pdata_int(id, m_iVGUI, restore & ~(1<<0))
	
	
	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	menu_destroy(menu)
	
	switch(data[0])
	{
		case('1'): 
		{            
			count_teams()
			
			if(TCount < 1)
			{
				msgblock = get_msg_block(g_MsgShowMenu)
				set_msg_block(g_MsgShowMenu, BLOCK_ONCE)
				engclient_cmd(id, "jointeam", "1")
				engclient_cmd(id, "joinclass", "1")
				set_msg_block(g_MsgShowMenu, msgblock)
			}
			else
			{
				msgblock = get_msg_block(g_MsgShowMenu)
				set_msg_block(g_MsgShowMenu, BLOCK_ONCE)
				engclient_cmd(id, "jointeam", "2")
				engclient_cmd(id, "joinclass", "2")
				set_msg_block(g_MsgShowMenu, msgblock)
			}
			
		}
		case('2'): 
		{
			msgblock = get_msg_block(g_MsgShowMenu)
			set_msg_block(g_MsgShowMenu, BLOCK_ONCE)
			engclient_cmd(id, "jointeam", "2")
			engclient_cmd(id, "joinclass", "2")
			set_msg_block(g_MsgShowMenu, msgblock)
		}
		
	}
	if(vgui)
		set_pdata_int(id, m_iVGUI, restore)
	return PLUGIN_HANDLED
}

public show_team_menu(id)
{
	static menu
	
	menu = menu_create("Select Your Team:", "team_choice")
	
	if(TCount < 1) 
		menu_additem(menu, "Slenderman", "1", 0)
	else 
		menu_additem(menu, "\dSlenderman", "1", 1<<31)
	
	menu_additem(menu, "Humans", "2", 0)
	menu_display(id, menu)
	
	return PLUGIN_HANDLED
}

public jointeam(id) return PLUGIN_HANDLED