#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Shangri-La fixes (baby gun targets, one special zombie per round, screamer spawn freeze). Log: "TEMPLESPECIALS >>".
// 1) Baby gun (31-79 JGb215): shrinks napalm zombies and screamers and kills monkeys again. DLC5's
//    shrink_ray_get_enemies_in_range took its targets from get_round_enemy_array(), which skips every AI marked
//    ignore_enemy_count - and the napalm zombie, the screamer and the monkeys all are - so they were never hit. BO1 used
//    every AI (GetAISpeciesArray( "axis", "all" )); this is DLC5's function with BO1's list. The shrinking itself (and
//    the monkey kill) is DLC5's own code in shrink_zombie, unchanged.
// 2) Never a napalm zombie and a screamer (sonic zombie) in the same round. BO1 spawned its special zombies from inside
//    the one round-spawn loop (zombie_temple_spawning.gsc: _try_spawn_napalm / _try_spawn_sonic +
//    level.special_zombie_spawned_this_round), so only one could come per round. The port gives each its own spawn
//    thread and only marks the round (level.last_special_zombie_round) once the zombie has spawned, so both checks could
//    pass before either marked it. This replaces DLC5's sonic_spawn_check with the same rules plus an immediate claim of
//    the round; the napalm side (mods\dlc5\maps\mp\zombies\_zm_ai_napalm.gsc) claims the same way.

main()
{
    if ( getdvar( "mapname" ) != "zm_temple" )
        return;

    f = getfunction( "maps/mp/zombies/_zm_ai_sonic", "sonic_spawn_check" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::templespecials_sonic_spawn_check, -1 );
        println( "TEMPLESPECIALS >> sonic_spawn_check replaced (one special zombie per round)" );
    }
    else
        println( "TEMPLESPECIALS >> sonic_spawn_check not found" );

    f = getfunction( "maps/mp/zombies/_zm_ai_sonic", "do_sonic_spawn" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::templespecials_do_sonic_spawn, -1 );
        println( "TEMPLESPECIALS >> screamer spawns without the rise animation (BO1-style)" );
    }
    else
        println( "TEMPLESPECIALS >> do_sonic_spawn not found" );

    // 4) Logo2K's usermaps zzz_zz_zzzzzzzztemplespecials.gsc (spawn fx/sounds) starts the looping drones
    //    evt_sonic_ambient_loop / evt_napalm_zombie_loop with playsound, which can never be stopped - they outlive the
    //    zombie and its deleted corpse (suspected cause of the reported screamer freeze; deleting his script was
    //    reported to stop it). Same functions, but both drones are real loops that stop when the zombie dies.
    //    His file is not changed.
    f = getfunction( "scripts/zm/zzz_zz_zzzzzzzztemplespecials", "tspec_sonic" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::templespecials_tspec_sonic, -1 );
        println( "TEMPLESPECIALS >> tspec_sonic replaced (drone stops on death)" );
    }

    f = getfunction( "scripts/zm/zzz_zz_zzzzzzzztemplespecials", "tspec_napalm" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::templespecials_tspec_napalm, -1 );
        println( "TEMPLESPECIALS >> tspec_napalm replaced (loop stops on death)" );
    }

    f = getfunction( "maps/mp/zombies/_zm_weap_shrink_ray", "shrink_ray_get_enemies_in_range" );

    if ( isdefined( f ) )
    {
        replacefunc( f, ::templespecials_shrink_targets, -1 );
        println( "TEMPLESPECIALS >> baby gun targets every zombie again (napalm, screamer, monkeys)" );
    }
    else
        println( "TEMPLESPECIALS >> shrink_ray_get_enemies_in_range not found" );
}

init()
{
}

// 3) Screamer freezing the game when it spawns. DLC5's do_sonic_spawn (decompiled from zm_temple.ff) makes it climb out
//    of the ground with stock do_zombie_rise, which plays the "zm_rise" state on the screamer's own animation set
//    (actor_zm_temple_sonic). BO1's screamer never rose - it had its own "sonic_spawn" animation - and the napalm
//    zombie, which uses the same spawn points and works, doesn't rise either. So it appears on its spot BO1-style: BO1's
//    spawn effect and sound, then "risen" so the stock zombie logic carries on exactly as after DLC5's rise.
templespecials_do_sonic_spawn()
{
    self endon( "death" );
    spot = self.spawn_point_override;
    self.spawn_point = spot;

    if ( !isdefined( spot ) )
    {
        self.in_the_ground = 0;
        self notify( "risen" );
        return;
    }

    if ( isdefined( spot.target ) )
        self.target = spot.target;

    if ( isdefined( spot.zone_name ) )
        self.zone_name = spot.zone_name;

    if ( isdefined( spot.script_parameters ) )
        self.script_parameters = spot.script_parameters;

    angles = ( 0, 0, 0 );

    if ( isdefined( spot.angles ) )
        angles = spot.angles;

    self forceteleport( spot.origin, angles );
    self.in_the_ground = 0;

    if ( isdefined( level._effect["sonic_spawn"] ) )
        playfx( level._effect["sonic_spawn"], spot.origin, ( 0, 0, 1 ) );

    self playsound( "evt_sonic_spawn" );
    println( "TEMPLESPECIALS >> screamer spawned at " + spot.origin );
    wait_network_frame();
    self notify( "risen", spot.script_string );
}

