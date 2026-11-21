// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
// Moon Earth, client side (see zzz_zm_moonearth.gsc). Log lines start with "MOONEARTH >>".
// BO1 puts its Earth card (p_zom_moon_earth, 37,500 units wide) ~128,000 units out; BO2 PC draws nothing that far
// (tested, also with r_zfar raised) and ignores setscale on client models. So mod_patch carries p_dlc5_moon_earth /
// _dest: BO1's cards and textures pre-shrunk by 12000/128466. They are drawn 12,000 units from each local player's
// eye along the exact direction of BO1's spot, following the player: BO1's size and place in the sky.

main()
{
}

init()
{
    if ( getdvar( "mapname" ) != "zm_moon" )
        return;

    level.moonearth_models = [];
    level thread moonearth_listen( "dlc5_se", "p_dlc5_moon_earth" );
    level thread moonearth_listen( "dlc5_sde", "p_dlc5_moon_earth_dest" );
    level thread moonearth_hide();
}

moonearth_bo1_spot()
{
    return ( -22060.8, -121800, 34463.4 );
}

// the pre-shrunk models are built for exactly this distance
moonearth_dist()
{
    return 12000;
}

moonearth_listen( note, model )
{
    for (;;)
    {
        level waittill( note );
        level.moonearth_model = model;
        moonearth_draw( model );
    }
}

moonearth_hide()
{
    for (;;)
    {
        level waittill( "dlc5_he" );
        level.moonearth_model = undefined;
        moonearth_remove();
        println( "MOONEARTH >> client removed the Earth" );
    }
}

moonearth_draw( model )
{
    moonearth_remove();
    level notify( "moonearth_redraw" );
    players = getlocalplayers();

    for ( i = 0; i < players.size; i++ )
    {
        earth = spawn( i, moonearth_bo1_spot(), "script_model" );
        earth.angles = ( 18, 78, 22 );
        earth setmodel( model );
        level.moonearth_models[level.moonearth_models.size] = earth;
        earth thread moonearth_follow( players[i] );
    }

    println( "MOONEARTH >> client drew " + model + " (follow mode)" );
}

// keep the Earth on the line from the player's eye to BO1's spot, at a distance BO2 still renders
moonearth_follow( player )
{
    self endon( "entityshutdown" );
    level endon( "moonearth_redraw" );

    while ( isdefined( self ) && isdefined( player ) )
    {
        eye = player.origin + ( 0, 0, 60 );
        to = moonearth_bo1_spot() - eye;
        d = moonearth_dist();
        self.origin = eye + vectornormalize( to ) * d;


        wait 0.01;
    }
}

moonearth_remove()
{
    level notify( "moonearth_redraw" );

    if ( isdefined( level.moonearth_models ) )
    {
        for ( i = 0; i < level.moonearth_models.size; i++ )
        {
            if ( isdefined( level.moonearth_models[i] ) )
                level.moonearth_models[i] delete();
        }
    }

    level.moonearth_models = [];
}
