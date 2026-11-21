// Fr0sty - DLC5 additions. Gersh Device fixes by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// This is Logo2K's Zombies Declassified Gersh Device script (maps/mp/zombies/_zm_weap_black_hole_bomb, used by
// Ascension, Shangri-La and Moon) with fixes. Every change is marked "Fr0sty:". Log lines start with "BHBFIX >>".
//   - a Gersh that stops on a wall, ledge or ceiling is no longer taken by Samantha: the black hole opens on the
//     floor under it (or at the nearest walkable spot), and only a throw that really left the map is taken
//   - zombies no longer keep running off after a black hole: each zombie is pulled by ONE black hole at a time
//     (the port started a new pull thread every time the zombie re-pathed), its walk is changed through its move
//     speed (so the move script can't lose or keep the pulled walk), and when the hole closes it gets its own
//     speed back and re-targets the players at once. A watchdog resets any zombie still left in a pulled walk.

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_spawner;
#include maps\mp\zombies\_zm_audio;

init()
{
    if ( !black_hole_bomb_exists() )
        return;

    level._effect["black_hole_bomb_portal"] = loadfx( "maps/zombie/fx_zmb_blackhole_looping" );
    level._effect["black_hole_bomb_portal_exit"] = loadfx( "maps/zombie/fx_zmb_blackhole_exit" );
    level._effect["black_hole_bomb_zombie_soul"] = loadfx( "maps/zombie/fx_zmb_blackhole_zombie_death" );
    level._effect["black_hole_bomb_zombie_destroy"] = loadfx( "maps/zombie/fx_zmb_blackhole_zombie_flare" );
    level._effect["black_hole_bomb_zombie_gib"] = loadfx( "maps/zombie/fx_zombie_dog_explosion" );
    level._effect["black_hole_bomb_event_horizon"] = loadfx( "maps/zombie/fx_zmb_blackhole_implode" );
    level._effect["black_hole_samantha_steal"] = loadfx( "maps/zombie/fx_zmb_blackhole_trap_end" );
    level._effect["black_hole_bomb_zombie_pull"] = loadfx( "maps/zombie/fx_blackhole_zombie_breakup" );
    level._effect["black_hole_bomb_marker_flare"] = loadfx( "maps/zombie/fx_zmb_blackhole_flare_marker" );
    registerclientfield( "scriptmover", "blackhole", 15000, 1, "int" );
    registerclientfield( "actor", "blackhole", 15000, 1, "int" );
    level.zombie_death_animscript_override = ::black_hole_bomb_corpse_hide;
    level.black_hole_bomb_poi_initial_attract_func = ::black_hole_bomb_initial_attract_func;
    level.black_hole_bomb_poi_arrival_attract_func = ::black_hole_bomb_arrival_attract_func;
    level._black_hole_bomb_zombies_anim_change = [];
    flag_init( "bhb_anim_change_allowed" );
    level thread black_hole_bomb_throttle_anim_changes();
    flag_set( "bhb_anim_change_allowed" );
    // Fr0sty: safety net for zombies left in a pulled walk
    level thread black_hole_bomb_stuck_watch();
    println( "BHBFIX >> Gersh Device fixes on " + getdvar( "mapname" ) );
}

player_give_black_hole_bomb()
{
    self giveweapon( "zombie_black_hole_bomb" );
    self set_player_tactical_grenade( "zombie_black_hole_bomb" );
    self thread player_handle_black_hole_bomb();
}

