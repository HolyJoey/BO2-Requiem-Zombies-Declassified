#include maps\mp\zm_moon_distance_tracking;
#include maps\mp\zombies\_zm_zonemgr;
#include maps\mp\zombies\_zm_ai_basic;
#include maps\mp\zombies\_zm;
#include maps\mp\zombies\_zm_audio;
#include maps\mp\animscripts\zm_shared;
#include maps\mp\animscripts\zm_utility;
#include maps\mp\zombies\_zm_spawner;
#include maps\mp\zombies\_zm_net;
#include maps\mp\zombies\_zm_utility;
#include common_scripts\utility;
#include maps\mp\_utility;

init()
{
    init_astro_zombie_fx();

    if ( !isdefined( level.astro_zombie_enter_level ) )
        level.astro_zombie_enter_level = ::moon_astro_enter_level;

    level.num_astro_zombies = 0;
    level.astro_zombie_spawners = getentarray( "astronaut_zombie", "targetname" );
    array_thread( level.astro_zombie_spawners, ::add_spawn_function, ::astro_prespawn );
    level.max_astro_zombies = 1;
    level.astro_zombie_health_mult = 4;
    level.min_astro_round_wait = 1;
    level.max_astro_round_wait = 2;
    level.astro_round_start = 1;
    level.next_astro_round = level.astro_round_start + randomintrange( 0, level.max_astro_round_wait + 1 );
    level.zombies_left_before_astro_spawn = 1;
    level.zombie_left_before_spawn = 0;
    level.astro_explode_radius = 400;
    level.astro_explode_blast_radius = 150;
    level.astro_explode_pulse_min = 100;
    level.astro_explode_pulse_max = 300;
    level.astro_headbutt_delay = 2000;
    level.astro_headbutt_radius_sqr = 4096;
    level.zombie_total_update = 1;
    level.zombie_total_set_func = ::astro_zombie_total_update;
    maps\mp\zombies\_zm_spawner::register_zombie_damage_callback( ::astro_damage_callback );
    maps\mp\zombies\_zm::register_custom_ai_spawn_check( "astro", ::astro_spawn_check, ::get_astro_spawners, ::get_astro_locations );
}

astro_spawn_check()
{
    if ( level.zombie_astro_locations.size <= 0 )
        return false;

    if ( !( level.round_number >= level.next_astro_round && level.num_astro_zombies < level.max_astro_zombies ) )
        return false;

    if ( !is_true( level.on_the_moon ) )
        return false;

    if ( !is_true( level.zombie_total_update ) )
        return false;

    if ( level.zombie_total > level.zombies_left_before_astro_spawn )
        return false;

    return true;
}

get_astro_spawners()
{
    return level.astro_zombie_spawners;
}

get_astro_locations()
{
    return level.zombie_astro_locations;
}

astro_prespawn()
{
    self.animname = "astro_zombie";
    self thread astro_zombie_spawn( self );
    self.ignoreall = 1;
    self.allowdeath = 1;
    self.is_zombie = 1;
    self.has_legs = 1;
    self allowedstances( "stand" );
    self.gibbed = 0;
    self.head_gibbed = 0;
    self.disablearrivals = 1;
    self.disableexits = 1;
    self.grenadeawareness = 0;
    self.badplaceawareness = 0;
    self.ignoresuppression = 1;
    self.suppressionthreshold = 1;
    self.nododgemove = 1;
    self.dontshootwhilemoving = 1;
    self.pathenemylookahead = 0;
    self.badplaceawareness = 0;
    self.chatinitialized = 0;
    self.dropweapon = 0;
    self thread maps\mp\zombies\_zm_spawner::zombie_damage_failsafe();
    self thread maps\mp\zombies\_zm_spawner::delayed_zombie_eye_glow();
    self.flame_damage_time = 0;
    self.meleedamage = 50;
    self.no_powerups = 1;
    self.no_gib = 1;
    self.ignorelocationaldamage = 1;
    self.actor_damage_func = ::astro_actor_damage;
    self.custom_damage_func = ::astro_custom_damage;
    self.microwavegun_sizzle_func = ::astro_microwavegun_sizzle;
    self.ignore_distance_tracking = 1;
    self.ignore_enemy_count = 1;
    self.ignore_gravity = 1;
    self.ignore_devgui_death = 1;
    self.ignore_nml_delete = 1;
    self.ignore_round_spawn_failsafe = 1;
    self.ignore_nuke = 1;
    self.ignore_poi_targetname = [];
    self.ignore_poi_targetname[self.ignore_poi_targetname.size] = "zm_bhb";
    self.zombie_move_speed = "walk";
    self set_zombie_run_cycle();
    self thread maps\mp\zombies\_zm_ai_basic::find_flesh();
    self.zombie_init_done = 1;
    self notify( "zombie_init_done" );
}

