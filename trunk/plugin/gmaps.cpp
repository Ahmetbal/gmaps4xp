#include "gmaps.h"



int fillTileInfo(struct  TileObj *tile, double lat, double lng, double alt){


	double	x = 0.0;
	double	y = 0.0;

	double	a 		= lat;
	double	b 		= lng;
	int	c		= 0;
	int	d 		= 0;
	double	e 		= 0.0;
	int	zoom		= 0;
	char	Galileo[8]	= "Galileo";
	int	iGal		= 0;
	char	url[1024]	= {};
	int	LAYER_NMBER	= 20; //18

	zoom	= LAYER_NMBER - (int)( alt / 100 );
	if (zoom < 0 ) zoom = 0;

	c 		= zoom;
	tile->lat	= lat;
	tile->lng	= lng;
	tile->z		= zoom;
	tile->PI	= M_PI;
	tile->tileSize	= 256;
	tile->c		= 256;


	tile->pixelsPerLonDegree	= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->pixelsPerLonRadian	= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->numTiles			= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->bitmapOrigo[0]		= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->bitmapOrigo[1]		= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));


	tile->bc = 2.0 * tile->PI;
	tile->Wa = tile->PI / 180.0;


	//for( d = LAYER_NMBER;  d >= 0; --d) {
	for( d = 0;  d < (LAYER_NMBER + 1); d++) {
		e = tile->c / 2.0;
		tile->pixelsPerLonDegree[d]	= tile->c / 360.0;
		tile->pixelsPerLonRadian[d]	= tile->c / tile->bc;
		tile->bitmapOrigo[0][d]		= e;
		tile->bitmapOrigo[1][d]		= e;
		tile->numTiles[d]		= tile->c / 256.0;
		tile->c *= 2.0;	

	}

	x = floor( tile->bitmapOrigo[0][c] + b * tile->pixelsPerLonDegree[c] );
	e = sin(a * tile->Wa);

	if(e > 0.9999)	e = 0.9999;
  	if(e < -0.9999)	e = -0.9999;
  		
	y = floor( tile->bitmapOrigo[1][c] + 0.5 * log((1.0 + e) / (1.0 - e)) * -1.0 * (tile->pixelsPerLonRadian[c]) );

	tile->x = floor( x / tile->tileSize);
	tile->y = floor( y / tile->tileSize);



	iGal		= ( ( (int)tile->x * 3 + (int)tile->y ) % 8 );
	if ( iGal >= 8 ) iGal = 7;
	Galileo[iGal]	= '\0';
	tile->Galileo	= (char *)malloc( sizeof(char) *  iGal + 1 );
	sprintf(tile->Galileo, "%s", Galileo);


	a = tile->x;
	b = tile->y;

	tile->lng = (a - tile->bitmapOrigo[0][c]) / tile->pixelsPerLonDegree[c];
	e	  = (b - tile->bitmapOrigo[1][c]) / (-1.0 * tile->pixelsPerLonRadian[c]);
	tile->lat = (2.0 * atan(exp(e)) - tile->PI / 2.0) / tile->Wa;


	// http://khm1.google.com/kh/v=58&x=557121&y=379081&z=20&s=Gali
	for( d = 0;  d < 1024; d++) url[d] = '\0';
	sprintf(url,"http://%s/kh/v=%d&x=%d&y=%d&z=%d&s=%s", GMapServers[GMapsServerIndex], (int)GMAPS_VERION, (int)tile->x, (int)tile->y, (int)tile->z, tile->Galileo);

	GMapsServerIndex++;
	if (GMapsServerIndex >= SERVERS_NUMBER ) GMapsServerIndex = 0;

	tile->url = (char *)malloc( sizeof(char) * ( strlen(url) + 1 ) );
	strcpy(tile->url, url);



	return 0;
}


//---------------------------------------------------------------------------------------//
int writeConsole(const char *msg){
	struct  consoleBuffer *cursor = NULL;
	int	i;

	if ( msg == NULL ) return 1;
	if ( consoleOutput == NULL ){
		consoleOutput		= (struct  consoleBuffer *)malloc( sizeof(struct  consoleBuffer));
		consoleOutput->line	= (char *)malloc(sizeof(char) * (strlen(msg) + 1 ));
		consoleOutput->next	= NULL;
		strcpy(consoleOutput->line, msg);
		return 0;
	}

	for ( cursor = consoleOutput, i = 0; cursor->next != NULL; cursor = cursor->next){ i++; };
	

	cursor->next	= (struct  consoleBuffer *)malloc( sizeof(struct  consoleBuffer));
	cursor 		= cursor->next;
	cursor->line	= (char *)malloc(sizeof(char) * (strlen(msg) + 1 ));
	cursor->next	= NULL;
	strcpy(cursor->line, msg);


	if ( i > BUFFER_CONSOL_LIN ){
		cursor		= consoleOutput;
		consoleOutput	= consoleOutput->next;
		free(cursor);
	}

	return 0;
}


