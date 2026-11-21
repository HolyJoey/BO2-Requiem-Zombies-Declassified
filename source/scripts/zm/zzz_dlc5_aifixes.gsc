#include common_scripts\utility;
#include maps\mp\_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Special zombie fixes on the DLC5 maps. Log lines start with "AIFIXES >>".
// 1) Nova crawlers used the normal zombie attack scream. Stock _zm_spawner::zombie_spawn_init gives every zombie
//    self.zmb_vocals_attack = "zmb_vocals_zombie_attack", and the melee animscript plays exactly that; BO1 played the
//    crawler's own zmb_vocals_quad_attack. DLC5 ships that alias (BO1's 10 quad_attack recordings, dlc5_load bank) but
//    never swaps it in, so each Nova crawler gets it here once it has spawned.
// 2) Thief (Five) too weak: DLC5 uses BO1's exact health (2000 x round, max 60000, scaled down for fewer players), but
//    BO2's guns and Pack-a-Punch hit far harder than BO1's, so he drops in seconds. Health is x3 (6000 x round,
//    max 180000); BO1's player-count scaling is kept.
// 3) Death Machine spin (hold aim): only the spin-up played. The weapon's spin-down alias is misspelled
//    ("wpn_vulcann_stop_plr") and its spin loop is not heard, so the loop and spin-down recordings (DLC5 Kino's bank,
//    in mod.ff's dlc5_moongate.all as dlc5_dmspin_loop / _stop) are played here while the barrel spins.

main()
{
    if ( getdvar( "mapname" ) == "zm_pentagon" )
        aifixes_thief_health();

    // 4) crash at the end of a match: stock _zm_powerups::powerup_hud_monitor indexes level.zombie_vars[ player.team ]
    //    every frame; once a player's team is cleared (match ending) that is an undefined index ("type undefined is not
    //    an int", Plutonium crash dump 2026-09-27). Same loop, skipping such players.
    if ( aifixes_is_dlc5_map() )
    {
        f = getfunction( "maps/mp/zombies/_zm_powerups", "powerup_hud_monitor" );

        if ( isdefined( f ) )
            replacefunc( f, ::aifixes_powerup_hud_monitor, -1 );
    }
}

init()
{
    switch ( getdvar( "mapname" ) )
    {
        case "zm_theater":
        case "zm_pentagon":
        case "zm_moon":
            level thread aifixes_quad_attack_vox();
            break;
    }

    if ( getdvar( "mapname" ) == "zm_pentagon" )
        aifixes_thief_health();

    if ( aifixes_is_dlc5_map() )
        level thread aifixes_dm_spin_players();
}

aifixes_is_dlc5_map()
{
    switch ( getdvar( "mapname" ) )
    {
        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_factory":
        case "zm_theater":
        case "zm_pentagon":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            return true;
    }

    return false;
}

aifixes_dm_spin_players()
{
    level endon( "end_game" );
    players = getplayers();

    for ( i = 0; i < players.size; i++ )
        players[i] thread aifixes_dm_spin();

    for (;;)
    {
        level waittill( "connected", player );
        player thread aifixes_dm_spin();
    }
}

aifixes_dm_spin()
{
    self notify( "aifixes_dm_spin" );
    self endon( "aifixes_dm_spin" );
    self endon( "disconnect" );
    spinning = 0;

    for (;;)
    {
        wait 0.05;
        weapon = self getcurrentweapon();
        holding = isdefined( weapon ) && ( weapon == "minigun_zm" || weapon == "minigun_upgraded_zm" );
        want = holding && isalive( self ) && ( self adsbuttonpressed() || self attackbuttonpressed() );

        if ( want && !spinning )
        {
            spinning = 1;
            self playloopsound( "dlc5_dmspin_loop", 0.25 );
        }
        else if ( !want && spinning )
        {
            spinning = 0;
            self stoploopsound( 0.15 );

            if ( holding )
                self playsound( "dlc5_dmspin_stop" );
        }
    }
}

aifixes_thief_health()
{
    level.thief_health_multiplier = 6000;
    level.max_thief_health = 180000;
}

aifixes_quad_attack_vox()
{
    level endon( "end_game" );

    if ( !soundexists( "zmb_vocals_quad_attack" ) )
    {
        println( "AIFIXES >> zmb_vocals_quad_attack missing, Nova crawlers keep the stock attack sound" );
        return;
    }

    println( "AIFIXES >> Nova crawlers use zmb_vocals_quad_attack; Thief health x3 on Five" );

    for (;;)
    {
        zombies = getaispeciesarray( level.zombie_team, "all" );

        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[i];

            if ( isdefined( z ) && isdefined( z.animname ) && z.animname == "quad_zombie" && !isdefined( z.aifixes_quad ) )
            {
                z.aifixes_quad = 1;
                z.zmb_vocals_attack = "zmb_vocals_quad_attack";
            }
        }

        wait 0.25;
    }
}

