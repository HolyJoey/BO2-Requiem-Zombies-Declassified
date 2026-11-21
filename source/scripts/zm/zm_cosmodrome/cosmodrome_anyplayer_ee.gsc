// Ascension (zm_cosmodrome) Easter egg for any number of players (1-4). Log lines start with "COSMOEE >>".
// Based on the DLC5 solo EE script (zm_cosmodrome_solo_ee.gsc, a gsc-tool decompile). Any-player changes by Fr0sty;
// please credit Fr0sty if you reuse or reupload them.
//
// What changed from the solo script:
//   - Player count is read live (get_players) whenever a step needs it. The solo script read getnumexpectedplayers()
//     once at load, which can be 0 in private/custom games and never follows people joining or leaving.
//   - Sync switches (monkey round): as many switches as there are players (max 4), no 0.5 s timing unless 4 players.
//   - Pressure plate: only players who are alive and not downed have to stand on it (downed/dead ones blocked it).
//   - Solo still skips the lander passkey and the Ray Gun / doll hits, as the solo script does.
//   - Weapon combo: the damage weapon is a name string in T6, so "weapon.name" was replaced (it broke the step).
//   - If the map has its own copy of this EE built in, it is switched off so the two never run at once.

#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_powerups;
#include maps\mp\zombies\_zm_audio;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\_utility;
#include common_scripts\utility;

main()
{
    if ( getdvar( "mapname" ) != "zm_cosmodrome" )
        return;

    // the built-in EE (if the map has one) under the names it is likely to have: turn its entry point into a no-op
    names = array( "maps/mp/zm_cosmodrome_eggs", "maps/mp/zm_cosmodrome_solo_ee", "maps/mp/zm_cosmodrome_ee" );

    foreach ( name in names )
    {
        f = getfunction( name, "init" );

        if ( isdefined( f ) )
        {
            replacefunc( f, ::cosmoee_builtin_off, -1 );
            println( "COSMOEE >> built-in EE " + name + "::init switched off" );
        }
    }
}

cosmoee_builtin_off()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_cosmodrome" )
        return;

    level thread cosmoee_run();
}

cosmoee_run()
{
    precachemodel( "p_glo_electrical_transformer" );
    precachemodel( "p_zom_monitor_csm_screen_on" );
    precachemodel( "p_zom_monitor_csm_screen_logo" );
    precachemodel( "p_rus_electric_switch_stop" );
    precachemodel( "p_rus_clock_lrg" );
    cosmoee_flag_init( "target_teleported" );
    cosmoee_flag_init( "rerouted_power" );
    cosmoee_flag_init( "switches_synced" );
    cosmoee_flag_init( "pressure_sustained" );
    cosmoee_flag_init( "passkey_confirmed" );
    cosmoee_flag_init( "weapons_combined" );
    cosmoee_flag_init( "letter_acquired" );
    cosmoee_flag_init( "thundergun_hit" );
    level.casimir_lights = [];
    level.lander_letters["a"] = getent( "letter_a", "targetname" );
    level.lander_letters["e"] = getent( "letter_e", "targetname" );
    level.lander_letters["h"] = getent( "letter_h", "targetname" );
    level.lander_letters["i"] = getent( "letter_i", "targetname" );
    level.lander_letters["l"] = getent( "letter_l", "targetname" );
    level.lander_letters["m"] = getent( "letter_m", "targetname" );
    level.lander_letters["n"] = getent( "letter_n", "targetname" );
    level.lander_letters["r"] = getent( "letter_r", "targetname" );
    level.lander_letters["s"] = getent( "letter_s", "targetname" );
    level.lander_letters["t"] = getent( "letter_t", "targetname" );
    level.lander_letters["u"] = getent( "letter_u", "targetname" );
    level.lander_letters["y"] = getent( "letter_y", "targetname" );
    keys = getarraykeys( level.lander_letters );

    for ( i = 0; i < keys.size; i++ )
    {
        if ( isdefined( level.lander_letters[keys[i]] ) )
            level.lander_letters[keys[i]] ghost();
    }

    // players are not in yet at load
    while ( get_players().size == 0 )
        wait 0.1;

    println( "COSMOEE >> any-player EE on, " + get_players().size + " player(s) now" );

    teleport_target_event();
    println( "COSMOEE >> step 1 done (Gersh device teleport)" );
    reroute_power_event();
    println( "COSMOEE >> step 2 done (monitor)" );
    sync_switch_event();
    println( "COSMOEE >> step 3 done (sync switches)" );
    pressure_plate_event();
    println( "COSMOEE >> step 4 done (pressure plate)" );
    lander_passkey_event();
    println( "COSMOEE >> step 5 done (lander passkey)" );
    weapon_combo_event();
    println( "COSMOEE >> step 6 done (weapon combo)" );
    level notify( "help_found" );
    monitor = getent( "casimir_monitor", "targetname" );
    monitor setmodel( "p_zom_monitor_csm_screen_off" );
}

