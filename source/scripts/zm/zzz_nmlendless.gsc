// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// No Man's Land endless mode (own script, separate from DLC5's Moon scripts). Log lines start with "NMLEND >>".
// Only on the "nomansland" start. User's choices (2026-09-24): no rounds (everything scales with time survived),
// dog WAVES, one fixed box in NML.
//   Endless: level.zombie_total is kept topped up, so stock round_spawning never runs dry and round_wait never ends
//   (the round number stays 1). Every minute counts as a round: stock ai_calculate_health( 1 + minutes ), the stock
//   move-speed and spawn-delay steps, and the per-round powerup cap is reset (else drops stop after 4).
//   Dogs: first wave at 10 min, then every 2 min, via stock _zm_ai_dogs::special_dog_spawn (stock dog-round health).
//   HUD: a survival timer.
// The Mystery Box: Moon's active box is moved to the user's NML spot and locked there.
//   Box entities (zbarriers) are placed in the map and can't be spawned by script, so one is moved instead.
//   Moon has 4 box locations (chest_0..3); layout taken from the active one (probe 2026-09-24):
//   trigger stub 22.5 units in front along -right(angles), zbarrier 2 back along forward and 8 along right.

main()
{
    // invisible collision blocks from common_zm (same as the NML perk machines)
    precachemodel( "collision_geo_32x32x128_standard" );
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread nmlend_box();
    level thread nmlend_endless();
}

nmlend_wait_start()
{
    while ( getplayers().size == 0 )
        wait 0.1;

    if ( isdefined( level.flag ) && isdefined( level.flag[ "initial_blackscreen_passed" ] ) )
    {
        while ( !level.flag[ "initial_blackscreen_passed" ] )
            wait 0.1;
    }
}

nmlend_box()
{
    level endon( "end_game" );
    nmlend_wait_start();
    wait 1;

    if ( getdvar( "ui_zm_mapstartlocation" ) != "nomansland" )
        return;

    if ( !isdefined( level.chests ) || !isdefined( level.chest_index ) )
    {
        println( "NMLEND >> no box system on this map, box not moved" );
        return;
    }

    chest = level.chests[ level.chest_index ];

    if ( !isdefined( chest.zbarrier ) || !isdefined( chest.unitrigger_stub ) )
    {
        println( "NMLEND >> active box has no zbarrier/trigger, box not moved" );
        return;
    }

    // never move: no teddy bear (stock checks this dvar before every joker roll)
    setdvar( "magic_chest_movable", "0" );

    // the user's spot: stood at (14609.9, -14551, -679.9) facing +x into a wall at x 14630; the box sits against
    // that wall with its front (-right) facing back at the player, i.e. yaw 90
    origin = ( 14606, -14551, -679.875 );
    angles = ( 0, 90, 0 );
    f = anglestoforward( angles );
    r = anglestoright( angles );

    chest maps\mp\zombies\_zm_magicbox::hide_chest( 0 );
    wait 0.5;

    chest.origin = origin;
    chest.angles = angles;
    chest.zbarrier.origin = origin + f * -2 + r * 8;
    chest.zbarrier.angles = angles;
    chest.unitrigger_stub.origin = origin + r * -22.5;
    chest.unitrigger_stub.angles = angles;
    // the stub was filed under its old zone; clear it so show_chest re-files it under NML's zone
    chest.unitrigger_stub.in_zone = undefined;

    chest thread maps\mp\zombies\_zm_magicbox::show_chest();

    // the box's own collision is part of the map at its old spot: two 32x32 blocks along the box's length,
    // tops at box height (~44) so nothing sticks up above the lid
    for ( i = -1; i <= 1; i += 2 )
    {
        tile = spawn( "script_model", chest.zbarrier.origin + f * ( i * 18 ) + ( 0, 0, 44 - 64 ), 1 );
        tile.angles = angles;
        tile setmodel( "collision_geo_32x32x128_standard" );
        tile.script_noteworthy = "clip";

        if ( i == 1 )
            tile disconnectpaths();
    }
    println( "NMLEND >> box " + chest.script_noteworthy + " moved to " + origin + ", zbarrier now at " + chest.zbarrier.origin + ", locked (magic_chest_movable 0)" );
}

nmlend_endless()
{
    level endon( "end_game" );
    nmlend_wait_start();

    if ( getdvar( "ui_zm_mapstartlocation" ) != "nomansland" )
        return;

    level.nmlend_start = gettime();
    // test switch: "set dlc5_nml_fast 1" before loading makes each scaled minute last 6 seconds
    level.nmlend_minute = 60;

    if ( getdvar( "dlc5_nml_fast" ) == "1" )
    {
        level.nmlend_minute = 6;
        println( "NMLEND >> FAST TEST MODE: 1 minute = 6 seconds" );
    }

    level thread nmlend_keep_spawning();
    level thread nmlend_timer_hud();
    level._supress_survived_screen = 1;
    level.custom_end_screen = ::nmlend_end_screen;
    level thread nmlend_dog_waves();
    println( "NMLEND >> endless mode on" );

    for ( minute = 1;; minute++ )
    {
        wait level.nmlend_minute;
        nmlend_ramp( 1 + minute );
        level thread nmlend_clock_flash();
    }
}

// the stock round spawner stops when zombie_total hits 0 and the round ends when that and the living count do
nmlend_keep_spawning()
{
    level endon( "end_game" );

    for (;;)
    {
        if ( !isdefined( level.zombie_total ) || level.zombie_total < 10 )
            level.zombie_total = 10;

        wait 0.5;
    }
}