// stock powerup_hud_monitor (patch_zm), with the player guard marked below
aifixes_powerup_hud_monitor()
{
    flag_wait( "start_zombie_round_logic" );

    if ( isdefined( level.current_game_module ) && level.current_game_module == 2 )
        return;

    flashing_timers = [];
    flashing_values = [];
    flashing_timer = 10;
    flashing_delta_time = 0;
    flashing_is_on = 0;
    flashing_value = 3;
    flashing_min_timer = 0.15;

    while ( flashing_timer >= flashing_min_timer )
    {
        if ( flashing_timer < 5 )
            flashing_delta_time = 0.1;
        else
            flashing_delta_time = 0.2;

        if ( flashing_is_on )
        {
            flashing_timer = flashing_timer - flashing_delta_time - 0.05;
            flashing_value = 2;
        }
        else
        {
            flashing_timer = flashing_timer - flashing_delta_time;
            flashing_value = 3;
        }

        flashing_timers[flashing_timers.size] = flashing_timer;
        flashing_values[flashing_values.size] = flashing_value;
        flashing_is_on = !flashing_is_on;
    }

    client_fields = [];
    powerup_keys = getarraykeys( level.zombie_powerups );

    for ( powerup_key_index = 0; powerup_key_index < powerup_keys.size; powerup_key_index++ )
    {
        if ( isdefined( level.zombie_powerups[powerup_keys[powerup_key_index]].client_field_name ) )
        {
            powerup_name = powerup_keys[powerup_key_index];
            client_fields[powerup_name] = spawnstruct();
            client_fields[powerup_name].client_field_name = level.zombie_powerups[powerup_name].client_field_name;
            client_fields[powerup_name].solo = level.zombie_powerups[powerup_name].solo;
            client_fields[powerup_name].time_name = level.zombie_powerups[powerup_name].time_name;
            client_fields[powerup_name].on_name = level.zombie_powerups[powerup_name].on_name;
        }
    }

    client_field_keys = getarraykeys( client_fields );

    while ( true )
    {
        wait 0.05;
        waittillframeend;
        players = get_players();

        for ( playerindex = 0; playerindex < players.size; playerindex++ )
        {
            for ( client_field_key_index = 0; client_field_key_index < client_field_keys.size; client_field_key_index++ )
            {
                player = players[playerindex];

                // stock indexes level.zombie_vars[ player.team ]: a player whose team is already cleared (match ending,
                // disconnecting) made that an undefined index -> "type undefined is not an int" -> crash at game end
                if ( !isdefined( player ) || !isdefined( player.team ) || !isdefined( player.zombie_vars ) )
                    continue;
/#
                if ( isdefined( player.pers["isBot"] ) && player.pers["isBot"] )
                    continue;
#/

                if ( isdefined( level.powerup_player_valid ) )
                {
                    if ( ![[ level.powerup_player_valid ]]( player ) )
                        continue;
                }

                client_field_name = client_fields[client_field_keys[client_field_key_index]].client_field_name;
                time_name = client_fields[client_field_keys[client_field_key_index]].time_name;
                on_name = client_fields[client_field_keys[client_field_key_index]].on_name;
                powerup_timer = undefined;
                powerup_on = undefined;

                if ( client_fields[client_field_keys[client_field_key_index]].solo )
                {
                    if ( isdefined( player._show_solo_hud ) && player._show_solo_hud == 1 )
                    {
                        powerup_timer = player.zombie_vars[time_name];
                        powerup_on = player.zombie_vars[on_name];
                    }
                }
                else if ( isdefined( level.zombie_vars[player.team] ) && isdefined( level.zombie_vars[player.team][time_name] ) )
                {
                    powerup_timer = level.zombie_vars[player.team][time_name];
                    powerup_on = level.zombie_vars[player.team][on_name];
                }
                else if ( isdefined( level.zombie_vars[time_name] ) )
                {
                    powerup_timer = level.zombie_vars[time_name];
                    powerup_on = level.zombie_vars[on_name];
                }

                if ( isdefined( powerup_timer ) && isdefined( powerup_on ) )
                {
                    player maps\mp\zombies\_zm_powerups::set_clientfield_powerups( client_field_name, powerup_timer, powerup_on, flashing_timers, flashing_values );
                    continue;
                }

                player setclientfieldtoplayer( client_field_name, 0 );
            }
        }
    }
}
