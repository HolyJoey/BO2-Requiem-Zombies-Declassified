#include common_scripts\utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// BO1 character quotes for lines DLC5 registers but ships no sound for. Log lines start with "BO1VOX >>".
// The recordings come from BO1 (each map's own cast where BO1 has the line, else the same character from another
// Ultimis map) and live in the dlc5_bo1vox.english bank in mod.ff under map-tagged names:
//   vox_plr_<n>_<tag>_<suffix>_<variant>     e.g. vox_plr_0_kino_powerup_minigun_0
// The tag keeps each map's version separate (plr0 is Dempsey on Kino but JFK on Five) and means no line that
// already has sound is ever replaced: the stock picker below only falls back to the tagged name when the stock
// name has no variants at all.

main()
{
    tag = bo1vox_map_tag( getdvar( "mapname" ) );

    if ( !isdefined( tag ) )
        return;

    level.bo1vox_tag = tag;
    f = getfunction( "maps/mp/zombies/_zm_audio", "zmbvoxgetlinevariant" );

    if ( isdefined( f ) )
        replacefunc( f, ::bo1vox_getlinevariant, -1 );
    else
        println( "BO1VOX >> zmbvoxgetlinevariant not found, BO1 quotes off" );
}

init()
{
    if ( !isdefined( level.bo1vox_tag ) )
        return;

    println( "BO1VOX >> on for " + getdvar( "mapname" ) + " (tag " + level.bo1vox_tag + ")" );
    level thread bo1vox_register_pickups();
    level thread bo1vox_register_table();
    level thread bo1vox_unused_watch();
}

// Box / wall pickup quotes are looked up by the weapon's own name (_zm_weapons::play_weapon_vo passes e.g.
// "ray_gun_zm" as the type), but the DLC5 maps only register some guns by name, so the rest stay silent.
// Every weapon on the map without an entry gets one: its own BO1 line where BO1 has one (wonder weapons,
// monkeys, bowie...), else the BO1 line for its weapon class. Only lines that have sound (stock or BO1) are used.
bo1vox_register_pickups()
{
    level endon( "end_game" );

    while ( !isdefined( level.vox ) || !isdefined( level.vox.speaker ) || !isdefined( level.vox.speaker["player"] ) || !isdefined( level.zombie_weapons ) || getplayers().size == 0 )
        wait 0.5;

    wait 2;
    sp = level.vox.speaker["player"];

    if ( !isdefined( sp.alias["weapon_pickup"] ) )
        sp.alias["weapon_pickup"] = [];

    self bo1vox_monkey_lines( sp );

    added = 0;
    names = "";

    foreach ( weapon, info in level.zombie_weapons )
    {
        if ( isdefined( sp.alias["weapon_pickup"][weapon] ) )
            continue;

        suffix = bo1vox_pickup_suffix( weapon, info, sp );

        if ( !isdefined( suffix ) )
            continue;

        sp.alias["weapon_pickup"][weapon] = suffix;
        added++;
        names = names + weapon + "=" + suffix + " ";
    }

    // equipment (Moon gas mask / hacker) is kept in its own list
    if ( isdefined( level.zombie_include_equipment ) )
    {
        foreach ( equip, val in level.zombie_include_equipment )
        {
            if ( isdefined( sp.alias["weapon_pickup"][equip] ) )
                continue;

            suffix = bo1vox_special_pickup( equip );

            if ( !isdefined( suffix ) || !bo1vox_line_exists( sp.prefix, suffix ) )
                continue;

            sp.alias["weapon_pickup"][equip] = suffix;
            added++;
            names = names + equip + "=" + suffix + " ";
        }
    }

    level.vox.speaker["player"] = sp;
    println( "BO1VOX >> registered " + added + " pickup lines: " + names );
}

bo1vox_pickup_suffix( weapon, info, sp )
{
    candidates = [];
    special = bo1vox_special_pickup( weapon );

    if ( isdefined( special ) )
        candidates[candidates.size] = special;

    if ( isdefined( info ) && isdefined( info.vox ) )
    {
        // the map's own entry for this class (e.g. "pistol" -> "wpck_crappy"), then BO1's class line
        if ( isdefined( sp.alias["weapon_pickup"][info.vox] ) )
            candidates[candidates.size] = sp.alias["weapon_pickup"][info.vox];

        cls = bo1vox_class_pickup( info.vox );

        if ( isdefined( cls ) )
            candidates[candidates.size] = cls;
    }

    for ( i = 0; i < candidates.size; i++ )
    {
        if ( bo1vox_line_exists( sp.prefix, candidates[i] ) )
            return candidates[i];
    }

    return undefined;
}

