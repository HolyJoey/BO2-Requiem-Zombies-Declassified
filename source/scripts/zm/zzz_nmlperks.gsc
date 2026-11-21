// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// No Man's Land perk machines - only on the "nomansland" start location.
// The Moon's own perks never spawn on this start (their structs are tagged for the moon start) and the teleporter
// is off, so these bring them to Area 51. Positions are where the player STOOD in the NMLPOS scouting log.
// Machines are always on (NML has no power) and hand the perk over through the stock drinking code.
// To change a perk or spot, edit nmlperk_spots().
// Rotation fix-up: stand by a machine and `set dlc5_turn 90` (or -90, 15, ...) turns the NEAREST machine; the log
// prints its final yaw ("NMLPERK >> ... now faces N") to copy into the spot's yaw below.

main()
{
    // zm_collision_perks1 (what stock machines use) is not loaded on this map, so each machine's footprint is tiled
    // with these 32x32x128 boxes from common_zm instead
    precachemodel( "collision_geo_32x32x128_standard" );
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level thread nmlperk_setup();
}

nmlperk_spots()
{
    spots = [];

    qr = nmlperk_spot( "specialty_quickrevive", ( 14193.5, -14115.7, -679.9 ), 118.97, 180 ); // scout #7, next to spawn
    qr.back = 24;   // moved back toward the wall behind it
    spots[ spots.size ] = qr;

    spots[ spots.size ] = nmlperk_spot( "specialty_rof",                     ( 14088.4, -13448.0, -679.9 ), 338.39, 70 );  // scout #2
    spots[ spots.size ] = nmlperk_spot( "specialty_longersprint",            ( 13511.8, -13489.5, -679.9 ), 1.13, 90 );    // scout #3
    spots[ spots.size ] = nmlperk_spot( "specialty_deadshot",                ( 14609.6, -14006.0, -679.9 ), 179.55, 270 ); // scout #1
    spots[ spots.size ] = nmlperk_spot( "specialty_additionalprimaryweapon", ( 14381.3, -14836.6, -679.9 ), 270.63, 180 ); // scout #5
    spots[ spots.size ] = nmlperk_spot( "specialty_flakjacket",              ( 13833.5, -15040.1, -619.9 ), 313.71, 45 );  // scout #6, far end (turned round: 225 had its back to the player)
    // Speed Cola gets its own machine now that the NML machine is locked to Jugg; facing from the nearest wall
    spots[ spots.size ] = nmlperk_spot( "specialty_fastreload",              ( 13931.0, -15561.9, -620.5 ), 179.40 );
    // scout #8 ( 14419.6, -14782.3, -679.9 ) left empty: only 66 units from #5
    return spots;
}

nmlperk_spot( perk, stand, look_yaw, yaw )
{
    spot = spawnstruct();
    spot.perk = perk;
    spot.stand = stand;
    spot.look_yaw = look_yaw;
    spot.yaw = yaw;     // optional: a fixed facing that overrides the wall guess
    return spot;
}

// name shown in the hint, key into level.machine_assets, full price, jingle alias
nmlperk_info( perk )
{
    info = spawnstruct();

    switch ( perk )
    {
        case "specialty_quickrevive":
            info.name = "Quick Revive";
            info.asset = "revive";
            info.light = "revive_light";
            info.cost = 1500;
            info.jingle = "mus_perks_revive_sting";
            break;
        case "specialty_rof":
            info.name = "Double Tap Root Beer";
            info.asset = "doubletap";
            info.light = "doubletap_light";
            info.cost = 2000;
            info.jingle = "mus_perks_doubletap_sting";
            break;
        case "specialty_longersprint":
            info.name = "Stamin-Up";
            info.asset = "marathon";
            info.light = "marathon_light";
            info.cost = 2000;
            info.jingle = "mus_perks_stamin_sting";
            break;
        case "specialty_deadshot":
            info.name = "Deadshot Daiquiri";
            info.asset = "deadshot";
            info.light = "deadshot_light";
            info.cost = 1500;
            info.jingle = "mus_perks_deadshot_sting";
            break;
        case "specialty_additionalprimaryweapon":
            info.name = "Mule Kick";
            info.asset = "additionalprimaryweapon";
            info.light = "additionalprimaryweapon_light";
            info.cost = 4000;
            info.jingle = "mus_perks_mulekick_sting";
            break;
        case "specialty_fastreload":
            info.name = "Speed Cola";
            info.asset = "sleight";
            info.light = "sleight_light";
            info.cost = 3000;
            info.jingle = "mus_perks_speed_sting";
            info.map_model = "vending_sleight";    // no machine_assets entry: the map places its Speed Cola by hand
            break;
        case "specialty_flakjacket":
            info.name = "PhD Flopper";
            info.asset = "divetonuke";
            info.light = "divetonuke_light";
            info.cost = 2000;
            info.jingle = "mus_perks_phd_sting";
            break;
        default:
            return undefined;
    }

    return info;
}