init_astro_zombie_fx()
{
    level._effect["astro_spawn"] = loadfx( "maps/zombie/fx_zombie_boss_spawn" );
    level._effect["astro_explosion"] = loadfx( "maps/zombie_moon/fx_moon_qbomb_explo_distort" );
}

astro_zombie_spawn( astro_zombie )
{
    self.script_moveoverride = 1;

    if ( !isdefined( level.num_astro_zombies ) )
        level.num_astro_zombies = 0;

    level.num_astro_zombies++;
    astro_zombie.has_legs = 1;
    self.count = 100;

    if ( !spawn_failed( astro_zombie ) )
    {
        astro_zombie.script_noteworthy = self.script_noteworthy;
        astro_zombie.targetname = self.targetname + "_ai";
        astro_zombie.target = self.target;
        astro_zombie.deathfunction = ::astro_zombie_die;
        astro_zombie.animname = "astro_zombie";
        astro_zombie thread astro_zombie_think();
    }
    else
        level.num_astro_zombies--;

    return astro_zombie;
}

astro_zombie_total_update()
{
    level.zombie_total_update = 1;
    level.zombies_left_before_astro_spawn = 1;

    if ( level.zombie_total > 1 )
        level.zombies_left_before_astro_spawn = randomintrange( int( level.zombie_total * 0.25 ), int( level.zombie_total * 0.75 ) );
}

astro_zombie_think()
{
    self endon( "death" );
    self.entered_level = 0;
    self.ignoreall = 0;
    self.maxhealth = level.zombie_health * level.players.size * level.astro_zombie_health_mult;
    self.health = self.maxhealth;
    self.maxsightdistsqrd = 96 * 96;
    self.zombie_move_speed = "walk";
    self thread [[ level.astro_zombie_enter_level ]]();

    if ( isdefined( level.astro_zombie_custom_think ) )
        self thread [[ level.astro_zombie_custom_think ]]();

    self thread astro_zombie_headbutt_think();
    self playloopsound( self.loopsound );

    while ( true )
    {
        if ( !self.entered_level )
        {
            wait_network_frame();
            continue;
        }
        else if ( is_true( self.custom_think ) )
        {
            wait_network_frame();
            continue;
        }
        else if ( !isdefined( self.following_player ) || !self.following_player )
        {
            self thread maps\mp\zombies\_zm_ai_basic::find_flesh();
            self.following_player = 1;
        }

        wait 1;
    }
}

astro_zombie_headbutt_think()
{
    self endon( "death" );
    self.is_headbutt = 0;
    self.next_headbutt_time = gettime() + level.astro_headbutt_delay;
    self thread astro_zombie_headbutt_watcher( "headbutt" );
    self thread astro_zombie_headbutt_release_watcher( "headbutt" );

    while ( true )
    {
        if ( !isdefined( self.enemy ) )
        {
            wait_network_frame();
            continue;
        }

        if ( !self.is_headbutt && gettime() > self.next_headbutt_time )
        {
            origin = self geteye();
            test_origin = self.enemy geteye();
            dist_sqr = distancesquared( origin, test_origin );

            if ( dist_sqr > level.astro_headbutt_radius_sqr )
            {
                wait_network_frame();
                continue;
            }

            yaw = getyawtoorigin( self.enemy.origin );

            if ( abs( yaw ) > 45 )
            {
                wait_network_frame();
                continue;
            }

            if ( !bullettracepassed( origin, test_origin, 0, undefined ) )
            {
                wait_network_frame();
                continue;
            }

            self.is_headbutt = 1;
            self thread astro_turn_player();
            time = self getanimlengthfromasd( "zm_headbutt", 0 );
            self.player_to_headbutt thread astro_restore_move_speed( time );
            self animscripted( self.origin, self.angles, "zm_headbutt" );
            wait( time );
            self.next_headbutt_time = gettime() + level.astro_headbutt_delay;
            self.is_headbutt = 0;
        }

        wait_network_frame();
    }
}

astro_restore_move_speed( time )
{
    self endon( "disconnect" );
    wait( time );
    self allowjump( 1 );
    self allowprone( 1 );
    self allowcrouch( 1 );
    self setmovespeedscale( 1 );
}