bo1vox_line_exists( prefix, suffix )
{
    for ( p = 0; p < 4; p++ )
    {
        if ( soundexists( prefix + p + "_" + suffix + "_0" ) )
            return true;

        if ( soundexists( prefix + p + "_" + level.bo1vox_tag + "_" + suffix + "_0" ) )
            return true;
    }

    return false;
}

bo1vox_special_pickup( weapon )
{
    if ( issubstr( weapon, "raygun_mark2" ) || issubstr( weapon, "ray_gun" ) )
        return "wpck_raygun";

    if ( issubstr( weapon, "thundergun" ) )
        return "wpck_thunder";

    if ( issubstr( weapon, "tesla" ) )
        return "wpck_tesla";

    if ( issubstr( weapon, "freezegun" ) )
        return "wpck_freeze";

    if ( issubstr( weapon, "microwave" ) )
        return "wpck_microwave";

    if ( issubstr( weapon, "black_hole" ) )
        return "wpck_gersh_device";

    if ( issubstr( weapon, "quantum" ) )
        return "wpck_quantum";

    if ( issubstr( weapon, "cymbal_monkey" ) || issubstr( weapon, "monkey" ) )
        return "wpck_monkey";

    if ( issubstr( weapon, "bowie" ) )
        return "wpck_bowie";

    if ( issubstr( weapon, "shrink" ) )
        return "wpck_shrink";

    if ( issubstr( weapon, "nesting_doll" ) )
        return "wpck_dolls";

    if ( issubstr( weapon, "sickle" ) )
        return "wpck_sickle";

    if ( issubstr( weapon, "spikemore" ) )
        return "wpck_spikemore";

    if ( issubstr( weapon, "sticky_grenade" ) )
        return "wpck_sticky";

    if ( issubstr( weapon, "flamethrower" ) )
        return "wpck_flame";

    if ( issubstr( weapon, "gasmask" ) )
        return "wpck_gasmask";

    if ( issubstr( weapon, "hacker" ) )
        return "wpck_hacker";

    return undefined;
}

bo1vox_class_pickup( vox )
{
    switch ( vox )
    {
        case "pistol":
            return "wpck_crappy";
        case "smg":
            return "wpck_smg";
        case "dualwield":
            return "wpck_dual";
        case "shotgun":
            return "wpck_shotgun";
        case "rifle":
        case "sniper":
            return "wpck_sniper";
        case "burstrifle":
        case "assault":
        case "mg":
            return "wpck_mg";
        case "launcher":
        case "crossbow":
            return "wpck_launcher";
    }

    return undefined;
}

bo1vox_map_tag( mapname )
{
    switch ( mapname )
    {
        case "zm_theater":
            return "kino";
        case "zm_moon":
            return "moon";
        case "zm_pentagon":
            return "five";
        case "zm_cosmodrome":
            return "asc";
        case "zm_temple":
            return "shang";
        case "zm_prototype":
            return "nacht";
        case "zm_asylum":
            return "verr";
        case "zm_sumpf":
            return "shino";
        case "zm_factory":
            return "der";
    }

    return undefined;
}