// the map may already have made some of these flags (flag_init errors on a second call)
cosmoee_flag_init( name )
{
    if ( !isdefined( level.flag ) || !isdefined( level.flag[ name ] ) )
        flag_init( name );
}

// live player count, and the solo rule on top of it
cosmoee_players()
{
    return get_players().size;
}

cosmoee_solo()
{
    return get_players().size <= 1;
}

activate_casimir_light( num )
{
    spot = getstruct( "casimir_light_" + num, "targetname" );

    if ( isdefined( spot ) )
    {
        light = spawn( "script_model", spot.origin );
        light setmodel( "tag_origin" );
        light.angles = spot.angles;
        fx = playfxontag( level._effect["fx_zmb_light_floodlight_bright"], light, "tag_origin" );
        level.casimir_lights[level.casimir_lights.size] = light;
    }
}

teleport_target_event()
{
    teleport_target_start = getstruct( "teleport_target_start", "targetname" );
    teleport_target_spark = getstruct( "teleport_target_spark", "targetname" );
    spark_angles = teleport_target_spark.angles;
    level.teleport_target = spawn( "script_model", teleport_target_start.origin );
    level.teleport_target setmodel( "p_glo_electrical_transformer" );
    level.teleport_target.angles = teleport_target_start.angles;
    level.teleport_target playloopsound( "zmb_egg_notifier", 1 );
    teleport_target_spark = spawn( "script_model", teleport_target_spark.origin );
    teleport_target_spark setmodel( "tag_origin" );
    teleport_target_spark.angles = spark_angles;
    playfxontag( level._effect["switch_sparks"], teleport_target_spark, "tag_origin" );
    level.teleport_target_trigger = spawn( "trigger_radius", teleport_target_start.origin + vectorscale( ( 0, 0, -1 ), 70 ), 0, 125, 100 );
    level.black_hole_bomb_loc_check_func = ::bhb_teleport_loc_check;
    level waittill( "cosmoee_target_grabbed" );
    teleport_target_spark delete();
    flag_wait( "target_teleported" );
    level.black_hole_bomb_loc_check_func = undefined;
    level thread play_egg_vox( "vox_ann_egg1_success", "vox_gersh_egg1", 1 );
}

bhb_teleport_loc_check( grenade, model, info )
{
    if ( isdefined( level.teleport_target_trigger ) && grenade istouching( level.teleport_target_trigger ) )
    {
        model setclientfield( "toggle_black_hole_deployed", 1 );
        level thread teleport_target( grenade, model );
        return true;
    }

    return false;
}