astro_turn_player()
{
    self endon( "death" );
    self.player_to_headbutt = self.enemy;
    player = self.player_to_headbutt;
    up = player.origin + vectorscale( ( 0, 0, 1 ), 10 );
    facing_astro = vectortoangles( self.origin - up );
    player thread astro_watch_controls( self );

    if ( self.health > 0 )
        player freezecontrols( 1 );

    lerp_time = 0.2;
    enemy_to_player = vectornormalize( player.origin - self.origin );
    link_org = self.origin + 40 * enemy_to_player;
    player lerp_player_view_to_position( link_org, facing_astro, lerp_time, 1 );
    wait( lerp_time );
    player freezecontrols( 0 );
    player allowjump( 0 );
    player allowstand( 1 );
    player allowprone( 0 );
    player allowcrouch( 0 );
    player setmovespeedscale( 0.1 );
    player notify( "released" );
    dist = distance( self.origin, player.origin );
}

lerp_player_view_to_position( origin, angles, lerptime, fraction, right_arc, left_arc, top_arc, bottom_arc, hit_geo )
{
    if ( isplayer( self ) )
        self endon( "disconnect" );

    linker = spawn( "script_origin", ( 0, 0, 0 ) );
    linker.origin = self.origin;
    linker.angles = self getplayerangles();

    if ( isdefined( hit_geo ) )
        self playerlinkto( linker, "", fraction, right_arc, left_arc, top_arc, bottom_arc, hit_geo );
    else if ( isdefined( right_arc ) )
        self playerlinkto( linker, "", fraction, right_arc, left_arc, top_arc, bottom_arc );
    else if ( isdefined( fraction ) )
        self playerlinkto( linker, "", fraction );
    else
        self playerlinkto( linker );

    linker moveto( origin, lerptime, lerptime * 0.25 );
    linker rotateto( angles, lerptime, lerptime * 0.25 );
    linker waittill( "movedone" );
    linker delete();
}

astro_watch_controls( astro )
{
    self endon( "released" );
    self endon( "disconnect" );
    animlen = astro getanimlengthfromasd( "zm_headbutt", 0 );
    time = 0.5 + animlen;
    astro waittill_notify_or_timeout( "death", time );
    self freezecontrols( 0 );
}

astro_zombie_headbutt_watcher( animname )
{
    self endon( "death" );

    while ( true )
    {
        self waittillmatch( animname, "fire" );

        if ( !isdefined( self.player_to_headbutt ) || !is_player_valid( self.player_to_headbutt ) )
            continue;

        self thread astro_zombie_attack();
        self thread astro_zombie_teleport_enemy();
    }
}

astro_zombie_headbutt_release_watcher( animname )
{
    self endon( "death" );
    _release_dist = 59;

    while ( true )
    {
        self waittillmatch( animname, "headbutt_start" );
        player = self.player_to_headbutt;

        if ( !isdefined( player ) || !isalive( player ) )
            continue;

        dist = distance( player.origin, self.origin );

        if ( dist < _release_dist )
            continue;

        player allowjump( 1 );
        player allowprone( 1 );
        player allowcrouch( 1 );
        player setmovespeedscale( 1 );
        time = self getanimlengthfromasd( "zm_headbutt_release", 0 );
        self animscripted( self.origin, self.angles, "zm_headbutt_release" );
        wait( time );
    }
}

astro_zombie_attack()
{
    self endon( "death" );

    if ( !isdefined( self.player_to_headbutt ) )
        return;

    player = self.player_to_headbutt;
    perk_list = [];
    vending_triggers = getentarray( "zombie_vending", "targetname" );

    for ( i = 0; i < vending_triggers.size; i++ )
    {
        perk = vending_triggers[i].script_noteworthy;

        if ( player hasperk( perk ) )
            perk_list[perk_list.size] = perk;
    }

    take_perk = 0;

    if ( perk_list.size > 0 && !isdefined( player._retain_perks ) )
    {
        take_perk = 1;
        perk_list = array_randomize( perk_list );
        perk = perk_list[0];
        perk_str = perk + "_stop";
        player notify( perk_str );

        if ( flag( "solo_game" ) && perk == "specialty_quickrevive" )
            player.lives--;

        player thread astro_headbutt_damage( self, self.origin );
    }

    if ( !take_perk )
    {
        damage = player.health - 1;
        player dodamage( damage, self.origin, self );
    }
}

