// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// No Man's Land wall buys - only on the "nomansland" start location.
// Positions are the WALL points (crosshair hits) from the NMLPOS scouting log, with the logged facing yaw.
// To change a gun, edit its line in the spot list; any gun the Moon already loads works (wall or box weapons).
// Built server-side: the gun model on the wall plus a use trigger, using the map's own costs and hint strings.

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    nmlwall_register_ballista();
    nmlwall_load_chalk();
    level thread nmlwall_setup();
}

// Stock BO2 chalk outlines live in common_zm (loaded on every zombies map), so Moon can use them.
nmlwall_load_chalk()
{
    level.nmlwall_chalk = [];
    level.nmlwall_chalk[ "m14_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_buy_m14" );
    level.nmlwall_chalk[ "m16_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_buy_m16" );
    level.nmlwall_chalk[ "ak74u_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_buy_ak74u" );
    level.nmlwall_chalk[ "870mcs_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_buy_870mcs" );
    level.nmlwall_chalk[ "mp5k_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_buy_mp5k" );
    // Buried's SVU chalk effect, repainted with the Origins Ballista chalk in our mod_patch.ff
    level.nmlwall_chalk[ "ballista_zm" ] = loadfx( "maps/zombie/fx_zmb_wall_dyn_svuas" );
}

// The Ballista is built into our mod.ff but Moon never registers it; do it the way zzz_zm_mk2box adds the Mk2.
// Wall-only: include_weapon( , false ) keeps it out of the box.
nmlwall_register_ballista()
{
    if ( isdefined( level.zombie_weapons ) && isdefined( level.zombie_weapons[ "ballista_zm" ] ) )
        return;

    inc = getfunction( "maps/mp/zombies/_zm_utility", "include_weapon" );
    add = getfunction( "maps/mp/zombies/_zm_weapons", "add_zombie_weapon" );

    if ( !isdefined( inc ) || !isdefined( add ) )
    {
        println( "NMLWALL >> getfunction failed, Ballista not registered" );
        return;
    }

    [[ inc ]]( "ballista_zm", false );
    [[ inc ]]( "ballista_upgraded_zm", false );
    [[ add ]]( "ballista_zm", "ballista_upgraded_zm", &"ZOMBIE_WEAPON_BALLISTA", 1000, "sniper", "", undefined );
    println( "NMLWALL >> ballista_zm registered (wall only, 1000)" );
}

nmlwall_spots()
{
    // WALL point + facing yaw from the NMLPOS scouting log (2026-09-23); fence spots face back at the player.
    // 2026-09-24: M14 and Ballista pushed 3 units into their fences, Ballista 8 units to the left (user request).
    spots = [];
    spots[ spots.size ] = nmlwall_spot( "m14_zm",    ( 14235.4, -13827.0, -620.4 ), 180, "M14" );     // spawn fence
    spots[ spots.size ] = nmlwall_spot( "ballista_zm", ( 13845.6, -13830.0, -620.4 ), 0, "Ballista" );  // spawn fence, from our mod.ff
    spots[ spots.size ] = nmlwall_spot( "mp5k_zm",   ( 13638.0, -14814.8, -620.2 ), 90, "MP5K" );
    spots[ spots.size ] = nmlwall_spot( "870mcs_zm", ( 13533.8, -14050.5, -620.6 ), 0, "Remington 870" );
    spots[ spots.size ] = nmlwall_spot( "m16_zm",    ( 14632.0, -13461.0, -617.6 ), 180, "M16" );
    spots[ spots.size ] = nmlwall_spot( "ak74u_zm",  ( 13857.2, -13515.2, -620.3 ), 230, "AK74u" );
    // the fence chalk sits a bit further out than the gun (user request 2026-09-24)
    spots[0].chalk_out = 2;
    spots[1].chalk_out = 3;
    // Buried's SVU chalk effect (repainted Ballista) draws off-centre, so move the Ballista onto it
    spots[1].gun_left = -6;
    return spots;
}

nmlwall_spot( weapon, point, yaw, name )
{
    spot = spawnstruct();
    spot.weapon = weapon;
    spot.point = point;
    spot.yaw = yaw;
    spot.name = name;
    return spot;
}

nmlwall_setup()
{
    level endon( "end_game" );

    for ( t = 0; t < 600; t++ )
    {
        if ( isdefined( level.zombie_weapons ) && getplayers().size > 0 )
            break;

        wait 0.1;
    }

    // bounds read during the loading blackscreen are bogus and fling the guns off the wall
    if ( isdefined( level.flag ) && isdefined( level.flag[ "initial_blackscreen_passed" ] ) )
    {
        while ( !level.flag[ "initial_blackscreen_passed" ] )
            wait 0.1;
    }

    wait 1;

    // list every gun this map loads, so a replacement for a missing one can be picked
    names = "";

    foreach ( key, w in level.zombie_weapons )
        names = names + key + " ";

    println( "NMLWALL >> map weapons: " + names );

    if ( getdvar( "ui_zm_mapstartlocation" ) != "nomansland" )
    {
        println( "NMLWALL >> normal Moon start, no extra wall buys" );
        return;
    }

    built = 0;

    foreach ( spot in nmlwall_spots() )
    {
        if ( spot nmlwall_build() )
            built++;
    }

    println( "NMLWALL >> " + built + " wall buys placed" );
}