teleport_target( grenade, model )
{
    level.teleport_target_trigger delete();
    level.teleport_target_trigger = undefined;
    wait 1;
    level notify( "cosmoee_target_grabbed" );
    time = 3;
    level.teleport_target moveto( grenade.origin + vectorscale( ( 0, 0, 1 ), 50 ), time, time - 0.05 );
    wait( time );
    teleport_target_end = getstruct( "teleport_target_end", "targetname" );
    level.teleport_target ghost();
    playsoundatposition( "zmb_gersh_teleporter_out", grenade.origin + vectorscale( ( 0, 0, 1 ), 50 ) );
    wait 0.5;
    level.teleport_target.angles = teleport_target_end.angles;
    level.teleport_target moveto( teleport_target_end.origin, 0.05 );
    level.teleport_target stoploopsound( 1 );
    wait 0.5;
    level.teleport_target show();
    playfxontag( level._effect["black_hole_bomb_event_horizon"], level.teleport_target, "tag_origin" );
    level.teleport_target playsound( "zmb_gersh_teleporter_go" );
    wait 2;
    model delete();
    flag_set( "target_teleported" );
}

reroute_power_event()
{
    monitor = getent( "casimir_monitor", "targetname" );
    location = getstruct( "casimir_monitor_struct", "targetname" );
    monitor playloopsound( "zmb_egg_notifier", 1 );
    monitor setmodel( "p_zom_monitor_csm_screen_on" );
    trig = spawn( "trigger_radius", location.origin, 0, 32, 60 );
    trig wait_for_use( monitor );
    trig delete();
    flag_set( "rerouted_power" );
    monitor setmodel( "p_zom_monitor_csm_screen_logo" );
    monitor stoploopsound( 1 );
    level thread play_egg_vox( "vox_ann_egg2_success", "vox_gersh_egg2", 2 );
    level thread activate_casimir_light( 1 );
}

wait_for_use( monitor )
{
    while ( true )
    {
        self waittill( "trigger", who );

        while ( isplayer( who ) && who istouching( self ) )
        {
            if ( who usebuttonpressed() )
            {
                flag_set( "rerouted_power" );
                monitor playsound( "zmb_comp_activate" );
                return;
            }

            wait 0.05;
        }
    }
}

sync_switch_event()
{
    switches = getstructarray( "sync_switch_start", "targetname" );
    self waittill_switches_synced( switches );
    level thread play_egg_vox( "vox_ann_egg3_success", "vox_gersh_egg3", 3 );
    level thread activate_casimir_light( 2 );
}

waittill_switches_synced( switches )
{
    while ( !flag( "switches_synced" ) )
    {
        flag_wait( "monkey_round" );
        array_thread( switches, ::reveal_switch );
        self thread switch_watcher();
        level waittill_either( "between_round_over", "switches_synced" );
    }
}

reveal_switch()
{
    button = spawn( "script_model", self.origin );
    button setmodel( "p_rus_electric_switch_stop" );
    button.angles = self.angles + vectorscale( ( 0, 1, 0 ), 90 );
    button playloopsound( "zmb_egg_notifier", 1 );
    offset = anglestoforward( self.angles ) * 8;
    time = 1;
    button moveto( button.origin + offset, 1 );
    wait 1;

    if ( flag( "monkey_round" ) )
    {
        trig = spawn( "trigger_radius", button.origin, 0, 32, 72 );
        trig thread wait_for_sync_use( self, button );
        level waittill_either( "between_round_over", "switches_synced" );
        trig delete();
    }

    button stoploopsound( 1 );
    button moveto( self.origin, time );
    wait( time );
    button delete();
}

wait_for_sync_use( ss, button )
{
    level endon( "between_round_over" );
    level endon( "switches_synced" );
    ss.pressed = 0;

    while ( true )
    {
        self waittill( "trigger", who );

        while ( isplayer( who ) && who istouching( self ) )
        {
            if ( who usebuttonpressed() )
            {
                level notify( "sync_button_pressed" );
                button playsound( "zmb_push_button" );
                ss.pressed = 1;

                while ( who usebuttonpressed() )
                    wait 0.05;
            }

            wait 0.05;
        }
    }
}