nmlperk_setup()
{
    level endon( "end_game" );

    for ( t = 0; t < 600; t++ )
    {
        if ( isdefined( level.machine_assets ) && getplayers().size > 0 )
            break;

        wait 0.1;
    }

    wait 1;

    if ( getdvar( "ui_zm_mapstartlocation" ) != "nomansland" )
    {
        println( "NMLPERK >> normal Moon start, no extra perk machines" );
        return;
    }

    built = 0;
    level.nmlperk_machines = [];
    level thread nmlperk_turn_watch();
    level thread nmlperk_jugg_only();

    foreach ( spot in nmlperk_spots() )
    {
        if ( spot nmlperk_build() )
            built++;
    }

    println( "NMLPERK >> " + built + " perk machines placed" );
}

nmlperk_build()
{
    perk = self.perk;
    info = nmlperk_info( perk );

    if ( !isdefined( info ) )
    {
        println( "NMLPERK >> unknown perk " + perk + ", skipped" );
        return false;
    }

    model_name = nmlperk_model( info );

    if ( !isdefined( model_name ) )
    {
        println( "NMLPERK >> " + info.name + " has no machine model on this map, skipped" );
        return false;
    }

    // stand the machine on the floor where the player stood
    down = bullettrace( self.stand + ( 0, 0, 40 ), self.stand - ( 0, 0, 120 ), 0, undefined );
    origin = self.stand;

    if ( down["fraction"] < 1 )
        origin = down["position"];

    if ( isdefined( self.yaw ) )
        yaw = self.yaw;
    else
        yaw = self nmlperk_facing( origin );

    if ( isdefined( self.back ) )
        origin = nmlperk_push_back( origin, yaw, self.back, info.name );

    machine = spawn( "script_model", origin );
    machine.angles = ( 0, yaw, 0 );
    machine setmodel( model_name );
    machine.targetname = "nml_vending_" + info.asset;

    // real footprint from the model files (the engine's own bounds are a loose cube ~1.8x the machine's diagonal)
    footprint = nmlperk_footprint( model_name );
    machine.nmlperk_lmins = footprint.lmins;
    machine.nmlperk_lmaxs = footprint.lmaxs;
    machine.nmlperk_name = info.name;
    machine.nmlperk_tiles = [];

    size = machine.nmlperk_lmaxs - machine.nmlperk_lmins;
    reach = size[0];

    if ( size[1] > reach )
        reach = size[1];

    reach = reach * 0.5;
    println( "NMLPERK >> " + info.name + " (" + model_name + ") footprint " + int( size[0] ) + " x " + int( size[1] ) + " x " + int( size[2] ) + footprint.note );

    // the bottle-clink when a player walks into it: stock machines use a separate trigger for this, not the collision
    bump = spawn( "trigger_radius", origin, 0, reach + 20, 80 );
    bump triggerignoreteam();
    bump.script_sound = nmlperk_bump_sound();
    bump thread nmlperk_bump();
    machine.nmlperk_bump = bump;

    machine thread nmlperk_light( info.light, info.name );
    level.nmlperk_machines[ level.nmlperk_machines.size ] = machine;

    cost = info.cost;

    if ( perk == "specialty_quickrevive" && getplayers().size == 1 )
        cost = 500;

    // reaches past the machine's widest side so a player pressed against the collision is inside it
    trig = spawn( "trigger_radius_use", origin, 0, reach + 32, 70 );
    trig triggerignoreteam();
    trig setcursorhint( "HINT_NOICON" );
    trig usetriggerrequirelookat();
    trig sethintstring( "Hold ^3[{+activate}]^7 for " + info.name + " [Cost: " + cost + "]" );
    trig.script_noteworthy = perk;
    trig.script_label = info.jingle;
    trig.power_on = 1;
    trig.nmlperk_cost = cost;
    trig.nmlperk_name = info.name;
    trig thread nmlperk_think();
    machine.nmlperk_trig = trig;
    machine nmlperk_fit();

    println( "NMLPERK >> " + info.name + " ($" + cost + ") at " + origin + " facing " + int( yaw ) );
    return true;
}