// Stock _zm_audio::zmbvoxgetlinevariant, plus the BO1 fallback when the stock line has no variants.
bo1vox_getlinevariant( prefix, alias_suffix, force_variant, override )
{
    if ( !isdefined( self.sound_dialog ) )
    {
        self.sound_dialog = [];
        self.sound_dialog_available = [];
    }

    if ( !isdefined( self.bo1vox_key ) )
        self.bo1vox_key = [];

    key = alias_suffix;

    if ( isdefined( self.bo1vox_key[prefix + alias_suffix] ) )
        key = self.bo1vox_key[prefix + alias_suffix];

    if ( !isdefined( self.sound_dialog[key] ) )
    {
        num_variants = maps\mp\zombies\_zm_spawner::get_number_variants( prefix + alias_suffix );

        if ( num_variants <= 0 && isdefined( level.bo1vox_tag ) )
        {
            tagged = level.bo1vox_tag + "_" + alias_suffix;
            num_variants = maps\mp\zombies\_zm_spawner::get_number_variants( prefix + tagged );

            if ( num_variants > 0 )
            {
                key = tagged;
                self.bo1vox_key[prefix + alias_suffix] = tagged;
                println( "BO1VOX >> " + prefix + alias_suffix + " -> BO1 " + prefix + tagged + " (" + num_variants + " variants)" );
            }
        }

        if ( num_variants <= 0 )
            return undefined;

        for ( i = 0; i < num_variants; i++ )
            self.sound_dialog[key][i] = i;

        self.sound_dialog_available[key] = [];
    }

    if ( self.sound_dialog_available[key].size <= 0 )
    {
        for ( i = 0; i < self.sound_dialog[key].size; i++ )
            self.sound_dialog_available[key][i] = self.sound_dialog[key][i];
    }

    variation = random( self.sound_dialog_available[key] );
    arrayremovevalue( self.sound_dialog_available[key], variation );

    if ( isdefined( force_variant ) )
        variation = force_variant;

    if ( !isdefined( override ) )
        override = 0;

    return key + "_" + variation;
}

// ---- generated from BO1's level.plr_vox tables (common_zombie + each map) ----
// Entries the DLC5 map never registered are added at map start, but only when the line has sound (stock or BO1 tagged),
// so DLC5's ported map scripts that fire these events (excavator, jump pads, hacking, astronauts...) get their quotes.
bo1vox_register_table()
{
    level endon( "end_game" );

    // registered as soon as the player speaker exists (no player needed): the level-start lines (Moon's
    // "head to the teleporter" = general/start, 3 s after the round logic starts) fired before a later registration
    while ( !isdefined( level.vox ) || !isdefined( level.vox.speaker ) || !isdefined( level.vox.speaker["player"] ) )
        wait 0.05;

    sp = level.vox.speaker["player"];
    entries = bo1vox_table_common();
    extra = bo1vox_table_map( getdvar( "mapname" ) );

    for ( i = 0; i < extra.size; i++ )
        entries[entries.size] = extra[i];

    added = 0;
    names = "";

    for ( i = 0; i < entries.size; i++ )
    {
        parts = strtok( entries[i], "|" );
        cat = parts[0];
        type = parts[1];
        suffix = parts[2];

        if ( isdefined( sp.alias[cat] ) && isdefined( sp.alias[cat][type] ) )
            continue;

        if ( !bo1vox_line_exists( sp.prefix, suffix ) )
            continue;

        if ( !isdefined( sp.alias[cat] ) )
            sp.alias[cat] = [];

        sp.alias[cat][type] = suffix;
        added++;
        names = names + cat + "/" + type + " ";

        if ( added % 20 == 0 )
            wait 0.05;
    }

    println( "BO1VOX >> registered " + added + " BO1 quote entries the map was missing: " + names );
}

// Monkey Bomb character lines were silent. The box pickup line (_zm_weapons::weapon_give -> play_weapon_vo) is skipped
// when the map tags cymbal_monkey_zm "crappy", and the kill line needs kill/monkey with sound; both are made sure of here.
bo1vox_monkey_lines( sp )
{
    vox = "none";

    if ( isdefined( level.zombie_weapons["cymbal_monkey_zm"] ) )
    {
        if ( isdefined( level.zombie_weapons["cymbal_monkey_zm"].vox ) )
            vox = level.zombie_weapons["cymbal_monkey_zm"].vox;

        if ( vox == "none" || vox == "crappy" )
            level.zombie_weapons["cymbal_monkey_zm"].vox = "monkey";
    }

    if ( !isdefined( sp.alias["kill"] ) )
        sp.alias["kill"] = [];

    kill = "kept";

    if ( !isdefined( sp.alias["kill"]["monkey"] ) && bo1vox_line_exists( sp.prefix, "kill_monkey" ) )
    {
        sp.alias["kill"]["monkey"] = "kill_monkey";
        kill = "added";
    }

    println( "BO1VOX >> Monkey Bomb lines: map vox tag was " + vox + ", kill line " + kill + ", pickup sound " + bo1vox_line_exists( sp.prefix, "wpck_monkey" ) + ", kill sound " + bo1vox_line_exists( sp.prefix, "kill_monkey" ) );
}