// Stock: all 4 switches within 0.5 s. Here: one switch per player (max 4); under 4 players they stay pressed for the
// whole monkey round, so they can be pressed one after another.
switch_watcher()
{
    level endon( "between_round_over" );
    pressed = 0;
    switches = getstructarray( "sync_switch_start", "targetname" );

    while ( true )
    {
        level waittill( "sync_button_pressed" );
        count = cosmoee_players();
        needed = count;

        if ( needed > 4 )
            needed = 4;

        if ( needed < 1 )
            needed = 1;

        timeout = gettime() + 500;

        if ( count < 4 )
            timeout = timeout + 100000;

        while ( gettime() < timeout )
        {
            pressed = 0;

            for ( i = 0; i < switches.size; i++ )
            {
                if ( isdefined( switches[i].pressed ) && switches[i].pressed )
                    pressed++;
            }

            if ( pressed >= needed )
            {
                flag_set( "switches_synced" );
                level notify( "switches_synced" );

                for ( i = 0; i < switches.size; i++ )
                    playsoundatposition( "zmb_misc_activate", switches[i].origin );

                return;
            }

            wait 0.05;
        }

        switch ( pressed )
        {
            case 1:
            case 2:
            case 3:
                for ( i = 0; i < switches.size; i++ )
                    playsoundatposition( "zmb_deny", switches[i].origin );

                break;
        }

        for ( i = 0; i < switches.size; i++ )
            switches[i].pressed = 0;
    }
}

pressure_plate_event()
{
    area = getstruct( "pressure_pad", "targetname" );
    trig = spawn( "trigger_radius", area.origin, 0, 300, 100 );
    n_timer = 120;
    trig area_timer( n_timer );
    trig delete();
    level thread play_egg_vox( "vox_ann_egg4_success", "vox_gersh_egg4", 4 );
    level thread activate_casimir_light( 3 );
}

// every player who is alive and up is on the plate (downed, dead and spectating players don't count)
cosmoee_all_on_plate( trig )
{
    players = get_players();
    standing = 0;

    for ( i = 0; i < players.size; i++ )
    {
        if ( !is_player_valid( players[i] ) )
            continue;

        if ( !players[i] istouching( trig ) )
            return false;

        standing++;
    }

    return standing > 0;
}

area_timer( time )
{
    clock_loc = getstruct( "pressure_timer", "targetname" );
    clock = spawn( "script_model", clock_loc.origin );
    clock setmodel( "p_rus_clock_lrg" );
    clock.angles = clock_loc.angles;
    clock playloopsound( "zmb_egg_notifier", 1 );
    timer_hand_angles_init = ( 270, 90, 0 );
    timer_hand = spawn( "script_model", clock_loc.origin + ( -1, 0, 12 ) );
    timer_hand setmodel( "t5_weapon_ballistic_knife_blade" );
    timer_hand.angles = timer_hand_angles_init;
    step = 1;

    while ( !flag( "pressure_sustained" ) )
    {
        self waittill( "trigger" );

        if ( !cosmoee_all_on_plate( self ) )
        {
            wait( step );
            continue;
        }

        self playsound( "zmb_pressure_plate_trigger" );
        time_remaining = time;
        timer_hand rotatepitch( 360, time );
        stop_timer = 0;

        while ( time_remaining )
        {
            if ( !cosmoee_all_on_plate( self ) )
            {
                wait( step );
                time_remaining = time;
                stop_timer = 1;
                timer_hand rotateto( timer_hand_angles_init, 0.5 );
                timer_hand playsound( "zmb_deny" );
                wait 0.5;
                break;
            }

            wait( step );
            time_remaining = time_remaining - step;
            timer_hand playsound( "zmb_egg_timer_oneshot" );
        }

        if ( time_remaining <= 0 )
        {
            flag_set( "pressure_sustained" );
            players = get_players();
            temp_fx = undefined;

            if ( isdefined( players[0].fx ) )
                temp_fx = players[0].fx;

            timer_hand playsound( "zmb_perks_packa_ready" );
            players[0].fx = level.zombie_powerups["nuke"].fx;
            level thread maps\mp\zombies\_zm_powerups::nuke_powerup( players[0], players[0].team );
            clock stoploopsound( 1 );
            wait 1;

            if ( isdefined( temp_fx ) )
                players[0].fx = temp_fx;
            else
                players[0].fx = undefined;

            clock delete();
            timer_hand delete();
            return;
        }
    }
}