nmlwall_build()
{
    weapon = self.weapon;

    if ( !isdefined( level.zombie_weapons[ weapon ] ) )
    {
        println( "NMLWALL >> " + weapon + " is not a zombie weapon on this map, skipped" );
        return false;
    }

    flat = anglestoforward( ( 0, self.yaw, 0 ) );

    // gun lies flat against the wall, barrel running along it
    model = spawn( "script_model", self.point + flat * 2 );
    model.angles = ( 0, self.yaw - 90, 0 );
    model setmodel( getweaponmodel( weapon ) );
    model useweaponhidetags( weapon );

    wait 0.05;

    // centre the gun on the saved point without pulling it off the wall; a gun is never ~2 feet off centre
    centre = ( model getabsmins() + model getabsmaxs() ) * 0.5;
    delta = self.point - centre;
    delta = delta - flat * vectordot( delta, flat );

    if ( length( delta ) < 24 )
        model.origin = model.origin + delta;
    else
        println( "NMLWALL >> " + weapon + " bounds look wrong (off by " + int( length( delta ) ) + "), not centring" );

    // per-spot nudge of the gun along the wall, to sit it on its chalk (+ = the player's RIGHT when facing the wall; measured in game)
    if ( isdefined( self.gun_left ) )
        model.origin = model.origin + anglestoforward( ( 0, self.yaw - 90, 0 ) ) * self.gun_left;

    if ( isdefined( level.nmlwall_chalk[ weapon ] ) )
    {
        // stock orientation: the effect is aimed the way the gun lies (barrel along the wall), not out of the wall
        along = anglestoforward( ( 0, self.yaw - 90, 0 ) );
        chalk_out = 1;

        if ( isdefined( self.chalk_out ) )
            chalk_out = self.chalk_out;

        chalk = spawnfx( level.nmlwall_chalk[ weapon ], self.point + flat * chalk_out, along, ( 0, 0, 1 ) );
        triggerfx( chalk );
        model hide();
        println( "NMLWALL >> " + weapon + " chalk drawn, gun hidden until first buy" );
    }

    model thread nmlwall_mag_attach( weapon );

    cost = maps\mp\zombies\_zm_weapons::get_weapon_cost( weapon );

    // Hand the buy to the stock wall-buy system (same as _zm_weapons::init_spawnable_weapon_upgrade), so the prompt,
    // purchase/ammo/PaP-ammo prices, sounds and the gun sliding out of the chalk all behave exactly like stock.
    model.targetname = "nmlwall_gun_" + weapon;
    stub = spawnstruct();
    stub.origin = self.point + flat * 8;
    stub.angles = ( 0, self.yaw, 0 );
    stub.script_unitrigger_type = "unitrigger_box_use";
    stub.script_width = 64;
    stub.script_length = 64;
    stub.script_height = 64;
    stub.cursor_hint = "HINT_NOICON";
    stub.require_look_at = 1;
    stub.targetname = "weapon_upgrade";
    stub.target = model.targetname;
    stub.zombie_weapon_upgrade = weapon;
    stub.weapon_upgrade = weapon;
    stub.clientfieldname = "nmlwall_" + weapon;
    stub.cost = cost;
    stub.hint_string = maps\mp\zombies\_zm_weapons::get_weapon_hint( weapon );
    stub.hint_parm1 = cost;
    stub.prompt_and_visibility_func = maps\mp\zombies\_zm_weapons::wall_weapon_update_prompt;
    maps\mp\zombies\_zm_unitrigger::unitrigger_force_per_player_triggers( stub, 1 );
    maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( stub, maps\mp\zombies\_zm_weapons::weapon_spawn_think );

    println( "NMLWALL >> " + weapon + " ($" + cost + ") at " + self.point + " facing " + int( self.yaw ) + " model " + model.model + " at " + model.origin );
    return true;
}

// The mag is the weapon's worldClipModel, modelled around its own origin. Only the M16 world model has a tag_clip
// bone, so each mag sits at an offset from the gun's root (tag_weapon), fitted from the models' side profiles
// (M16 = its real tag_clip). Hidden like the gun until the stock weapon_show reveal (which sets og_origin).
nmlwall_mag_attach( weapon )
{
    switch ( weapon )
    {
        case "m14_zm":
            mag = "t6_attach_mag_m14_world";
            offset = ( -7.2, 0, -1.5 );
            break;
        case "mp5k_zm":
            mag = "t6_attach_mag_mp5_world";
            offset = ( -5.8, 0, -0.4 );
            break;
        case "m16_zm":
            mag = "t6_attach_mag_m16_world";
            offset = ( -6.2, 0, -1.3 );
            break;
        case "ak74u_zm":
            mag = "t6_attach_mag_ak_world";
            offset = ( -5.2, 0, -0.9 );
            break;
        case "ballista_zm":
            mag = "t6_attach_mag_ballista_world";
            offset = ( -5.6, 0, -3.4 );
            break;
        default:
            return;
    }

    // place it in world space from the gun's own axes (x = barrel, y = left, z = up), then link without an offset
    f = anglestoforward( self.angles );
    r = anglestoright( self.angles );
    u = anglestoup( self.angles );
    clip = spawn( "script_model", self.origin + f * offset[0] - r * offset[1] + u * offset[2] );
    clip.angles = self.angles;
    clip setmodel( mag );
    clip linkto( self );
    clip hide();

    while ( isdefined( self ) && !isdefined( self.og_origin ) )
        wait 0.05;

    wait 0.05;
    clip show();
}