// ---- lines BO1 recorded but its own scripts never played ----
// board (every 10th board repaired - stock's "reboard" trigger, which the DLC5 maps never gave a sound), the nesting
// doll lines (holding a doll / the first doll landing), down_revive (asking for help while down, co-op only) and
// Dempsey's "rare" lines on Kino (now and then at the start of a round).
bo1vox_unused_watch()
{
    level endon( "end_game" );

    if ( level.bo1vox_tag == "kino" )
        level thread bo1vox_rare_watch();

    players = getplayers();

    for ( i = 0; i < players.size; i++ )
        players[i] thread bo1vox_player_watch();

    for (;;)
    {
        level waittill( "connected", player );
        player thread bo1vox_player_watch();
    }
}

bo1vox_player_watch()
{
    self notify( "bo1vox_player_watch" );
    self endon( "bo1vox_player_watch" );
    self endon( "disconnect" );
    self thread bo1vox_down_watch();
    self thread bo1vox_doll_watch();
}

// plays a registered-or-not line straight away; used while downed, where stock create_and_play_dialog refuses to speak
bo1vox_play_direct( suffix )
{
    if ( isdefined( self.isspeaking ) && self.isspeaking )
        return;

    if ( !isdefined( level.vox ) || !isdefined( level.vox.speaker ) || !isdefined( level.vox.speaker["player"] ) )
        return;

    index = maps\mp\zombies\_zm_weapons::get_player_index( self );
    prefix = level.vox.speaker["player"].prefix + index + "_";
    sound = self bo1vox_getlinevariant( prefix, suffix );

    if ( !isdefined( sound ) )
        return;

    println( "BO1VOX >> " + self.name + " says " + prefix + sound );
    self thread maps\mp\zombies\_zm_audio::do_player_or_npc_playvox( prefix, index, sound, 1, "general", suffix, 0, 0 );
}

bo1vox_down_watch()
{
    self endon( "disconnect" );
    self endon( "bo1vox_player_watch" );

    for (;;)
    {
        self waittill( "player_downed" );
        wait( randomfloatrange( 3, 5 ) );

        if ( getplayers().size > 1 && self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && randomint( 100 ) < 70 )
        {
            if ( !isdefined( self.revivetrigger ) || !isdefined( self.revivetrigger.beingrevived ) || !self.revivetrigger.beingrevived )
                self bo1vox_play_direct( "down_revive" );
        }

        while ( self maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
            wait 0.5;
    }
}

bo1vox_doll_watch()
{
    self endon( "disconnect" );
    self endon( "bo1vox_player_watch" );

    if ( !isdefined( level.zombie_weapons ) || !isdefined( level.zombie_weapons["zombie_nesting_dolls"] ) )
        return;

    for (;;)
    {
        self waittill( "grenade_pullback", weaponname );

        if ( weaponname != "zombie_nesting_dolls" )
            continue;

        name = self bo1vox_next_doll_name();

        if ( isdefined( name ) && randomint( 100 ) < 35 )
            self maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "doll_hold_" + name );
        else
            self thread bo1vox_doll_land();
    }
}

// the first doll of the throw stopping on the ground
bo1vox_doll_land()
{
    self endon( "disconnect" );
    self endon( "grenade_pullback" );
    self waittill( "spawn_doll" );

    if ( randomint( 100 ) < 30 )
        self maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "doll_land" );
}

// which character's doll the next throw starts with (the same pick _zm_weap_nesting_dolls shows on the weapon)
bo1vox_next_doll_name()
{
    if ( !isdefined( level.nesting_dolls_data ) || !isdefined( self.nesting_dolls_randomized_indices ) )
        return undefined;

    id = 0;

    if ( isdefined( self.doll_id ) )
    {
        id = self.doll_id + 1;

        if ( isdefined( level.nesting_dolls_max_ids ) && id >= level.nesting_dolls_max_ids )
            id = 0;
    }

    if ( !isdefined( self.nesting_dolls_randomized_indices[id] ) )
        return undefined;

    data = level.nesting_dolls_data[self.nesting_dolls_randomized_indices[id][0]];

    if ( !isdefined( data ) || !isdefined( data.name ) )
        return undefined;

    return data.name;
}