nmlperk_turn_watch()
{
    level endon( "end_game" );
    setdvar( "dlc5_turn", "" );

    for (;;)
    {
        value = getdvar( "dlc5_turn" );

        if ( value != "" )
        {
            setdvar( "dlc5_turn", "" );
            players = getplayers();

            if ( players.size > 0 && isdefined( players[0] ) )
                nmlperk_turn_nearest( players[0], int( value ) );
        }

        wait 0.1;
    }
}

nmlperk_turn_nearest( player, degrees )
{
    nearest = undefined;
    nearest_dist = 400;

    foreach ( machine in level.nmlperk_machines )
    {
        dist = distance( player.origin, machine.origin );

        if ( dist < nearest_dist )
        {
            nearest_dist = dist;
            nearest = machine;
        }
    }

    if ( !isdefined( nearest ) )
    {
        player iprintlnbold( "No perk machine within 400 units" );
        return;
    }

    yaw = nearest.angles[1] + degrees;

    while ( yaw < 0 )
        yaw += 360;

    while ( yaw >= 360 )
        yaw -= 360;

    nearest.angles = ( 0, yaw, 0 );
    nearest nmlperk_fit();

    player iprintlnbold( nearest.nmlperk_name + " now faces " + int( yaw ) );
    println( "NMLPERK >> " + nearest.nmlperk_name + " now faces " + int( yaw ) + " (at " + nearest.origin + ")" );
}

// Slide a machine backwards, stopping short of any wall behind it. Its back is yaw + 90 (see nmlperk_facing).
nmlperk_push_back( origin, yaw, amount, name )
{
    dir = anglestoforward( ( 0, yaw + 90, 0 ) );
    eye = origin + ( 0, 0, 40 );
    trace = bullettrace( eye, eye + dir * ( amount + 24 ), 0, undefined );
    move = amount;

    if ( trace["fraction"] < 1 )
    {
        room = distance( eye, trace["position"] ) - 24;

        if ( room < move )
            move = room;

        if ( move < 0 )
            move = 0;
    }

    println( "NMLPERK >> " + name + " moved back " + int( move ) + " of " + amount + " units" );
    return origin + dir * move;
}

// The NML machine normally swaps between Jugg and Speed Cola: the inactive perk's model is hidden and its trigger parked
// 10000 units underground. Keep it on Jugg for the whole game, re-applying if the map's own logic swaps it back.
nmlperk_jugg_only()
{
    level endon( "end_game" );
    wait 2;

    jugg_model = nmlperk_first( getentarray( "vending_jugg", "targetname" ) );
    speed_model = nmlperk_first( getentarray( "vending_sleight", "targetname" ) );
    jugg_trig = undefined;
    speed_trig = undefined;

    foreach ( trig in getentarray( "zombie_vending", "targetname" ) )
    {
        if ( !isdefined( trig.script_noteworthy ) )
            continue;

        if ( trig.script_noteworthy == "specialty_armorvest" )
            jugg_trig = trig;
        else if ( trig.script_noteworthy == "specialty_fastreload" )
            speed_trig = trig;
    }

    println( "NMLPERK >> jugg-only: jugg model " + isdefined( jugg_model ) + " speed model " + isdefined( speed_model ) + " jugg trigger " + isdefined( jugg_trig ) + " speed trigger " + isdefined( speed_trig ) );
    powered_logged = 0;

    for (;;)
    {
        if ( isdefined( jugg_model ) )
            jugg_model show();

        if ( isdefined( speed_model ) )
            speed_model hide();

        if ( isdefined( jugg_trig ) && jugg_trig.origin[2] < -5000 )
        {
            jugg_trig.origin = jugg_trig.origin + ( 0, 0, 10000 );
            println( "NMLPERK >> jugg-only: brought the Jugg trigger back up" );
        }

        // When the map picks Speed Cola it only powers that one, so stock Jugg sits at "power must be activated" and
        // won't sell. "juggernog_on" is stock's own switch: on model, glow, hum, then the trigger gets its buy prompt.
        if ( isdefined( jugg_trig ) && !( isdefined( jugg_trig.power_on ) && jugg_trig.power_on ) )
        {
            level notify( "juggernog_on" );

            if ( !powered_logged )
            {
                powered_logged = 1;
                println( "NMLPERK >> jugg-only: Jugg was unpowered, sent juggernog_on" );
            }
        }

        if ( isdefined( speed_trig ) && speed_trig.origin[2] > -5000 )
        {
            speed_trig.origin = speed_trig.origin - ( 0, 0, 10000 );
            println( "NMLPERK >> jugg-only: parked the Speed Cola trigger" );
        }

        wait 1;
    }
}