player_handle_black_hole_bomb()
{
    self notify( "starting_black_hole_bomb" );
    self endon( "disconnect" );
    self endon( "starting_black_hole_bomb" );
    attract_dist_diff = level.black_hole_attract_dist_diff;

    if ( !isdefined( attract_dist_diff ) )
        attract_dist_diff = 10;

    num_attractors = level.num_black_hole_bomb_attractors;

    if ( !isdefined( num_attractors ) )
        num_attractors = 15;

    max_attract_dist = level.black_hole_bomb_attract_dist;

    if ( !isdefined( max_attract_dist ) )
        max_attract_dist = 2056;

    while ( true )
    {
        grenade = get_thrown_black_hole_bomb();

        if ( isdefined( grenade ) )
        {
            if ( self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || is_true( self.intermission ) )
            {
                grenade delete();
                continue;
            }

            grenade hide();
            model = spawn( "script_model", grenade.origin );
            str_weap_model = getweaponmodel( "zombie_black_hole_bomb" );
            model setmodel( str_weap_model );
            model linkto( grenade );
            model.angles = grenade.angles;
            info = spawnstruct();
            info.sound_attractors = [];
            grenade thread monitor_zombie_groans( info );

            // Fr0sty: wait until it has really settled (still for two checks in a row, not the top of a bounce) and
            // remember the way it was travelling, to step back off a wall it hit
            still = 0;
            last_move = ( 0, 0, 0 );
            oldpos = grenade.origin;

            while ( still < 2 )
            {
                wait 0.05;

                if ( !isdefined( grenade ) )
                    break;

                move = grenade.origin - oldpos;

                if ( lengthsquared( move ) < 0.25 )
                    still++;
                else
                {
                    still = 0;
                    last_move = move;
                }

                oldpos = grenade.origin;
            }

            if ( isdefined( grenade ) )
            {
                self thread black_hole_bomb_kill_counter( grenade );
                model unlink();
                model.origin = grenade.origin;
                model.angles = grenade.angles;
                model._black_hole_bomb_player = self;
                model.targetname = "zm_bhb";
                model._new_ground_trace = 1;
                grenade resetmissiledetonationtime();

                if ( isdefined( level.black_hole_bomb_loc_check_func ) )
                {
                    if ( [[ level.black_hole_bomb_loc_check_func ]]( grenade, model, info ) )
                        continue;
                }

                if ( isdefined( level._blackhole_bomb_valid_area_check ) )
                {
                    if ( [[ level._blackhole_bomb_valid_area_check ]]( grenade, model, self ) )
                        continue;
                }

                // Fr0sty: open the black hole on the floor under where it stopped (walls, ledges, ceilings)
                spot = black_hole_bomb_find_spot( grenade, last_move );

                if ( isdefined( spot ) )
                {
                    if ( distancesquared( spot, grenade.origin ) > 4 )
                    {
                        println( "BHBFIX >> Gersh stopped at " + grenade.origin + ", black hole moved to the floor at " + spot );
                        model.origin = spot;
                        model.angles = ( 0, grenade.angles[1], 0 );
                    }

                    valid_poi = 1;
                }
                else
                    valid_poi = 0;

                if ( valid_poi )
                {
                    level thread black_hole_bomb_cleanup( grenade, model );

                    if ( isdefined( level._black_hole_bomb_poi_override ) )
                        model thread [[ level._black_hole_bomb_poi_override ]]();

                    model create_zombie_point_of_interest( max_attract_dist, num_attractors, 0, 1, level.black_hole_bomb_poi_initial_attract_func, level.black_hole_bomb_poi_arrival_attract_func );
                    model setclientfield( "blackhole", 1 );
                    grenade thread do_black_hole_bomb_sound( model, info );
                    level thread black_hole_bomb_teleport_init( grenade, model.origin );
                    grenade.is_valid = 1;
                }
                else
                {
                    println( "BHBFIX >> Gersh at " + grenade.origin + " is outside the playable map, Samantha takes it" );
                    self.script_noteworthy = undefined;
                    level thread black_hole_bomb_stolen_by_sam( self, model );
                }
            }
            else
            {
                self.script_noteworthy = undefined;
                level thread black_hole_bomb_stolen_by_sam( self, model );
            }
        }

        wait 0.05;
    }
}

// Fr0sty: where the black hole opens. The port only accepted the exact spot the Gersh stopped at, and a Gersh
// resting on a wall, a ledge edge or a ceiling is usually just outside the map's zone volumes, so Samantha took it.
// Returns undefined only when there is no playable floor near it.
black_hole_bomb_find_spot( grenade, last_move )
{
    org = grenade.origin;
    starts = [];
    starts[starts.size] = org;

    // a step back along the throw gets it off the wall it hit
    if ( lengthsquared( last_move ) > 0 )
    {
        back = vectornormalize( ( last_move[0], last_move[1], 0 ) );
        starts[starts.size] = org - back * 16;
        starts[starts.size] = org - back * 40;
    }

    for ( i = 0; i < starts.size; i++ )
    {
        // starts just above the Gersh: from higher up it could begin inside a ceiling it is stuck to
        trace = bullettrace( starts[i] + ( 0, 0, 1 ), starts[i] - ( 0, 0, 1024 ), 0, grenade );

        if ( trace["fraction"] >= 1 || trace["fraction"] <= 0 )
            continue;

        ground = trace["position"];

        if ( check_point_in_enabled_zone( ground, undefined, undefined ) && black_hole_bomb_spot_walkable( ground ) )
            return ground;
    }

    if ( check_point_in_enabled_zone( org, undefined, undefined ) && black_hole_bomb_spot_walkable( org ) )
        return org;

    // last try: the nearest path node the zombies can walk to
    nodes = getnodesinradiussorted( org, 256, 0, 256, "path" );

    for ( i = 0; i < nodes.size; i++ )
    {
        if ( check_point_in_enabled_zone( nodes[i].origin, undefined, undefined ) )
            return nodes[i].origin;
    }

    return undefined;
}