bo1vox_rare_watch()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "start_of_round" );

        if ( !isdefined( level.round_number ) || level.round_number < 2 || randomint( 100 ) >= 10 )
            continue;

        wait( randomfloatrange( 5, 15 ) );
        players = getplayers();

        for ( i = 0; i < players.size; i++ )
        {
            if ( maps\mp\zombies\_zm_weapons::get_player_index( players[i] ) == 0 )
                players[i] maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "rare" );
        }
    }
}

bo1vox_table_map( mapname )
{
    switch ( mapname )
    {
        case "zm_prototype":
            return bo1vox_table_zm_prototype();
        case "zm_asylum":
            return bo1vox_table_zm_asylum();
        case "zm_sumpf":
            return bo1vox_table_zm_sumpf();
        case "zm_factory":
            return bo1vox_table_zm_factory();
        case "zm_theater":
            return bo1vox_table_zm_theater();
        case "zm_pentagon":
            return bo1vox_table_zm_pentagon();
        case "zm_cosmodrome":
            return bo1vox_table_zm_cosmodrome();
        case "zm_temple":
            return bo1vox_table_zm_temple();
        case "zm_moon":
            return bo1vox_table_zm_moon();
    }

    return [];
}

bo1vox_table_common()
{
    t = [];
    t[t.size] = "catapult|ally|catapult_ally";
    t[t.size] = "catapult|rival|catapult_rival";
    t[t.size] = "catapult|self|catapult_self";
    t[t.size] = "catapult|zombie|catapult_zmb";
    t[t.size] = "director|anger|director_anger";
    t[t.size] = "director|exit|director_exit";
    t[t.size] = "director|water|director_water";
    t[t.size] = "director|weaken|director_weaken";
    t[t.size] = "eggs|achievement|achievement";
    t[t.size] = "eggs|dolls|egg_dolls";
    t[t.size] = "eggs|gameover|gameover";
    t[t.size] = "eggs|meteors|egg_pedastool";
    t[t.size] = "eggs|music_activate|secret";
    t[t.size] = "eggs|portrait_dempsey|egg_port_dempsey";
    t[t.size] = "eggs|portrait_empty|egg_port_empty";
    t[t.size] = "eggs|portrait_nikolai|egg_port_nikolai";
    t[t.size] = "eggs|portrait_richtofan|egg_port_richtofan";
    t[t.size] = "eggs|portrait_takeo|egg_port_takeo";
    t[t.size] = "eggs|quest1|quest_step1";
    t[t.size] = "eggs|quest2|quest_step2";
    t[t.size] = "eggs|quest3|quest_step3";
    t[t.size] = "eggs|quest4|quest_step4";
    t[t.size] = "eggs|quest5|quest_step5";
    t[t.size] = "eggs|quest6|quest_step6";
    t[t.size] = "eggs|quest7|quest_step7";
    t[t.size] = "eggs|quest8|quest_step8";
    t[t.size] = "eggs|rod|rod";
    t[t.size] = "eggs|room_alley|egg_room_alley";
    t[t.size] = "eggs|room_dress|egg_room_dress";
    t[t.size] = "eggs|room_lounge|egg_room_lounge";
    t[t.size] = "eggs|room_rest|egg_room_rest";
    t[t.size] = "eggs|room_screen|egg_room_screen";
    t[t.size] = "eggs|safety|safety";
    t[t.size] = "general|ammo_low|ammo_low";
    t[t.size] = "general|ammo_out|ammo_out";
    t[t.size] = "general|box_move|box_move";
    t[t.size] = "general|crawl_hit|crawler_hit";
    t[t.size] = "general|crawl_spawn|spawn_crawl";
    t[t.size] = "general|damage_shocked|damage_shocked";
    t[t.size] = "general|dog_spawn|spawn_dog";
    t[t.size] = "general|door_deny|nomoney";
    t[t.size] = "general|geyser|geyser";
    t[t.size] = "general|hitlrg|gen_hitlrg";
    t[t.size] = "general|hitmed|gen_hitmed";
    t[t.size] = "general|intro|level_start";
    t[t.size] = "general|location_maze|location_maze";
    t[t.size] = "general|location_waterfall|location_waterfall";
    t[t.size] = "general|meteor_see|meteor_see";
    t[t.size] = "general|mine_ride|mine_ride";
    t[t.size] = "general|mine_see|mine_see";
    t[t.size] = "general|monkey_hit|space_monkey_hit";
    t[t.size] = "general|monkey_spawn|monkey_start";
    t[t.size] = "general|napalm_spawn|napalm_spawn";
    t[t.size] = "general|no|no";
    t[t.size] = "general|no_money|nomoney";
    t[t.size] = "general|oh_shit|ohshit";
    t[t.size] = "general|perk_deny|nomoney";
    t[t.size] = "general|poweron|power_on";
    t[t.size] = "general|quad_spawn|spawn_quad";
    t[t.size] = "general|react_sparkers|react_sparkers";
    t[t.size] = "general|react_sprinters|react_sprinters";
    t[t.size] = "general|revive_down|revive_down";
    t[t.size] = "general|revive_up|revive_up";
    t[t.size] = "general|round_10|round_10";
    t[t.size] = "general|round_20|round_20";
    t[t.size] = "general|round_35|round_35";
    t[t.size] = "general|round_5|round_5";
    t[t.size] = "general|round_50|round_50";
    t[t.size] = "general|shoot_arm|shoot_limb";
    t[t.size] = "general|sigh|sigh";
    t[t.size] = "general|slide|slide";
    t[t.size] = "general|sonic_hit|sonic_dmg";
    t[t.size] = "general|sonic_spawn|sonic_spawn";
    t[t.size] = "general|spikes_close|spikes_close";
    t[t.size] = "general|spikes_damage|spikes_dmg";
    t[t.size] = "general|start|start";
    t[t.size] = "general|teleport_gersh|teleport_gersh_device";
    t[t.size] = "general|thief_steal|thief_steal";
    t[t.size] = "general|turret_active|turret_active";
    t[t.size] = "general|turret_inactive|turret_inactive";
    t[t.size] = "general|uncertain|uncertain";
    t[t.size] = "general|water_damage|damage_water";
    t[t.size] = "general|water_frozen|damage_frozen";
    t[t.size] = "general|weather_bad|weather_bad";
    t[t.size] = "general|weather_good|weather_good";
    t[t.size] = "general|yes|yes";
    t[t.size] = "general|zipline|zipline";
    t[t.size] = "kill|bullet|kill_streak";
    t[t.size] = "kill|claymore|kill_claymore";
    t[t.size] = "kill|closekill|kill_close";
    t[t.size] = "kill|crawler|kill_crawler";
    t[t.size] = "kill|damage|kill_damaged";
    t[t.size] = "kill|dolls|kill_dolls";
    t[t.size] = "kill|explosive|kill_explo";
    t[t.size] = "kill|flame|kill_flame";
    t[t.size] = "kill|freeze|kill_freeze";
    t[t.size] = "kill|gersh_device|kill_gersh_device";
    t[t.size] = "kill|headshot|kill_headshot";
    t[t.size] = "kill|hellhound|kill_hellhound";
    t[t.size] = "kill|human|kill_human";
    t[t.size] = "kill|melee|kill_melee";
    t[t.size] = "kill|melee_instakill|kill_insta";
    t[t.size] = "kill|monkey|kill_monkey";
    t[t.size] = "kill|napalm|napalm_kill";
    t[t.size] = "kill|quad|kill_quad";
    t[t.size] = "kill|raygun|kill_ray";
    t[t.size] = "kill|shrink|kill_shrink";
    t[t.size] = "kill|shrunken|kill_shrunken";
    t[t.size] = "kill|sickle|kill_sickle";
    t[t.size] = "kill|sonic|sonic_kill";
    t[t.size] = "kill|space_monkey|kill_space_monkey";
    t[t.size] = "kill|spikemore|kill_spikemore";
    t[t.size] = "kill|streak|kill_streak";
    t[t.size] = "kill|tesla|kill_tesla";
    t[t.size] = "kill|thief|kill_thief";
    t[t.size] = "kill|thundergun|kill_thunder";
    t[t.size] = "kill|ubersniper|kill_ubersniper";
    t[t.size] = "kill|weapon_instakill|kill_insta";
    t[t.size] = "perk|specialty_armorvest|perk_jugga";
    t[t.size] = "perk|specialty_deadshot|perk_deadshot";
    t[t.size] = "perk|specialty_fastreload|perk_speed";
    t[t.size] = "perk|specialty_flakjacket|perk_phdflopper";
    t[t.size] = "perk|specialty_longersprint|perk_stamin";
    t[t.size] = "perk|specialty_quickrevive|perk_revive";
    t[t.size] = "perk|specialty_rof|perk_doubletap";
    t[t.size] = "perk|steal_specialty_armorvest|perk_steal_jugga";
    t[t.size] = "perk|steal_specialty_fastreload|perk_steal_speed";
    t[t.size] = "perk|steal_specialty_flakjacket|perk_steal_prone";
    t[t.size] = "perk|steal_specialty_longersprint|perk_steal_stamin";
    t[t.size] = "perk|steal_specialty_quickrevive|perk_steal_revive";
    t[t.size] = "powerup|carpenter|powerup_carp";
    t[t.size] = "powerup|double_points|powerup_double";
    t[t.size] = "powerup|firesale|powerup_firesale";
    t[t.size] = "powerup|full_ammo|powerup_ammo";
    t[t.size] = "powerup|insta_kill|powerup_insta";
    t[t.size] = "powerup|minigun|powerup_minigun";
    t[t.size] = "powerup|nuke|powerup_nuke";
    t[t.size] = "weapon_pickup|assault|wpck_mg";
    t[t.size] = "weapon_pickup|bowie|wpck_bowie";
    t[t.size] = "weapon_pickup|burstrifle|wpck_mg";
    t[t.size] = "weapon_pickup|crossbow|wpck_launcher";
    t[t.size] = "weapon_pickup|dolls|wpck_dolls";
    t[t.size] = "weapon_pickup|dualwield|wpck_dual";
    t[t.size] = "weapon_pickup|favorite|wpck_favorite";
    t[t.size] = "weapon_pickup|favorite_upgrade|wpck_favorite_upgrade";
    t[t.size] = "weapon_pickup|freezegun|wpck_freeze";
    t[t.size] = "weapon_pickup|gersh|wpck_gersh_device";
    t[t.size] = "weapon_pickup|grenade|wpck_grenade";
    t[t.size] = "weapon_pickup|human|wpck_human";
    t[t.size] = "weapon_pickup|launcher|wpck_launcher";
    t[t.size] = "weapon_pickup|mg|wpck_mg";
    t[t.size] = "weapon_pickup|monkey|wpck_monkey";
    t[t.size] = "weapon_pickup|pistol|wpck_crappy";
    t[t.size] = "weapon_pickup|raygun|wpck_raygun";
    t[t.size] = "weapon_pickup|rifle|wpck_sniper";
    t[t.size] = "weapon_pickup|shotgun|wpck_shotgun";
    t[t.size] = "weapon_pickup|shrink|wpck_shrink";
    t[t.size] = "weapon_pickup|sickle|wpck_sickle";
    t[t.size] = "weapon_pickup|smg|wpck_smg";
    t[t.size] = "weapon_pickup|sniper|wpck_sniper";
    t[t.size] = "weapon_pickup|spikemore|wpck_spikemore";
    t[t.size] = "weapon_pickup|tesla|wpck_tesla";
    t[t.size] = "weapon_pickup|thunder|wpck_thunder";
    t[t.size] = "weapon_pickup|ubersniper|wpck_ubersniper";
    t[t.size] = "weapon_pickup|upgrade|wpck_upgrade";
    t[t.size] = "weapon_pickup|upgrade_wait|wpck_upgrade_wait";
    return t;
}

