#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Player death animation on the DLC5 maps. Log lines start with "DEATHFALL >>".
// When the last player dies (game over), plain BO2 only takes the weapons and forces the player prone. Buried and Mob
// of the Dead set level.custom_player_fake_death to a proper death: the view falls to the floor (towards where the hit
// came from) and bounces, with the death-throe hands. The DLC5 maps set nothing, so this gives them that death
// (same code as Buried's zm_player_fake_death / fall_down). Game modes that set their own (Grief, Turned) keep theirs.

main()
{
    // the dying hands: like Buried / Mob of the Dead, the weapon has to be precached or giveweapon does nothing
    if ( deathfall_is_dlc5_map() )
        precacheitem( "death_throe_zm" );
}

init()
{
    if ( !deathfall_is_dlc5_map() )
        return;

    level thread deathfall_setup();
}

deathfall_is_dlc5_map()
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

deathfall_setup()
{
    level endon( "end_game" );
    flag_wait( "initial_blackscreen_passed" );

    // the map / game mode had its chance to set one; only fill in the gap
    if ( isdefined( level.custom_player_fake_death ) )
    {
        println( "DEATHFALL >> " + getdvar( "mapname" ) + " already has a custom death, left alone" );
        return;
    }

    level.custom_player_fake_death = ::deathfall_fake_death;

    if ( !isdefined( level.custom_player_fake_death_cleanup ) )
        level.custom_player_fake_death_cleanup = ::deathfall_cleanup;

    println( "DEATHFALL >> falling death on " + getdvar( "mapname" ) );
}

deathfall_cleanup()
{
    if ( isdefined( self._fall_down_anchor ) )
    {
        self._fall_down_anchor delete();
        self._fall_down_anchor = undefined;
    }
}

// Buried's zm_player_fake_death
deathfall_fake_death( vdir )
{
    level notify( "fake_death" );
    self notify( "fake_death" );
    stance = self getstance();

    // Fr0sty: dying while moving / sprinting / looking around made the dying hands come up sped up (standing still they
    // looked right). Everything is locked the moment the player dies: frozen, zero velocity, no sprint / jump / melee /
    // aim / offhands / weapon switching, and (in deathfall_fall_down) a camera link with no look room at all.
    self freezecontrols( 1 );
    self setvelocity( ( 0, 0, 0 ) );
    self setmovespeedscale( 0 );
    self allowsprint( 0 );
    self allowjump( 0 );
    self allowmelee( 0 );
    self allowads( 0 );
    self disableoffhandweapons();
    self disableweaponcycling();

    self.ignoreme = 1;
    self enableinvulnerability();
    self takeallweapons();

    if ( isdefined( self.insta_killed ) && self.insta_killed )
    {
        self maps\mp\zombies\_zm::player_fake_death();
        self allowprone( 1 );
        self allowcrouch( 0 );
        self allowstand( 0 );
        wait 0.25;
        self freezecontrols( 1 );
    }
    else
    {
        self freezecontrols( 1 );
        self thread deathfall_fall_down( vdir, stance );
        wait 1;
    }
}

// Buried's fall_down: the view drops to the floor, drifting away from the hit, then bounces
deathfall_fall_down( vdir, stance )
{
    self endon( "disconnect" );
    level endon( "game_module_ended" );
    self ghost();
    origin = self.origin;
    xyspeed = ( 0, 0, 0 );
    angles = self getplayerangles();
    angles = ( angles[0], angles[1], angles[2] + randomfloatrange( -5, 5 ) );

    if ( isdefined( vdir ) && length( vdir ) > 0 )
    {
        xyspeedmag = 40 + randomint( 12 ) + randomint( 12 );
        xyspeed = xyspeedmag * vectornormalize( ( vdir[0], vdir[1], 0 ) );
    }

    linker = spawn( "script_model", ( 0, 0, 0 ) );
    linker setmodel( "tag_origin" );
    linker.origin = origin;
    linker.angles = angles;
    self._fall_down_anchor = linker;
    // Fr0sty: no look room at all (arcs 0), the view follows the anchor
    self playerlinktodelta( linker, "tag_origin", 1, 0, 0, 0, 0, 1 );
    self setvelocity( ( 0, 0, 0 ) );
    self playsoundtoplayer( "zmb_player_death_fall", self );
    falling = stance != "prone";

    if ( falling )
    {
        origin = playerphysicstrace( origin, origin + xyspeed );
        eye = self get_eye();
        floor_height = 10 + origin[2] - eye[2];
        origin = origin + ( 0, 0, floor_height );
        lerptime = 0.5;
        linker moveto( origin, lerptime, lerptime );
        linker rotateto( angles, lerptime, lerptime );
    }

    self freezecontrols( 1 );

    if ( falling )
        linker waittill( "movedone" );

    // the dying hands come up the moment the view hits the floor (as Buried): any later and the game-over sequence
    // has already taken the player's weapons away, so no hands show. One server frame first so the player's client has
    // caught up with the locked view.
    wait 0.05;
    self giveweapon( "death_throe_zm" );

    self switchtoweapon( "death_throe_zm" );

    if ( falling )
    {
        bounce = randomint( 4 ) + 8;
        origin = origin + ( 0, 0, bounce ) - xyspeed * 0.1;
        lerptime = bounce / 50.0;
        linker moveto( origin, lerptime, 0, lerptime );
        linker waittill( "movedone" );
        origin = origin + ( 0, 0, bounce * -1 ) + xyspeed * 0.1;
        lerptime = lerptime / 2.0;
        linker moveto( origin, lerptime, lerptime );
        linker waittill( "movedone" );
        linker moveto( origin, 5, 0 );
    }

    wait 15;
    linker delete();
}