// Fr0sty: a spot counts only if zombies can walk to it - a path node close by at about the same height. A Gersh that
// stopped on top of pipes / beams near a tunnel ceiling (Moon's tunnel 11) is still inside the zone volume, and a black
// hole opened up there dragged zombies up into the roof; such a spot now falls through to the nearest path node.
black_hole_bomb_spot_walkable( spot )
{
    nodes = getnodesinradiussorted( spot, 96, 0, 48, "path" );
    return nodes.size > 0;
}

wait_for_attractor_positions_complete()
{
    self waittill( "attractor_positions_generated" );
    self.attract_to_origin = 0;
}

black_hole_bomb_cleanup( parent, model )
{
    model endon( "sam_stole_it" );
    grenade_org = parent.origin;

    while ( true )
    {
        if ( !isdefined( parent ) )
        {
            if ( isdefined( model ) )
            {
                model delete();
                wait_network_frame();
            }

            break;
        }

        wait 0.05;
    }

    level thread black_hole_bomb_corpse_collect( grenade_org );
}

black_hole_bomb_corpse_collect( vec_origin )
{
    wait 0.1;
    corpse_array = getcorpsearray();

    for ( i = 0; i < corpse_array.size; i++ )
    {
        if ( distancesquared( corpse_array[i].origin, vec_origin ) < 36864 )
            corpse_array[i] thread black_hole_bomb_corpse_delete();
    }
}

black_hole_bomb_corpse_delete()
{
    self delete();
}

do_black_hole_bomb_sound( model, info )
{
    monk_scream_vox = 0;

    if ( level.music_override == 0 )
        monk_scream_vox = 0;

    self playsound( "wpn_gersh_device_exp" );
    self playloopsound( "wpn_gersh_device_loop_close" );
    fakeorigin = self.origin;
    self waittill( "explode", position );
    playsoundatposition( "wpn_gersh_device_implode", fakeorigin );

    for ( i = 0; i < info.sound_attractors.size; i++ )
    {
        if ( isdefined( info.sound_attractors[i] ) )
            info.sound_attractors[i] notify( "black_hole_bomb_blown_up" );
    }

    if ( !monk_scream_vox )
        play_sound_in_space( "zmb_vox_monkey_explode", position );
}

get_thrown_black_hole_bomb()
{
    self endon( "disconnect" );
    self endon( "starting_black_hole_bomb" );

    while ( true )
    {
        self waittill( "grenade_fire", grenade, weapname );

        if ( weapname == "zombie_black_hole_bomb" )
            return grenade;

        wait 0.05;
    }
}

monitor_zombie_groans( info )
{
    self endon( "explode" );

    while ( true )
    {
        if ( !isdefined( self ) )
            return;

        if ( !isdefined( self.attractor_array ) )
        {
            wait 0.05;
            continue;
        }

        for ( i = 0; i < self.attractor_array.size; i++ )
        {
            if ( array_check_for_dupes( info.sound_attractors, self.attractor_array[i] ) )
            {
                if ( isdefined( self.origin ) && isdefined( self.attractor_array[i].origin ) )
                {
                    if ( distancesquared( self.origin, self.attractor_array[i].origin ) < 250000 )
                    {
                        info.sound_attractors[info.sound_attractors.size] = self.attractor_array[i];
                        self.attractor_array[i] thread play_zombie_groans();
                    }
                }
            }
        }

        wait 0.05;
    }
}