bo1vox_table_zm_prototype()
{
    t = [];
    return t;
}

bo1vox_table_zm_asylum()
{
    t = [];
    t[t.size] = "level|power|power";
    return t;
}

bo1vox_table_zm_sumpf()
{
    t = [];
    t[t.size] = "level|doubletap|gen_perk_dbltap";
    t[t.size] = "level|jugga|gen_perk_jugga";
    t[t.size] = "level|meteor|meteor";
    t[t.size] = "level|revive|gen_perk_revive";
    t[t.size] = "level|speed|gen_perk_speed";
    t[t.size] = "level|trap_barrel|trap_barrel";
    t[t.size] = "level|trap_log|trap_log";
    t[t.size] = "level|zipline|zipline";
    return t;
}

bo1vox_table_zm_factory()
{
    t = [];
    t[t.size] = "level|audio_secret|audio_secret";
    t[t.size] = "level|corkboard_1|resp_corkmap";
    t[t.size] = "level|corkboard_2|resp_corkmap";
    t[t.size] = "level|corkboard_3|resp_corkmap";
    t[t.size] = "level|fieldop|resp_fieldop";
    t[t.size] = "level|gen_giant|gen_giant";
    t[t.size] = "level|gen_sigh|gen_sigh";
    t[t.size] = "level|illumi_1|resp_maxis";
    t[t.size] = "level|illumi_2|resp_maxis";
    t[t.size] = "level|maxis|resp_maxis";
    t[t.size] = "level|perk_packa_see|perk_packa_see";
    t[t.size] = "level|teddy|resp_teddy";
    t[t.size] = "level|tele_count|tele_count";
    t[t.size] = "level|tele_help|tele_help";
    t[t.size] = "level|tele_linkall|tele_linkall";
    t[t.size] = "general|reboard|board";
    t[t.size] = "general|down_revive|down_revive";
    t[t.size] = "general|doll_hold_dempsey|mini_dempsey_hold";
    t[t.size] = "general|doll_hold_nikolai|mini_nikolai_hold";
    t[t.size] = "general|doll_hold_takeo|mini_takeo_hold";
    t[t.size] = "general|doll_hold_richtofen|mini_richtofan_hold";
    t[t.size] = "general|doll_land|mini_ground_hit";
    return t;
}