nmlperk_first( ents )
{
    if ( ents.size > 0 )
        return ents[0];

    return undefined;
}

nmlperk_bump()
{
    level endon( "end_game" );

    for (;;)
    {
        self waittill( "trigger", player );

        if ( !isplayer( player ) )
            continue;

        player playsound( self.script_sound );

        // once per bump, not every frame while pressed against it
        while ( isdefined( player ) && isalive( player ) && player istouching( self ) )
            wait 0.5;
    }
}

// Same clink as the NML Jugg machine, whose bump works. Order: a *bump* sound on any entity near that machine (the
// map's own bump trigger, whatever it is named), then BO1's alias, then BO2's (which is quiet).
nmlperk_bump_sound()
{
    if ( isdefined( level.nmlperk_bump_alias ) )
        return level.nmlperk_bump_alias;

    jugg = nmlperk_first( getentarray( "vending_jugg", "targetname" ) );

    if ( isdefined( jugg ) )
    {
        foreach ( ent in getentarray() )
        {
            if ( !isdefined( ent ) || !isdefined( ent.script_sound ) || ent.script_sound == "" )
                continue;

            if ( distance2d( ent.origin, jugg.origin ) > 200 )
                continue;

            classname = "?";

            if ( isdefined( ent.classname ) )
                classname = ent.classname;

            println( "NMLPERK >> found '" + ent.script_sound + "' on a " + classname + " by the NML Jugg" );

            // only a bump sound: the Jugg buy trigger carries its jingle here, which every machine then played
            if ( issubstr( tolower( ent.script_sound ), "bump" ) && soundexists( ent.script_sound ) )
            {
                level.nmlperk_bump_alias = ent.script_sound;
                break;
            }
        }
    }

    if ( !isdefined( level.nmlperk_bump_alias ) )
    {
        if ( soundexists( "fly_bump_bottle" ) )
            level.nmlperk_bump_alias = "fly_bump_bottle";
        else
            level.nmlperk_bump_alias = "zmb_perks_bump_bottle";
    }

    println( "NMLPERK >> bump sound " + level.nmlperk_bump_alias );
    return level.nmlperk_bump_alias;
}