play_zombie_groans()
{
    self endon( "death" );
    self endon( "black_hole_bomb_blown_up" );

    while ( true )
    {
        if ( isdefined( self ) )
        {
            self playsound( "zmb_vox_zombie_groan" );
            wait( randomfloatrange( 2, 3 ) );
        }
        else
            return;
    }
}

black_hole_bomb_exists()
{
    return isdefined( level.zombie_weapons["zombie_black_hole_bomb"] );
}

black_hole_bomb_initial_attract_func( ent_poi )
{
    self endon( "death" );

    if ( isdefined( self.pre_black_hole_bomb_run_combatanim ) )
        return;

    // Fr0sty: the stock point-of-interest code calls this every time the zombie re-paths (every 1-3 seconds) for as
    // long as the black hole lasts. BO1 stopped the repeats with pre_black_hole_bomb_run_combatanim, which the port
    // never sets, so every zombie piled up pull threads. One pull per zombie per black hole now.
    if ( isdefined( self._bhb_attract_poi ) && self._bhb_attract_poi == ent_poi )
        return;

    self._bhb_attract_poi = ent_poi;

    if ( isdefined( self.script_string ) && self.script_string == "riser" )
    {
        while ( is_true( self.in_the_ground ) )
            wait 0.05;
    }

    soul_spark_end = ent_poi.origin;
    soul_burst_range = 2500;
    pulled_in_range = 16384;
    inner_range = 1048576;
    outer_edge = 4227136;
    distance_to_black_hole = 1410065408;
    self._distance_to_black_hole = 1410065408;
    self._black_hole_bomb_collapse_death = 0;
    self._black_hole_attract_walk = 0;
    self._black_hole_attract_run = 0;
    self._current_black_hole_bomb_origin = ent_poi.origin;
    self._normal_run_blend_time = 0.2;
    self._black_hole_bomb_tosser = ent_poi._black_hole_bomb_player;
    self._black_hole_bomb_being_pulled_in_fx = 0;
    self.deathanim = self black_hole_bomb_death_while_attracted();

    if ( !isdefined( self._bhb_ent_flag_init ) )
    {
        self ent_flag_init( "bhb_anim_change" );
        self._bhb_ent_flag_init = 1;
    }

    if ( isdefined( level._black_hole_attract_override ) )
        level [[ level._black_hole_attract_override ]]();

    // Fr0sty: stop when this zombie is being pulled by a different (newer) black hole
    while ( isdefined( ent_poi ) && isdefined( self._bhb_attract_poi ) && self._bhb_attract_poi == ent_poi )
    {
        self._distance_to_black_hole = distancesquared( self.origin, self._current_black_hole_bomb_origin );

        if ( self._black_hole_attract_walk == 0 && ( self._distance_to_black_hole < outer_edge && self._distance_to_black_hole > inner_range ) )
        {
            if ( isdefined( self._bhb_walk_attract ) )
                self [[ self._bhb_walk_attract ]]();
            else
                self black_hole_bomb_attract_walk();
        }

        if ( self._black_hole_attract_run == 0 && ( self._distance_to_black_hole < inner_range && self._distance_to_black_hole > pulled_in_range ) )
        {
            if ( isdefined( self._bhb_run_attract ) )
                self [[ self._bhb_run_attract ]]();
            else
                self black_hole_bomb_attract_run();
        }

        if ( self._distance_to_black_hole < pulled_in_range && self._distance_to_black_hole > soul_burst_range )
        {
            self._black_hole_bomb_collapse_death = 1;

            if ( isdefined( self._bhb_horizon_death ) )
                self [[ self._bhb_horizon_death ]]( self._current_black_hole_bomb_origin, ent_poi );
            else
                self black_hole_bomb_event_horizon_death( self._current_black_hole_bomb_origin, ent_poi );
        }

        if ( self._distance_to_black_hole < soul_burst_range )
        {
            self._black_hole_bomb_collapse_death = 1;

            if ( isdefined( self._bhb_horizon_death ) )
                self [[ self._bhb_horizon_death ]]( self._current_black_hole_bomb_origin, ent_poi );
            else
                self black_hole_bomb_event_horizon_death( self._current_black_hole_bomb_origin, ent_poi );
        }

        wait 0.1;
    }

    // Fr0sty: a newer black hole took this zombie over; that one does the reset
    if ( isdefined( ent_poi ) && isdefined( self._bhb_attract_poi ) && self._bhb_attract_poi != ent_poi )
        return;

    self._bhb_attract_poi = undefined;
    self thread black_hole_bomb_escaped_zombie_reset();
}