bo1vox_table_zm_theater()
{
    t = [];
    t[t.size] = "general|rare|rare";
    return t;
}

bo1vox_table_zm_pentagon()
{
    t = [];
    return t;
}

bo1vox_table_zm_cosmodrome()
{
    t = [];
    t[t.size] = "eggs|gersh_response|cosmo_egg";
    return t;
}

bo1vox_table_zm_temple()
{
    t = [];
    t[t.size] = "kill|explosive|kill_explosive";
    return t;
}

bo1vox_table_zm_moon()
{
    t = [];
    t[t.size] = "digger|breach|digger_breach";
    t[t.size] = "digger|hacked|digger_hacked";
    t[t.size] = "digger|incoming|digger_incoming";
    t[t.size] = "general|airless|location_airless";
    t[t.size] = "general|astro_spawn|spawn_astro";
    t[t.size] = "general|biodome|location_biodome";
    t[t.size] = "general|hack_box|hack_box";
    t[t.size] = "general|hack_plr|hack_plr";
    t[t.size] = "general|hack_vox|hack_vox";
    t[t.size] = "general|jumppad|jumppad";
    t[t.size] = "general|moonbase|enter_moonbase";
    t[t.size] = "general|moonjump|moonjump";
    t[t.size] = "general|teleporter|teleporter";
    t[t.size] = "kill|astro|kill_astro";
    t[t.size] = "kill|explosive|kill_explosive";
    t[t.size] = "kill|micro_dual|kill_micro_dual";
    t[t.size] = "kill|micro_single|kill_micro_single";
    t[t.size] = "kill|quant_bad|kill_quant_bad";
    t[t.size] = "kill|quant_good|kill_quant_good";
    t[t.size] = "perk|specialty_additionalprimaryweapon|perk_arsenal";
    t[t.size] = "powerup|bonus_points_solo|powerup_pts_solo";
    t[t.size] = "powerup|bonus_points_team|powerup_pts_team";
    t[t.size] = "powerup|lose_points|powerup_antipts_zmb";
    t[t.size] = "weapon_pickup|gasmask|wpck_gasmask";
    t[t.size] = "weapon_pickup|grenade|wpck_launcher";
    t[t.size] = "weapon_pickup|hacker|wpck_hacker";
    t[t.size] = "weapon_pickup|microwave|wpck_microwave";
    t[t.size] = "weapon_pickup|quantum|wpck_quantum";
    return t;
}