lander_passkey_event()
{
    level.lander_key = [];
    level.lander_key["lander_station1"]["lander_station3"] = "s";
    level.lander_key["lander_station1"]["lander_station4"] = "r";
    level.lander_key["lander_station1"]["lander_station5"] = "e";
    level.lander_key["lander_station3"]["lander_station1"] = "y";
    level.lander_key["lander_station3"]["lander_station4"] = "a";
    level.lander_key["lander_station3"]["lander_station5"] = "i";
    level.lander_key["lander_station4"]["lander_station1"] = "m";
    level.lander_key["lander_station4"]["lander_station3"] = "h";
    level.lander_key["lander_station4"]["lander_station5"] = "u";
    level.lander_key["lander_station5"]["lander_station1"] = "t";
    level.lander_key["lander_station5"]["lander_station3"] = "n";
    level.lander_key["lander_station5"]["lander_station4"] = "l";
    level.passkey = array( "l", "u", "n", "a" );
    level.passkey_progress = 0;
    level.secret1 = array( "h", "i", "t", "s", "a", "m" );
    level.secret1_progress = 0;
    level.secret2 = array( "h", "y", "e", "n", "a" );
    level.secret2_progress = 0;
    level thread lander_monitor();
    flag_wait( "passkey_confirmed" );
    level.lander_audio_ent stoploopsound( 1 );
    level thread play_egg_vox( "vox_ann_egg5_success", "vox_gersh_egg5", 5 );
    level thread activate_casimir_light( 4 );
    wait 1;
    level.lander_audio_ent delete();
}

lander_monitor()
{
    lander = getent( "lander", "targetname" );
    level.lander_audio_ent = spawn( "script_origin", lander.origin );
    level.lander_audio_ent linkto( lander );
    level.lander_audio_ent playloopsound( "zmb_egg_notifier", 1 );

    // solo skips the passkey (as the solo script does); checked now and after every lander flight
    level thread lander_solo_skip();

    while ( !flag( "passkey_confirmed" ) )
    {
        level waittill( "lander_launched" );

        if ( flag( "passkey_confirmed" ) )
            break;

        if ( lander.called )
        {
            start = lander.depart_station;
            dest = lander.station;
            letter = level.lander_key[start][dest];
            model = level.lander_letters[letter];
            model show();
            model playsound( "zmb_spawn_powerup" );
            model thread spin_letter();
            model playloopsound( "zmb_spawn_powerup_loop", 0.5 );
            trig = spawn( "trigger_radius", model.origin, 0, 200, 150 );
            trig thread letter_grab( letter, model );
            flag_wait( "lander_grounded" );

            if ( !flag( "letter_acquired" ) )
                passkeys_reset();
            else
                flag_clear( "letter_acquired" );

            trig delete();
            model ghost();
            model stoploopsound( 0.5 );
        }
        else
            passkeys_reset();
    }
}

lander_solo_skip()
{
    while ( !flag( "passkey_confirmed" ) )
    {
        if ( cosmoee_solo() )
        {
            println( "COSMOEE >> solo: lander passkey skipped" );
            flag_set( "passkey_confirmed" );
            return;
        }

        wait 1;
    }
}

passkeys_reset()
{
    level.passkey_progress = 0;
    level.secret1_progress = 0;
    level.secret2_progress = 0;
}

spin_letter()
{
    level endon( "lander_grounded" );
    level endon( "letter_acquired" );

    while ( true )
    {
        self rotateyaw( 90, 5 );
        wait 5;
    }
}