// Collision and triggers for the machine's current facing: its footprint tiled with 32x32x128 boxes (rotated with it),
// triggers centred on the body rather than the origin, which some models sit well off (PhD).
nmlperk_fit()
{
    if ( isdefined( self.nmlperk_pathtile ) )
        self.nmlperk_pathtile connectpaths();

    foreach ( tile in self.nmlperk_tiles )
        tile delete();

    self.nmlperk_tiles = [];

    // a hair inside the model so players can press right up against it
    lmins = self.nmlperk_lmins + ( 2, 2, 0 );
    lmaxs = self.nmlperk_lmaxs - ( 2, 2, 0 );
    fwd = anglestoforward( self.angles );
    right = anglestoright( self.angles );

    xs = nmlperk_tile_centres( lmins[0], lmaxs[0] );
    ys = nmlperk_tile_centres( lmins[1], lmaxs[1] );

    // 128-tall boxes centred on their origin: the first spans floor to 128
    zs = [];

    for ( z = 64; z - 64 < lmaxs[2]; z += 128 )
        zs[ zs.size ] = z;

    foreach ( x in xs )
    {
        foreach ( y in ys )
        {
            foreach ( z in zs )
            {
                tile = spawn( "script_model", self.origin + fwd * x - right * y + ( 0, 0, z ), 1 );
                tile.angles = self.angles;
                tile setmodel( "collision_geo_32x32x128_standard" );
                tile.script_noteworthy = "clip";
                self.nmlperk_tiles[ self.nmlperk_tiles.size ] = tile;
            }
        }
    }

    centre = self.origin + fwd * ( ( lmins[0] + lmaxs[0] ) * 0.5 ) - right * ( ( lmins[1] + lmaxs[1] ) * 0.5 );

    // Only ONE tile per machine blocks zombie pathing: the engine caps how many entities may disconnect paths
    // ("Max number of disconnected paths exceeded" with every tile doing it). The rest are just solid.
    self.nmlperk_pathtile = undefined;
    best = 99999;

    foreach ( tile in self.nmlperk_tiles )
    {
        dist = distance2d( tile.origin, centre );

        if ( dist < best )
        {
            best = dist;
            self.nmlperk_pathtile = tile;
        }
    }

    if ( isdefined( self.nmlperk_pathtile ) )
        self.nmlperk_pathtile disconnectpaths();

    self.nmlperk_trig.origin = centre + ( 0, 0, 30 );
    self.nmlperk_bump.origin = centre + ( 0, 0, 30 );

}

// Evenly spaced 32-wide tile centres whose outer edges land exactly on lo and hi.
nmlperk_tile_centres( lo, hi )
{
    centres = [];
    span = hi - lo;

    if ( span <= 32 )
    {
        centres[0] = ( lo + hi ) * 0.5;
        return centres;
    }

    count = int( span / 32 );

    if ( count * 32 < span )
        count++;

    step = ( span - 32 ) / ( count - 1 );

    for ( i = 0; i < count; i++ )
        centres[i] = lo + 16 + step * i;

    return centres;
}

// Machine footprints in the model's own axes (X across the front, -Y out of the front, Z up), measured from the stock
// BO2 models' LOD0 geometry (Nuketown / Die Rise / TranZit). Deadshot and PhD are the port's own models, which cannot
// be read, so they use Quick Revive's shape - the engine's bounds put them at about the same size.
nmlperk_footprint( model_name )
{
    fp = spawnstruct();
    fp.note = "";

    switch ( model_name )
    {
        case "zombie_vending_revive_on":
            fp.lmins = ( -24.7, -23.8, 0 );
            fp.lmaxs = ( 24.7, 11.7, 85.4 );
            break;
        case "zombie_vending_doubletap2_on":
            fp.lmins = ( -26.7, -25.4, 0 );
            fp.lmaxs = ( 26.7, 0, 91.4 );
            break;
        case "zombie_vending_sleight_on":
            fp.lmins = ( -24.9, -18.5, 0 );
            fp.lmaxs = ( 26.1, 13.1, 104.1 );
            break;
        case "zombie_vending_jugg_on":
            fp.lmins = ( -14.8, -18.5, 0 );
            fp.lmaxs = ( 14.8, 18.3, 99.7 );
            break;
        case "zombie_vending_three_gun_on":
            fp.lmins = ( -33.5, -21.3, 0 );
            fp.lmaxs = ( 33.5, 21.3, 116.8 );
            break;
        case "zombie_vending_marathon_on":
            fp.lmins = ( -23.2, -19.0, 0 );
            fp.lmaxs = ( 23.2, 7.7, 88.2 );
            break;
        default:
            fp.lmins = ( -24.7, -23.8, 0 );
            fp.lmaxs = ( 24.7, 11.7, 85.4 );
            fp.note = " (estimated - Quick Revive's shape)";
            break;
    }

    return fp;
}

// The glow stock machines get when powered.
nmlperk_light( fx_name, perk_name )
{
    self endon( "death" );
    wait 1;

    if ( !isdefined( level._effect ) || !isdefined( level._effect[ fx_name ] ) )
    {
        println( "NMLPERK >> no light effect '" + fx_name + "' loaded for " + perk_name );
        return;
    }

    playfxontag( level._effect[ fx_name ], self, "tag_origin" );
}