// DLC5's shrink_ray_get_enemies_in_range with BO1's target list (all AI, not only the ones that count for the round)
templespecials_shrink_targets( upgraded, shrinkable_objects )
{
    range = 480;
    radius = 60;

    if ( upgraded )
    {
        range = 1200;
        radius = 84;
    }

    hitzombies = [];
    view_pos = self getweaponmuzzlepoint();

    if ( shrinkable_objects )
    {
        test_list = level._shrinkable_objects;
        range = range * 5;
    }
    else
        test_list = getaispeciesarray( level.zombie_team, "all" );

    if ( !isdefined( test_list ) )
        return hitzombies;

    zombies = get_array_of_closest( view_pos, test_list, undefined, undefined, range * 1.1 );

    if ( !isdefined( zombies ) )
        return hitzombies;

    range_squared = range * range;
    radius_squared = radius * radius;
    forward_view_angles = self getweaponforwarddir();
    end_pos = view_pos + vectorscale( forward_view_angles, range );

    for ( i = 0; i < zombies.size; i++ )
    {
        if ( !isdefined( zombies[i] ) || isai( zombies[i] ) && !isalive( zombies[i] ) )
            continue;

        if ( isdefined( zombies[i].shrinked ) && zombies[i].shrinked )
            continue;

        if ( isdefined( zombies[i].no_shrink ) && zombies[i].no_shrink )
            continue;

        test_origin = zombies[i] getcentroid();
        test_range_squared = distancesquared( view_pos, test_origin );

        if ( test_range_squared > range_squared )
            break;

        normal = vectornormalize( test_origin - view_pos );
        dot = vectordot( forward_view_angles, normal );

        if ( 0 > dot )
            continue;

        radial_origin = pointonsegmentnearesttopoint( view_pos, end_pos, test_origin );

        if ( distancesquared( test_origin, radial_origin ) > radius_squared )
            continue;

        if ( 0 == zombies[i] damageconetrace( view_pos, self ) )
            continue;

        hitzombies[hitzombies.size] = zombies[i];
    }

    return hitzombies;
}

// DLC5's sonic_spawn_check rules (BO1's _can_spawn_sonic + the port's checks), claiming the round when it passes
templespecials_sonic_spawn_check()
{
    if ( !isdefined( level.soniczombiesenabled ) || !level.soniczombiesenabled )
        return false;

    if ( !isdefined( level.sonic_zombie_spawners ) || level.sonic_zombie_spawners.size == 0 )
        return false;

    if ( !isdefined( level.zombie_napalm_locations ) || level.zombie_napalm_locations.size == 0 )
        return false;

    if ( isdefined( level.soniczombiecount ) && level.soniczombiecount > 0 )
        return false;

    // never with a napalm zombie alive
    if ( isdefined( level.napalmzombiecount ) && level.napalmzombiecount > 0 )
        return false;

    if ( !isdefined( level.last_special_zombie_round ) )
        level.last_special_zombie_round = 0;

    if ( level.last_special_zombie_round >= level.round_number )
        return false;

    if ( getdvarint( "zombiemode_debug_sonic" ) == 0 )
    {
        if ( !isdefined( level.nextsonicspawnround ) || level.nextsonicspawnround > level.round_number )
            return false;

        if ( level.zombie_total == 0 )
            return false;

        if ( !isdefined( level.zombiesleftbeforesonicspawn ) || level.zombie_total >= level.zombiesleftbeforesonicspawn )
            return false;
    }

    level.last_special_zombie_round = level.round_number;
    println( "TEMPLESPECIALS >> screamer gets round " + level.round_number );
    return true;
}

// Logo2K's tspec_sonic (scream, spawn fx, drone), with the drone as a real loop that stops when the screamer dies
// (his version started it with playsound, so it could never stop and outlived the deleted corpse)
templespecials_tspec_sonic()
{
    self endon( "death" );
    self playsound( "evt_sonic_spawn" );
    templespecials_callout( "sonic_spawn" );
    wait 0.3;

    if ( !isdefined( self ) || !isalive( self ) )
        return;

    self playsound( "zmb_vocals_sonic_scream" );

    if ( isdefined( level._effect ) && isdefined( level._effect["sonic_spawn"] ) )
        playfx( level._effect["sonic_spawn"], self.origin );

    self thread templespecials_death_loop( "evt_sonic_ambient_loop" );
    println( "TSPEC >> sonic lit (drone stops on death)" );
}

// Logo2K's tspec_napalm, with the burning loop as a real loop that ends with the napalm zombie
templespecials_tspec_napalm()
{
    if ( isdefined( level._effect ) && isdefined( level._effect["napalm_spawn"] ) )
        playfx( level._effect["napalm_spawn"], self.origin );

    self playsound( "evt_napalm_zombie_spawn" );
    templespecials_callout( "napalm_spawn" );

    if ( isdefined( level._effect ) )
    {
        if ( isdefined( level._effect["napalm_fire_torso"] ) )
            playfxontag( level._effect["napalm_fire_torso"], self, "J_SpineLower" );

        if ( isdefined( level._effect["napalm_distortion"] ) )
            playfxontag( level._effect["napalm_distortion"], self, "tag_origin" );

        if ( getdvar( "templeburn_arms" ) != "0" && isdefined( level._effect["napalm_fire_forearm"] ) )
        {
            playfxontag( level._effect["napalm_fire_forearm"], self, "J_Wrist_RI" );
            playfxontag( level._effect["napalm_fire_forearm"], self, "J_Wrist_LE" );
            playfxontag( level._effect["napalm_fire_forearm"], self, "J_Head" );
        }
    }

    self thread templespecials_death_loop( "evt_napalm_zombie_loop" );
    println( "TSPEC >> napalm lit" );
}

templespecials_death_loop( alias )
{
    self playloopsound( alias, 0.5 );
    self waittill( "death" );

    if ( isdefined( self ) )
        self stoploopsound( 0.25 );
}

// Logo2K's tspec_callout
templespecials_callout( key )
{
    players = getplayers();

    if ( players.size < 1 )
        return;

    p = players[randomint( players.size )];

    if ( isdefined( p ) )
        p thread maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", key );
}
