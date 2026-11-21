// Fr0sty - DLC5 additions. Written by Fr0sty; please credit Fr0sty if you reuse or reupload any of this.
main()
{
}

// Kino Grief team revive icons. Kino's client never runs the grief gametype precache hook,
// so clientscripts/mp/gametypes/zgrief.csc never gets to call setteamreviveicon; do it here.
init()
{
	if ( getdvar( "mapname" ) != "zm_theater" )
		return;

	gt = getdvar( "ui_gametype" );

	// Grief only: Turned keeps the stock CDC / CIA look.
	if ( gt != "zgrief" )
	{
		println( "KINOREVIVE >> csc: gametype '" + gt + "', not grief - stock revive icon" );
		return;
	}

	level thread kinoreviveicon_apply();
}

kinoreviveicon_apply()
{
	// Re-apply for a while in case a later stock script resets the team icons.
	for ( i = 0; i < 30; i++ )
	{
		setteamreviveicon( "allies", "waypoint_revive_mp" );
		setteamreviveicon( "axis", "waypoint_revive_spetsnaz" );

		if ( i == 0 )
			println( "KINOREVIVE >> csc: allies=waypoint_revive_mp axis=waypoint_revive_spetsnaz" );

		wait 1;
	}

	println( "KINOREVIVE >> csc: re-apply window closed" );
}