letter_grab( letter, model )
{
    level endon( "lander_grounded" );
    self waittill( "trigger" );
    flag_set( "letter_acquired" );
    playsoundatposition( "zmb_powerup_grabbed", model.origin );
    model ghost();

    if ( letter == level.passkey[level.passkey_progress] )
    {
        level.passkey_progress++;

        if ( level.passkey_progress == level.passkey.size )
            flag_set( "passkey_confirmed" );
    }
    else
        level.passkey_progress = 0;

    if ( letter == level.secret1[level.secret1_progress] )
        level.secret1_progress++;
    else
        level.secret1_progress = 0;

    if ( letter == level.secret2[level.secret2_progress] )
        level.secret2_progress++;
    else
        level.secret2_progress = 0;
}

weapon_combo_event()
{
    weapon_combo_spot = getstruct( "weapon_combo_spot", "targetname" );
    focal_point = spawn( "script_model", weapon_combo_spot.origin );
    focal_point setmodel( "tag_origin" );
    focal_point playloopsound( "zmb_egg_notifier", 1 );
    fx = playfxontag( level._effect["gersh_spark"], focal_point, "tag_origin" );
    level.black_hold_bomb_target_trig = spawn( "trigger_radius", weapon_combo_spot.origin, 0, 50, 72 );
    level.black_hole_bomb_loc_check_func = ::bhb_combo_loc_check;
    flag_wait( "weapons_combined" );
    level.black_hold_bomb_target_trig delete();
    level.black_hole_bomb_loc_check_func = undefined;
    focal_point delete();

    for ( i = 0; i < level.casimir_lights.size; i++ )
        level.casimir_lights[i] delete();
}

bhb_combo_loc_check( grenade, model, info )
{
    if ( isdefined( level.black_hold_bomb_target_trig ) && grenade istouching( level.black_hold_bomb_target_trig ) )
        grenade bhb_combo_start();

    return false;
}

bhb_combo_start()
{
    trig = spawn( "trigger_damage", self.origin, 0, 15, 72 );
    self thread wait_for_combo( trig );
}

wait_for_combo( trig )
{
    self endon( "death" );
    self thread kill_trig_on_death( trig );
    weapon_combo_spot = getstruct( "weapon_combo_spot", "targetname" );
    ray_gun_hit = 0;
    doll_hit = 0;

    if ( cosmoee_solo() )
    {
        ray_gun_hit = 1;
        doll_hit = 1;
    }

    players = get_players();
    array_thread( players, ::thundergun_check, self, trig, weapon_combo_spot );

    while ( true )
    {
        trig waittill( "damage", amount, inflictor, direction, point, type, tagname, modelname, partname, weapon );

        if ( isdefined( inflictor ) )
        {
            if ( !isdefined( weapon ) || !isstring( weapon ) )
                weapon = "";

            if ( isdefined( type ) && ( type == "MOD_PROJECTILE_SPLASH" || type == "MOD_PROJECTILE" ) && weapon == "ray_gun_upgraded_zm" )
                ray_gun_hit = 1;
            else if ( issubstr( weapon, "nesting_doll" ) )
                doll_hit = 1;

            if ( ray_gun_hit && doll_hit && flag( "thundergun_hit" ) )
            {
                flag_set( "weapons_combined" );
                level thread soul_release( self, trig.origin );
                return;
            }
        }
    }
}

thundergun_check( model, trig, weapon_combo_spot )
{
    model endon( "death" );
    self endon( "disconnect" );

    while ( true )
    {
        self waittill( "weapon_fired" );

        if ( self getcurrentweapon() == "thundergun_upgraded_zm" )
        {
            if ( distancesquared( self.origin, weapon_combo_spot.origin ) < 90000 )
            {
                vector_to_spot = vectornormalize( weapon_combo_spot.origin - self getweaponmuzzlepoint() );
                vector_player_facing = self getweaponforwarddir();
                angle_diff = acos( vectordot( vector_to_spot, vector_player_facing ) );

                if ( angle_diff <= 20 )
                    self thundergun_success( trig );
            }
        }
    }
}