black_hole_bomb_store_movement_anim()
{
    self endon( "death" );
    current_anim = self.run_combatanim;
    anim_keys = getarraykeys( level.scr_anim[self.animname] );

    for ( j = 0; j < anim_keys.size; j++ )
    {
        if ( level.scr_anim[self.animname][anim_keys[j]] == current_anim )
            return anim_keys[j];
    }

    assertmsg( "couldn't find zombie run anim in the array keys" );
}

black_hole_bomb_being_pulled_fx()
{
    self endon( "death" );
    wait_network_frame();
    self setclientfield( "blackhole", 1 );
    self._black_hole_bomb_being_pulled_in_fx = 1;
}

// Fr0sty: the pulled walks go through the zombie's move speed ("zm_move_" + speed, with the no-legs "_crawl" state
// picked by the move script), so the move script keeps it while pulled and puts the normal walk back afterwards.
// The zombie's own speed is saved once and given back by black_hole_bomb_escaped_zombie_reset.
black_hole_bomb_set_pulled_speed( speed )
{
    if ( !isdefined( self._bhb_saved_move_speed ) )
    {
        saved = self.zombie_move_speed;

        if ( !isdefined( saved ) || issubstr( saved, "blackhole" ) )
            saved = "run";

        self._bhb_saved_move_speed = saved;
    }

    self.zombie_move_speed = speed;
    self maps\mp\animscripts\zm_run::needsupdate();
}

black_hole_bomb_attract_walk()
{
    self endon( "death" );
    flag_wait( "bhb_anim_change_allowed" );
    level._black_hole_bomb_zombies_anim_change = add_to_array( level._black_hole_bomb_zombies_anim_change, self, 0 );
    self ent_flag_wait( "bhb_anim_change" );
    self.a.runblendtime = 0.9;
    self._had_legs = self.has_legs;
    self black_hole_bomb_set_pulled_speed( "blackhole_walk" );

    if ( is_true( self.nogravity ) )
    {
        self animmode( "none" );
        self.nogravity = undefined;
    }

    self._black_hole_attract_walk = 1;
    self._bhb_change_anim_notified = 1;
    self.a.runblendtime = self._normal_run_blend_time;
}

black_hole_bomb_attract_run()
{
    self endon( "death" );
    flag_wait( "bhb_anim_change_allowed" );
    level._black_hole_bomb_zombies_anim_change = add_to_array( level._black_hole_bomb_zombies_anim_change, self, 0 );
    self ent_flag_wait( "bhb_anim_change" );
    self.a.runblendtime = 0.9;
    self black_hole_bomb_set_pulled_speed( "blackhole_walk_fast" );

    if ( is_true( self.nogravity ) )
    {
        self animmode( "none" );
        self.nogravity = undefined;
    }

    self._black_hole_attract_run = 1;
    self._bhb_change_anim_notified = 1;
    self.a.runblendtime = self._normal_run_blend_time;
}

black_hole_bomb_death_anim()
{
    self endon( "death" );

    if ( self.has_legs )
        death_animation_state = "zm_black_hole_attracted_death";
    else
        death_animation_state = "zm_black_hole_attracted_death_crawl";

    return death_animation_state;
}

black_hole_bomb_death_while_attracted()
{
    self endon( "death" );
    death_animation_state = undefined;

    if ( self.has_legs )
        death_animation_state = "zm_black_hole_attracted_death";

    return death_animation_state;
}

black_hole_bomb_arrival_attract_func( ent_poi )
{
    self endon( "death" );
    self endon( "zombie_acquire_enemy" );
    self endon( "path_timer_done" );
    soul_spark_end = ent_poi.origin;
    self waittill( "goal" );

    if ( isdefined( self._bhb_horizon_death ) )
        self [[ self._bhb_horizon_death ]]( self._current_black_hole_bomb_origin, ent_poi );
    else
        self black_hole_bomb_event_horizon_death( self._current_black_hole_bomb_origin, ent_poi );
}