astro_headbutt_damage( astro, org )
{
    self endon( "disconnect" );
    self waittill( "perk_lost" );
    damage = self.health - 1;

    if ( isdefined( astro ) )
        self dodamage( damage, astro.origin, astro );
    else
        self dodamage( damage, org );
}

astro_zombie_teleport_enemy()
{
    self endon( "death" );
    player = self.player_to_headbutt;
    black_hole_teleport_structs = getstructarray( "struct_black_hole_teleport", "targetname" );
    chosen_spot = undefined;

    if ( isdefined( level._special_blackhole_bomb_structs ) )
        black_hole_teleport_structs = [[ level._special_blackhole_bomb_structs ]]();

    player_current_zone = player get_current_zone();

    if ( !isdefined( black_hole_teleport_structs ) || black_hole_teleport_structs.size == 0 || !isdefined( player_current_zone ) )
        return;

    black_hole_teleport_structs = array_randomize( black_hole_teleport_structs );

    for ( i = 0; i < black_hole_teleport_structs.size; i++ )
    {
        volume = level.zones[black_hole_teleport_structs[i].script_string].volumes[0];
        zone_enabled = maps\mp\zombies\_zm_zonemgr::get_zone_from_position( black_hole_teleport_structs[i].origin, 0 );

        if ( isdefined( zone_enabled ) && player_current_zone != black_hole_teleport_structs[i].script_string )
        {
            if ( !flag( "power_on" ) || volume.script_string == "lowgravity" )
            {
                chosen_spot = black_hole_teleport_structs[i];
                break;
            }
            else
                chosen_spot = black_hole_teleport_structs[i];

            continue;
        }

        if ( isdefined( zone_enabled ) )
            chosen_spot = black_hole_teleport_structs[i];
    }

    if ( isdefined( chosen_spot ) )
        player thread astro_zombie_teleport( chosen_spot );
}

astro_zombie_teleport( struct_dest )
{
    self endon( "death" );

    if ( !isdefined( struct_dest ) )
        return;

    prone_offset = vectorscale( ( 0, 0, 1 ), 49 );
    crouch_offset = vectorscale( ( 0, 0, 1 ), 20 );
    stand_offset = ( 0, 0, 0 );
    destination = undefined;

    if ( self getstance() == "prone" )
        destination = struct_dest.origin + prone_offset;
    else if ( self getstance() == "crouch" )
        destination = struct_dest.origin + crouch_offset;
    else
        destination = struct_dest.origin + stand_offset;

    if ( isdefined( level._black_hole_teleport_override ) )
        level [[ level._black_hole_teleport_override ]]( self );

    self freezecontrols( 1 );
    self disableoffhandweapons();
    self disableweapons();
    self dontinterpolate();
    self setorigin( destination );
    self setplayerangles( struct_dest.angles );
    self enableoffhandweapons();
    self enableweapons();
    self freezecontrols( 0 );
    earthquake( 0.8, 0.75, self.origin, 1000, self );
    playrumbleonposition( "explosion_generic", self.origin );
    self playsoundtoplayer( "zmb_gersh_teleporter_go_2d", self );
}

astro_zombie_die()
{
    playfxontag( level._effect["astro_explosion"], self, "J_SpineLower" );
    self stoploopsound( 1 );
    self playsound( "evt_astro_zombie_explo" );
    self thread astro_delay_delete();
    self thread astro_player_pulse();
    level.num_astro_zombies--;
    level.next_astro_round = level.round_number + randomintrange( level.min_astro_round_wait, level.max_astro_round_wait + 1 );
    level.zombie_total_update = 0;
    return self maps\mp\zombies\_zm_spawner::zombie_death_animscript();
}

astro_delay_delete()
{
    self endon( "death" );
    self setplayercollision( 0 );
    self thread maps\mp\zombies\_zm_spawner::zombie_eye_glow_stop();
    wait_network_frame();
    self ghost();
    wait_network_frame();
    self delete();
}