thundergun_success( trig )
{
    flag_set( "thundergun_hit" );
    radiusdamage( trig.origin, 5, 1, 1, self );
}

kill_trig_on_death( trig )
{
    self waittill( "death" );
    trig delete();

    if ( flag( "thundergun_hit" ) && !flag( "weapons_combined" ) )
        level thread play_egg_vox( "vox_ann_egg6p1_success", "vox_gersh_egg6_fail2", 7 );
    else if ( !flag( "weapons_combined" ) )
        level thread play_egg_vox( undefined, "vox_gersh_egg6_fail1", 6 );

    flag_clear( "thundergun_hit" );
}

soul_release( model, origin )
{
    soul = spawn( "script_model", origin );
    soul setmodel( "tag_origin" );
    soul playloopsound( "zmb_egg_soul" );
    fx = playfxontag( level._effect["gersh_spark"], soul, "tag_origin" );
    time = 20;
    model waittill( "death" );
    level thread play_egg_vox( "vox_ann_egg6_success", "vox_gersh_egg6_success", 9 );
    level thread wait_for_gersh_vox();
    soul movez( 2500, time, time - 1 );
    wait( time );
    soul delete();
    wait 2;
    level thread samantha_is_angry();
}

wait_for_gersh_vox()
{
    wait 12.5;
    players = getplayers();

    for ( i = 0; i < players.size; i++ )
        players[i] thread reward_wait();
}

reward_wait()
{
    self endon( "disconnect" );

    while ( !is_player_valid( self ) || self usebuttonpressed() && self in_revive_trigger() )
        wait 1;

    level thread maps\mp\zombies\_zm_powerups::minigun_weapon_powerup( self, 90 );
    self sq_give_player_all_perks();
}

sq_give_player_all_perks()
{
    if ( !isdefined( level._sq_perk_array ) )
    {
        level._sq_perk_array = [];
        machines = getentarray( "zombie_vending", "targetname" );

        for ( i = 0; i < machines.size; i++ )
            level._sq_perk_array[level._sq_perk_array.size] = machines[i].script_noteworthy;
    }

    for ( i = 0; i < level._sq_perk_array.size; i++ )
    {
        if ( !self hasperk( level._sq_perk_array[i] ) )
        {
            self playsound( "evt_sq_bag_gain_perks" );
            self maps\mp\zombies\_zm_perks::give_perk( level._sq_perk_array[i] );

            if ( isdefined( level.perk_bought_func ) )
                self [[ level.perk_bought_func ]]( level._sq_perk_array[i] );

            wait 0.25;
        }
    }
}

play_egg_vox( ann_alias, gersh_alias, plr_num )
{
    if ( isdefined( ann_alias ) )
        level maps\mp\zm_cosmodrome_amb::play_cosmo_announcer_vox( ann_alias );

    if ( isdefined( gersh_alias ) )
        level maps\mp\zm_cosmodrome_amb::play_gersh_vox( gersh_alias );

    if ( isdefined( plr_num ) )
    {
        players = get_players();
        rand = randomintrange( 0, players.size );
        players[rand] maps\mp\zombies\_zm_audio::create_and_play_dialog( "eggs", "gersh_response", undefined, plr_num );
    }
}

samantha_is_angry()
{
    playsoundatposition( "zmb_samantha_earthquake", ( 0, 0, 0 ) );
    playsoundatposition( "zmb_samantha_whispers", ( 0, 0, 0 ) );
    wait 6;
    level setclientfield( "COSMO_EGG_SAM_ANGRY", 1 );
    playsoundatposition( "zmb_samantha_scream", ( 0, 0, 0 ) );
    wait 6;
    level setclientfield( "COSMO_EGG_SAM_ANGRY", 0 );
}