black_hole_bomb_event_horizon_death( vec_black_hole_org, grenade )
{
    self endon( "death" );

    if ( !isdefined( grenade ) )
        return;

    self maps\mp\zombies\_zm_spawner::zombie_eye_glow_stop();
    self playsound( "wpn_gersh_device_kill" );
    self.deathanim = black_hole_bomb_death_anim();
    playfxontag( level._effect["black_hole_bomb_zombie_destroy"], self, "tag_origin" );
    grenade notify( "black_hole_bomb_kill" );
    self dodamage( self.health + 50, self.origin + vectorscale( ( 0, 0, 1 ), 50.0 ), self._black_hole_bomb_tosser, grenade, "MOD_CRUSH" );
}

black_hole_bomb_corpse_hide()
{
    if ( isdefined( self._black_hole_bomb_collapse_death ) && self._black_hole_bomb_collapse_death == 1 )
    {
        playfxontag( level._effect["black_hole_bomb_zombie_gib"], self, "tag_origin" );
        self ghost();
    }
}

black_hole_bomb_escaped_zombie_reset()
{
    self endon( "death" );

    // Fr0sty: one reset at a time
    if ( is_true( self._bhb_resetting ) )
        return;

    self._bhb_resetting = 1;
    flag_wait( "bhb_anim_change_allowed" );
    level._black_hole_bomb_zombies_anim_change = add_to_array( level._black_hole_bomb_zombies_anim_change, self, 0 );
    self ent_flag_wait( "bhb_anim_change" );
    self._bhb_resetting = undefined;

    // pulled again by a newer black hole while waiting: leave it to that one
    if ( isdefined( self._bhb_attract_poi ) )
        return;

    self.a.runblendtime = 0.9;

    // Fr0sty: give the zombie its own speed back through the stock run-cycle call (the move script then picks the
    // right walk/run/sprint, crawl or Moon low-gravity walk), not a hard-set "zm_move_run"
    speed = self._bhb_saved_move_speed;

    if ( !isdefined( speed ) && isdefined( self.zombie_move_speed ) && issubstr( self.zombie_move_speed, "blackhole" ) )
        speed = "run";

    self._bhb_saved_move_speed = undefined;

    if ( isdefined( speed ) )
        self set_zombie_run_cycle( speed );

    self.pre_black_hole_bomb_run_combatanim = undefined;
    self._black_hole_attract_walk = 0;
    self._black_hole_attract_run = 0;
    self._bhb_change_anim_notified = 1;
    self._black_hole_bomb_being_pulled_in_fx = 0;
    self._black_hole_bomb_collapse_death = 0;
    self.a.runblendtime = self._normal_run_blend_time;

    // (set_zombie_run_cycle already put the normal death anim back)
    if ( !isdefined( speed ) )
        self.deathanim = undefined;

    self._had_legs = undefined;
    self._bhb_ent_flag_init = 0;

    // Fr0sty: forget the closed black hole and go for the players now (not up to 3 seconds later)
    self.enemyoverride = undefined;
    self.zombie_path_timer = 0;
}

// Fr0sty: any living zombie still in a pulled walk with no black hole pulling it gets reset
black_hole_bomb_stuck_watch()
{
    level endon( "end_game" );

    while ( true )
    {
        wait 2;
        zombies = getaispeciesarray( level.zombie_team, "all" );

        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[i];

            if ( !isdefined( z ) || !isalive( z ) || is_true( z._bhb_resetting ) )
                continue;

            if ( isdefined( z._bhb_attract_poi ) )
                continue;

            pulled = isdefined( z._bhb_saved_move_speed );

            if ( !pulled && isdefined( z.zombie_move_speed ) && issubstr( z.zombie_move_speed, "blackhole" ) )
                pulled = 1;

            if ( pulled )
            {
                println( "BHBFIX >> reset a zombie left in a pulled walk at " + z.origin );
                z thread black_hole_bomb_escaped_zombie_reset();
            }
        }
    }
}