PLUGIN_API int XPluginStart( char *outName, char *outSig, char *outDesc ){
	int i;

	strcpy(outName, "GMaps For X-Plane");
	strcpy(outSig,  "Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/GMaps/");


	gConsole = XPLMCreateWindow(
			50, 600, 600, 200,               
			1,                               
			GMapsDrawWindowCallback, GMapsHandleKeyCallback, GMapsHandleMouseClickCallback,
			NULL);    


	XPLMRegisterKeySniffer( GMapsKeySniffer, 1, 0);

	gPlaneX 	= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY 	= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ 	= XPLMFindDataRef("sim/flightmodel/position/local_z");

	gPlaneHeading	= XPLMFindDataRef("sim/flightmodel/position/psi");
	gPlaneLat	= XPLMFindDataRef("sim/flightmodel/position/latitude");
	gPlaneLon	= XPLMFindDataRef("sim/flightmodel/position/longitude");
	gPlaneAlt	= XPLMFindDataRef("sim/flightmodel/position/elevation");	
	inProbe 	= XPLMCreateProbe(xplm_ProbeY);	

	return 1;
}



int GMapsKeySniffer( char inChar, XPLMKeyFlags inFlags, char inVirtualKey, void *inRefcon ){
	gVirtualKey	= inVirtualKey;
	gFlags		= inFlags;
	gChar		= inChar;

	return 1;
}

void GMapsDrawWindowCallback( XPLMWindowID inWindowID, void *inRefcon){
        int     left, top, right, bottom;
        float   color[] = { 1.0, 1.0, 1.0 };   
	struct  consoleBuffer *cursor= NULL;
	int	i;
	struct	TileObj tile;
	XPLMProbeInfo_t outInfo;  

	double 	planeX,		planeY, 	planeZ;
	double	outLatitude,	outLongitude,	outAltitude;
	double	terLatitude,	terLongitude,	terAltitude;
	double	Heading,	Altitude;


	char	tmp[1024] = {};


        XPLMGetWindowGeometry(inWindowID, &left, &top, &right, &bottom);
        XPLMDrawTranslucentDarkBox(left, top, right, bottom);

	/* If any data refs are missing, do not draw. */
	if (!gPlaneX || !gPlaneY || !gPlaneZ)	return;
		
	/* Fetch the plane's location at this instant in OGL coordinates. */	
	planeX 		= XPLMGetDataf(gPlaneX);
	planeY 		= XPLMGetDataf(gPlaneY);
	planeZ 		= XPLMGetDataf(gPlaneZ);
	outLatitude	= XPLMGetDataf(gPlaneLat);
	outLongitude	= XPLMGetDataf(gPlaneLon);
	outAltitude	= XPLMGetDataf(gPlaneAlt);
	Heading		= XPLMGetDataf(gPlaneHeading);

	outInfo.structSize = sizeof(outInfo);
	XPLMProbeTerrainXYZ( inProbe, planeX, planeY, planeZ, &outInfo);
	XPLMLocalToWorld(outInfo.locationX, outInfo.locationY, outInfo.locationZ, &terLatitude, &terLongitude, &terAltitude);

	Altitude = (int)(outAltitude - terAltitude );



	fillTileInfo(&tile, outLatitude, outLongitude,  Altitude );


	sprintf(tmp, "%s\n",  tile.url);
	writeConsole(tmp);

	// Message drow in debug windows
	if ( consoleOutput == NULL ) return;
	for ( cursor = consoleOutput, i = 0; cursor != NULL; cursor = cursor->next, i++){
		if (cursor->line ==  NULL ) continue;
	        XPLMDrawString(color, left + 5, ( bottom + 10 ) + ( i * 10) , cursor->line, NULL, xplmFont_Basic);
	}

}



int	GMapsHandleMouseClickCallback( XPLMWindowID inWindowID, int x, int y, XPLMMouseStatus inMouse, void *inRefcon){  return 1; }
void    GMapsHandleKeyCallback( XPLMWindowID inWindowID, char inKey, XPLMKeyFlags inFlags, char inVirtualKey,  void *inRefcon, int  losingFocus){}




PLUGIN_API void	XPluginStop(void)	{  XPLMDestroyWindow(gConsole); }
PLUGIN_API void	XPluginDisable(void)	{}
PLUGIN_API int	XPluginEnable(void)	{ return 1; }
PLUGIN_API void XPluginReceiveMessage( XPLMPluginID inFromWho, long inMessage,  void *inParam){}