// what the stock round transition does, with minutes standing in for rounds
nmlend_ramp( round )
{
    maps\mp\zombies\_zm::ai_calculate_health( round );

    if ( isdefined( level.gamedifficulty ) && level.gamedifficulty == 0 )
        level.zombie_move_speed = round * level.zombie_vars[ "zombie_move_speed_multiplier_easy" ];
    else
        level.zombie_move_speed = round * level.zombie_vars[ "zombie_move_speed_multiplier" ];

    timer = level.zombie_vars[ "zombie_spawn_delay" ];

    if ( timer > 0.08 )
        level.zombie_vars[ "zombie_spawn_delay" ] = timer * 0.95;
    else
        level.zombie_vars[ "zombie_spawn_delay" ] = 0.08;

    level.powerup_drop_count = 0;
    println( "NMLEND >> minute " + ( round - 1 ) + ": zombies now round-" + round + " health " + level.zombie_health + ", move speed " + level.zombie_move_speed + ", spawn delay " + level.zombie_vars[ "zombie_spawn_delay" ] );
}

// The survival clock sits in the bottom-left corner of the safe area (user request) in the round counter's red, and flashes white
// and back every minute like the counter does on a new round. The corner round number itself is the engine's
// setroundsplayed() display (numbers only), so DLC5's Moon round HUD is switched off by its own dvar and blanked.
nmlend_timer_hud()
{
    setdvar( "moonroundhud", "0" );
    wait 0.2;
    setroundsplayed( 0 );

    level.nmlend_clock = newhudelem();
    clock = level.nmlend_clock;
    // user_* alignments follow the player's safe-area setting; right in the bottom-left corner of it
    clock.alignx = "left";
    clock.aligny = "bottom";
    clock.horzalign = "user_left";
    clock.vertalign = "user_bottom";
    clock.x = 0;
    clock.y = 0;
    clock.font = "objective";
    clock.fontscale = 2.6;
    clock.color = ( 0.55, 0, 0 );
    clock.alpha = 0;
    clock.hidewheninmenu = 1;
    clock.foreground = 0;
    clock settimerup( 0 );
    clock fadeovertime( 1 );
    clock.alpha = 1;
}

// the counter's new-round flash: white, then back to red
nmlend_clock_flash()
{
    clock = level.nmlend_clock;

    if ( !isdefined( clock ) )
        return;

    clock fadeovertime( 0.5 );
    clock.color = ( 1, 1, 1 );
    wait 1;
    clock fadeovertime( 1.5 );
    clock.color = ( 0.55, 0, 0 );
}

// Replaces the stock "You Survived 1 Round" with BO1's No Man's Land line, fed with our time. The stock end_game
// still has this text (ZOMBIE_SURVIVED_NOMANS) but only for a map called "zombie_moon", so the stock screen is
// suppressed and redrawn here with its own layout.
nmlend_end_screen()
{
    seconds = 0;

    if ( isdefined( level.nmlend_start ) )
        seconds = int( ( gettime() - level.nmlend_start ) / 1000 );

    time = maps\mp\zombies\_zm::to_mins( seconds );
    println( "NMLEND >> game over after " + seconds + " seconds (" + time + ")" );

    if ( isdefined( level.nmlend_clock ) )
        level.nmlend_clock destroy();

    foreach ( player in getplayers() )
    {
        game_over = newclienthudelem( player );
        game_over.alignx = "center";
        game_over.aligny = "middle";
        game_over.horzalign = "center";
        game_over.vertalign = "middle";
        game_over.y = game_over.y - 130;
        game_over.foreground = 1;
        game_over.fontscale = 3;
        game_over.alpha = 0;
        game_over.color = ( 1, 1, 1 );
        game_over.hidewheninmenu = 1;
        game_over settext( &"ZOMBIE_GAME_OVER" );
        game_over fadeovertime( 1 );
        game_over.alpha = 1;

        survived = newclienthudelem( player );
        survived.alignx = "center";
        survived.aligny = "middle";
        survived.horzalign = "center";
        survived.vertalign = "middle";
        survived.y = survived.y - 100;
        survived.foreground = 1;
        survived.fontscale = 2;
        survived.alpha = 0;
        survived.color = ( 1, 1, 1 );
        survived.hidewheninmenu = 1;
        survived settext( &"ZOMBIE_SURVIVED_NOMANS", time );
        survived fadeovertime( 1 );
        survived.alpha = 1;
    }
}

nmlend_dog_waves()
{
    level endon( "end_game" );

    if ( !isdefined( level.dog_spawners ) || level.dog_spawners.size == 0 )
    {
        println( "NMLEND >> no dog spawners on this map, dog waves off" );
        return;
    }

    wait level.nmlend_minute * 10;

    for ( wave = 1;; wave++ )
    {
        // stock dog-round health steps
        if ( wave == 1 )
            level.dog_health = 400;
        else if ( wave == 2 )
            level.dog_health = 900;
        else if ( wave == 3 )
            level.dog_health = 1300;
        else
            level.dog_health = 1600;

        count = 2 + wave * getplayers().size;

        if ( count > 12 )
            count = 12;

        println( "NMLEND >> dog wave " + wave + ": " + count + " dogs, health " + level.dog_health );
        level thread nmlend_spawn_dogs( count );
        wait level.nmlend_minute * 2;
    }
}

// special_dog_spawn refuses while 9+ dogs are alive, so feed them in one at a time
nmlend_spawn_dogs( count )
{
    level endon( "end_game" );
    spawned = 0;

    for ( tries = 0; spawned < count && tries < 200; tries++ )
    {
        if ( maps\mp\zombies\_zm_ai_dogs::special_dog_spawn( undefined, 1 ) )
            spawned++;

        wait randomfloatrange( 0.5, 1.5 );
    }
}