black_hole_bomb_throttle_anim_changes()
{
    if ( !isdefined( level._black_hole_bomb_zombies_anim_change ) )
        level._black_hole_bomb_zombies_anim_change = [];

    int_max_num_zombies_per_frame = 7;
    array_zombies_allowed_to_switch = [];

    while ( isdefined( level._black_hole_bomb_zombies_anim_change ) )
    {
        if ( level._black_hole_bomb_zombies_anim_change.size == 0 )
        {
            wait 0.1;
            continue;
        }

        array_zombies_allowed_to_switch = level._black_hole_bomb_zombies_anim_change;

        for ( i = 0; i < array_zombies_allowed_to_switch.size; i++ )
        {
            if ( isdefined( array_zombies_allowed_to_switch[i] ) && isalive( array_zombies_allowed_to_switch[i] ) )
                array_zombies_allowed_to_switch[i] ent_flag_set( "bhb_anim_change" );

            if ( i >= int_max_num_zombies_per_frame )
                break;
        }

        flag_clear( "bhb_anim_change_allowed" );

        for ( i = 0; i < array_zombies_allowed_to_switch.size; i++ )
        {
            if ( !isdefined( array_zombies_allowed_to_switch[i] ) )
                continue;

            if ( !isdefined( array_zombies_allowed_to_switch[i]._bhb_ent_flag_init ) )
            {
                array_zombies_allowed_to_switch[i] ent_flag_init( "bhb_anim_change" );
                array_zombies_allowed_to_switch[i]._bhb_ent_flag_init = 1;
            }

            if ( array_zombies_allowed_to_switch[i] ent_flag( "bhb_anim_change" ) )
                arrayremovevalue( level._black_hole_bomb_zombies_anim_change, array_zombies_allowed_to_switch[i] );
        }

        level._black_hole_bomb_zombies_anim_change = array_removedead( level._black_hole_bomb_zombies_anim_change );
        arrayremovevalue( level._black_hole_bomb_zombies_anim_change, undefined );
        flag_set( "bhb_anim_change_allowed" );
        wait_network_frame();
        wait 0.1;
    }
}

// Fr0sty: the teleport trigger sits where the black hole opened (the port used the grenade's own spot)
black_hole_bomb_teleport_init( ent_grenade, hole_origin )
{
    if ( !isdefined( ent_grenade ) )
        return;

    if ( !isdefined( hole_origin ) )
        hole_origin = ent_grenade.origin;

    teleport_trigger = spawn( "trigger_radius", hole_origin, 0, 64, 70 );
    ent_grenade thread black_hole_bomb_trigger_monitor( teleport_trigger );
    ent_grenade waittill( "explode" );
    teleport_trigger notify( "black_hole_complete" );
    wait 0.1;
    teleport_trigger delete();
}

black_hole_bomb_trigger_monitor( ent_trigger )
{
    ent_trigger endon( "black_hole_complete" );

    while ( true )
    {
        ent_trigger waittill( "trigger", ent_player );

        if ( isplayer( ent_player ) && !ent_player isonground() && !is_true( ent_player.lander ) )
            ent_trigger thread black_hole_teleport_trigger_thread( ent_player, ::black_hole_time_before_teleport, ::black_hole_teleport_cancel );

        wait 0.1;
    }
}

black_hole_time_before_teleport( ent_player, str_endon )
{
    ent_player endon( str_endon );

    if ( !bullettracepassed( ent_player geteye(), self.origin + vectorscale( ( 0, 0, 1 ), 65.0 ), 0, ent_player ) )
        return;

    black_hole_teleport_structs = getstructarray( "struct_black_hole_teleport", "targetname" );
    chosen_spot = undefined;

    if ( isdefined( level._special_blackhole_bomb_structs ) )
        black_hole_teleport_structs = [[ level._special_blackhole_bomb_structs ]]();

    if ( !isdefined( black_hole_teleport_structs ) || black_hole_teleport_structs.size == 0 )
        return;

    black_hole_teleport_structs = array_randomize( black_hole_teleport_structs );

    if ( isdefined( level._override_blackhole_destination_logic ) )
        chosen_spot = [[ level._override_blackhole_destination_logic ]]( black_hole_teleport_structs, ent_player );
    else
    {
        for ( i = 0; i < black_hole_teleport_structs.size; i++ )
        {
            if ( check_point_in_enabled_zone( black_hole_teleport_structs[i].origin, undefined, undefined ) && ent_player get_current_zone() != black_hole_teleport_structs[i].script_string )
            {
                chosen_spot = black_hole_teleport_structs[i];
                break;
            }
        }
    }

    if ( isdefined( chosen_spot ) )
    {
        self playsound( "zmb_gersh_teleporter_out" );
        ent_player thread black_hole_teleport( chosen_spot );
    }
}

black_hole_teleport_cancel( ent_player )
{

}