// Model for a machine: the perk system's lit model, or a model borrowed from a machine the map placed itself.
nmlperk_model( info )
{
    if ( isdefined( level.machine_assets[ info.asset ] ) && isdefined( level.machine_assets[ info.asset ].on_model ) )
        return level.machine_assets[ info.asset ].on_model;

    if ( isdefined( info.map_model ) )
    {
        placed = nmlperk_first( getentarray( info.map_model, "targetname" ) );

        if ( isdefined( placed ) && isdefined( placed.model ) && placed.model != "" )
        {
            println( "NMLPERK >> " + info.name + " borrows the map's model " + placed.model );
            return placed.model;
        }
    }

    return undefined;
}

// Back against the nearest wall within 100 units; otherwise the way the player was looking.
nmlperk_facing( origin )
{
    eye = origin + ( 0, 0, 40 );
    best = undefined;
    best_dist = 100;

    for ( i = 0; i < 36; i++ )
    {
        dir = anglestoforward( ( 0, i * 10, 0 ) );
        trace = bullettrace( eye, eye + dir * 100, 0, undefined );

        if ( trace["fraction"] >= 1 || abs( trace["normal"][2] ) > 0.3 )
            continue;

        dist = distance( eye, trace["position"] );

        if ( dist < best_dist )
        {
            best_dist = dist;
            best = trace;
        }
    }

    if ( !isdefined( best ) )
        return self.look_yaw;

    // The wall normal points out of the wall, which is where the front should face. These machine models face their
    // local -Y, not +X, so the front is yaw - 90: every automatic facing needed +90 in game (Mule Kick 90->180,
    // Deadshot 180->270, Stamin-Up 0->90, Double Tap 340->70).
    return vectortoangles( ( best["normal"][0], best["normal"][1], 0 ) )[1] + 90;
}

// Perk limit: a per-player override if one is set, else the level's (4 unless the map changes it).
nmlperk_limit( player )
{
    if ( isdefined( player.player_perk_purchase_limit ) )
        return player.player_perk_purchase_limit;

    if ( isdefined( level.perk_purchase_limit ) )
        return level.perk_purchase_limit;

    return 4;
}

nmlperk_think()
{
    level endon( "end_game" );
    perk = self.script_noteworthy;
    cost = self.nmlperk_cost;

    for (;;)
    {
        self waittill( "trigger", player );

        if ( !isdefined( self.nmlperk_used ) )
        {
            self.nmlperk_used = 1;
            println( "NMLPERK >> " + self.nmlperk_name + " trigger works" );
        }

        if ( !isplayer( player ) || !isalive( player ) )
            continue;

        if ( player maps\mp\zombies\_zm_laststand::player_is_in_laststand() || ( isdefined( player.intermission ) && player.intermission ) )
            continue;

        if ( player isthrowinggrenade() || player isswitchingweapons() )
            continue;

        if ( isdefined( player.is_drinking ) && player.is_drinking > 0 )
            continue;

        if ( !player maps\mp\zombies\_zm_magicbox::can_buy_weapon() )
            continue;

        if ( player hasperk( perk ) || player maps\mp\zombies\_zm_perks::has_perk_paused( perk ) )
        {
            player playsound( "evt_perk_deny" );
            continue;
        }

        if ( player.score < cost )
        {
            player playsound( "evt_perk_deny" );
            player maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "perk_deny", undefined, 0 );
            continue;
        }

        if ( isdefined( player.num_perks ) && player.num_perks >= nmlperk_limit( player ) )
        {
            player playsound( "evt_perk_deny" );
            player maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "sigh" );
            continue;
        }

        playsoundatposition( "evt_bottle_dispense", self.origin );
        player maps\mp\zombies\_zm_score::minus_to_player_score( cost, 1 );
        player.perk_purchased = perk;
        self thread maps\mp\zombies\_zm_audio::play_jingle_or_stinger( self.script_label );
        self thread maps\mp\zombies\_zm_perks::vending_trigger_post_think( player, perk );
        println( "NMLPERK >> " + player.name + " bought " + self.nmlperk_name + " for " + cost );
    }
}