astro_player_pulse()
{
    eye_org = self geteye();
    foot_org = self.origin + vectorscale( ( 0, 0, 1 ), 8 );
    mid_org = ( foot_org[0], foot_org[1], ( foot_org[2] + eye_org[2] ) / 2 );
    astro_org = self.origin;

    if ( isdefined( self.player_to_headbutt ) )
    {
        self.player_to_headbutt allowjump( 1 );
        self.player_to_headbutt allowprone( 1 );
        self.player_to_headbutt allowcrouch( 1 );
        self.player_to_headbutt unlink();
        wait_network_frame();
        wait_network_frame();
    }

    players = level.players;

    for ( i = 0; i < players.size; i++ )
    {
        player = players[i];

        if ( !is_player_valid( player ) )
            continue;

        test_org = player geteye();
        explode_radius = level.astro_explode_radius;

        if ( distancesquared( eye_org, test_org ) > explode_radius * explode_radius )
            continue;

        test_org_foot = player.origin + vectorscale( ( 0, 0, 1 ), 8 );
        test_org_mid = ( test_org_foot[0], test_org_foot[1], ( test_org_foot[2] + test_org[2] ) / 2 );

        if ( !bullettracepassed( eye_org, test_org, 0, undefined ) )
        {
            if ( !bullettracepassed( mid_org, test_org_mid, 0, undefined ) )
            {
                if ( !bullettracepassed( foot_org, test_org_foot, 0, undefined ) )
                    continue;
            }
        }

        dist = distance( eye_org, test_org );
        scale = 1 - dist / explode_radius;

        if ( scale < 0 )
            scale = 0;

        bonus = ( level.astro_explode_pulse_max - level.astro_explode_pulse_min ) * scale;
        pulse = level.astro_explode_pulse_min + bonus;
        dir = ( player.origin[0] - astro_org[0], player.origin[1] - astro_org[1], 0 );
        dir = vectornormalize( dir );
        dir = dir + ( 0, 0, 1 );
        dir = dir * pulse;
        player setorigin( player.origin + ( 0, 0, 1 ) );
        player_velocity = dir;
        player setvelocity( player_velocity );

        if ( isdefined( level.ai_astro_explode ) )
            player thread [[ level.ai_astro_explode ]]( mid_org );
    }
}

astro_actor_damage( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime )
{
    self endon( "death" );

    switch ( weapon )
    {
        case "microwavegundw_upgraded_zm":
        case "microwavegundw_zm":
            damage = 0;
            break;
    }

    return damage;
}

astro_custom_damage( player )
{
    damage = self.meleedamage;

    if ( self.is_headbutt )
        damage = player.health - 1;

    return damage;
}

astro_microwavegun_sizzle( player )
{

}

zombie_set_fake_playername()
{
    self setzombiename( "SpaceZom" );
}

moon_astro_enter_level()
{
    self endon( "death" );
    self ghost();
    self.entered_level = 1;
    astro_struct = self moon_astro_get_spawn_struct();

    if ( isdefined( astro_struct ) )
    {
        self forceteleport( astro_struct.origin, astro_struct.angles );
        wait_network_frame();
    }

    playfx( level._effect["astro_spawn"], self.origin );
    self playsound( "zmb_hellhound_bolt" );
    self playsound( "zmb_hellhound_spawn" );
    playrumbleonposition( "explosion_generic", self.origin );
    self playloopsound( "zmb_zombie_astronaut_loop", 1 );
    self thread play_line_if_player_can_see();
    self zombie_set_fake_playername();
    wait_network_frame();
    self show();
}

play_line_if_player_can_see()
{
    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( distancesquared( self.origin, players[i].origin ) <= 640000 )
        {
            cansee = self maps\mp\zm_moon_distance_tracking::player_can_see_me( players[i] );

            if ( cansee )
            {
                players[i] thread maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "astro_spawn" );
                return;
            }
        }
    }
}

moon_astro_get_spawn_struct()
{
    keys = getarraykeys( level.zones );

    for ( i = 0; i < level.zones.size; i++ )
    {
        if ( keys[i] == "nml_zone" )
            continue;

        if ( level.zones[keys[i]].is_occupied )
        {
            locs = getstructarray( level.zones[keys[i]].volumes[0].target + "_astro", "targetname" );

            if ( isdefined( locs ) && locs.size > 0 )
            {
                locs = array_randomize( locs );
                return locs[0];
            }
        }
    }

    for ( i = 0; i < level.zones.size; i++ )
    {
        if ( keys[i] == "nml_zone" )
            continue;

        if ( level.zones[keys[i]].is_active )
        {
            locs = getstructarray( level.zones[keys[i]].volumes[0].target + "_astro", "targetname" );

            if ( isdefined( locs ) && locs.size > 0 )
            {
                locs = array_randomize( locs );
                return locs[0];
            }
        }
    }

    return undefined;
}

astro_damage_callback( mod, hit_location, hit_origin, player, amount )
{
    if ( isdefined( self.animname ) && self.animname == "astro_zombie" )
        return true;

    return false;
}