black_hole_teleport( struct_dest )
{
    self endon( "death" );

    if ( !isdefined( struct_dest ) )
        return;

    prone_offset = vectorscale( ( 0, 0, 1 ), 49.0 );
    crouch_offset = vectorscale( ( 0, 0, 1 ), 20.0 );
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

    black_hole_bomb_create_exit_portal( struct_dest.origin );
    self freezecontrols( 1 );
    self disableoffhandweapons();
    self disableweapons();
    self dontinterpolate();
    self setorigin( destination );
    self setplayerangles( struct_dest.angles );
    self enableoffhandweapons();
    self enableweapons();
    self freezecontrols( 0 );
    self thread slightly_delayed_player_response();
}

slightly_delayed_player_response()
{
    wait 1;
    self maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "teleport_gersh" );
}

black_hole_teleport_trigger_thread( ent, on_enter_payload, on_exit_payload )
{
    ent endon( "death" );
    self endon( "black_hole_complete" );

    if ( ent black_hole_teleport_ent_already_in_trigger( self ) )
        return;

    self black_hole_teleport_add_trigger_to_ent( ent );
    endon_condition = "leave_trigger_" + self getentitynumber();

    if ( isdefined( on_enter_payload ) )
        self thread [[ on_enter_payload ]]( ent, endon_condition );

    while ( isdefined( ent ) && ent istouching( self ) && isdefined( self ) )
        wait 0.01;

    ent notify( endon_condition );

    if ( isdefined( ent ) && isdefined( on_exit_payload ) )
        self thread [[ on_exit_payload ]]( ent );

    if ( isdefined( ent ) )
        self black_hole_teleport_remove_trigger_from_ent( ent );
}

black_hole_teleport_add_trigger_to_ent( ent )
{
    if ( !isdefined( ent._triggers ) )
        ent._triggers = [];

    ent._triggers[self getentitynumber()] = 1;
}

black_hole_teleport_remove_trigger_from_ent( ent )
{
    if ( !isdefined( ent._triggers ) )
        return;

    if ( !isdefined( ent._triggers[self getentitynumber()] ) )
        return;

    ent._triggers[self getentitynumber()] = 0;
}

black_hole_teleport_ent_already_in_trigger( trig )
{
    if ( !isdefined( self._triggers ) )
        return false;

    if ( !isdefined( self._triggers[trig getentitynumber()] ) )
        return false;

    if ( !self._triggers[trig getentitynumber()] )
        return false;

    return true;
}

black_hole_bomb_kill_counter( grenade )
{
    self endon( "death" );
    grenade endon( "death" );
    kill_count = 0;

    for (;;)
    {
        grenade waittill( "black_hole_bomb_kill" );
        kill_count++;

        if ( kill_count == 4 )
            self maps\mp\zombies\_zm_audio::create_and_play_dialog( "kill", "gersh_device" );

        if ( 5 <= kill_count )
            self notify( "black_hole_kills_achievement" );
    }
}

black_hole_bomb_create_exit_portal( pos )
{
    exit_portal_fx_spot = spawn( "script_model", pos );
    exit_portal_fx_spot setmodel( "tag_origin" );
    playfxontag( level._effect["black_hole_bomb_portal_exit"], exit_portal_fx_spot, "tag_origin" );
    exit_portal_fx_spot thread black_hole_bomb_exit_clean_up();
    exit_portal_fx_spot playsound( "zmb_gersh_teleporter_go" );
}

black_hole_bomb_exit_clean_up()
{
    wait 4.0;
    self delete();
}

black_hole_bomb_stolen_by_sam( ent_grenade, ent_model )
{
    if ( !isdefined( ent_model ) )
        return;

    direction = ent_model.origin;
    direction = ( direction[1], direction[0], 0 );

    if ( direction[1] < 0 || direction[0] > 0 && direction[1] > 0 )
        direction = ( direction[0], direction[1] * -1, 0 );
    else if ( direction[0] < 0 )
        direction = ( direction[0] * -1, direction[1], 0 );

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( isalive( players[i] ) )
            players[i] playlocalsound( level.zmb_laugh_alias );
    }

    playfxontag( level._effect["black_hole_samantha_steal"], ent_model, "tag_origin" );
    ent_model movez( 60, 1.0, 0.25, 0.25 );
    ent_model vibrate( direction, 1.5, 2.5, 1.0 );
    ent_model waittill( "movedone" );
    ent_model delete();
}
