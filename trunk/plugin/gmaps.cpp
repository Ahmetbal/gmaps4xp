#include "gmaps.h"
#include "download.h"


CURL    *curl_handle;


int fillTileInfo(struct  TileObj *tile, double lat, double lng, double alt){
	int	i, j;

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
	double	bounds[4]	= { 0.0, 0.0, 0.0, 0.0 };
	double	minx		= 0.0;
	double	miny		= 0.0;
	double	maxx		= 0.0;
	double	maxy		= 0.0;


	double	pntX		= 0.0;	
	double	pntZ		= 0.0;	
	double	stepMesh	= 0.0;	
	double	TILE_SIZE	= 0.0;
	double	MESH_SIZE	= 0.0;
	int	MESH_ZOOM[LAYER_NMBER + 1] = {
			1,	// 0
			1,	// 1
			1,	// 2
			1,	// 3
			1,	// 4
			1,	// 5
			1,	// 6
			1,	// 7
			32,	// 8
			32,	// 9
			16,	// 10
			16,	// 11
			8,	// 12
			8,	// 13
			8,	// 14
			4,	// 15
			4,	// 16
			4,	// 17
			4,	// 18
			2,	// 19
			1,	// 20
		};


	XPLMProbeInfo_t outInfo;
	outInfo.structSize = sizeof(outInfo);


	// If i use a negative altitude is directly the zoom level
	if ( zoom < 0 )	zoom = abs((int)alt);
	else		zoom = LAYER_NMBER - (int)( alt / 100 );
	if (zoom < 0 )	zoom = 0;



	c 		= zoom;
	tile->lat	= lat;
	tile->lng	= lng;
	tile->z		= zoom;
	tile->tileSize	= 256;
	tile->c		= 256;


	tile->pixelsPerLonDegree	= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->pixelsPerLonRadian	= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->numTiles			= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->bitmapOrigo[0]		= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));
	tile->bitmapOrigo[1]		= (double *)malloc( sizeof(double) * (LAYER_NMBER + 1));


	tile->bc = 2.0 * M_PI;
	tile->Wa = M_PI / 180.0;


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


	/*
	a = tile->x;
	b = tile->y;

	tile->lng = (a - tile->bitmapOrigo[0][c]) / tile->pixelsPerLonDegree[c];
	e	  = (b - tile->bitmapOrigo[1][c]) / (-1.0 * tile->pixelsPerLonRadian[c]);
	tile->lat = (2.0 * atan(exp(e)) - M_PI / 2.0) / tile->Wa;
	*/

	for( d = 0;  d < 1024; d++) url[d] = '\0';
	sprintf(url,"http://%s/kh/v=%d&x=%d&y=%d&z=%d&s=%s", GMapServers[GMapsServerIndex], (int)GMAPS_VERION, (int)tile->x, (int)tile->y, (int)tile->z, tile->Galileo);

	GMapsServerIndex++;
	if (GMapsServerIndex >= SERVERS_NUMBER ) GMapsServerIndex = 0;

	tile->url = (char *)malloc( sizeof(char) * ( strlen(url) + 1 ) );
	strcpy(tile->url, url);
	//---------------------------------------------//

	tile->Resolution	= 2.0 * M_PI * 6378137 / tile->tileSize / pow(2, zoom);
	tile->originShift	= 2.0 * M_PI * 6378137 / 2.0;


	minx	= (tile->x * tile->tileSize )		* tile->Resolution - tile->originShift;
	maxx	= ((tile->x+1.0) * tile->tileSize)	* tile->Resolution - tile->originShift;

	miny	= tile->originShift - (tile->y * tile->tileSize )	* tile->Resolution;
	maxy	= tile->originShift - ((tile->y+1.0) * tile->tileSize)	* tile->Resolution;


	tile->minLng = ( minx / tile->originShift ) * 180.0;
	tile->minLat = ( miny / tile->originShift ) * 180.0;
	tile->minLat = 180.0 / M_PI * (2.0 * atan( exp( tile->minLat * M_PI / 180.0)) - M_PI / 2.0);

	tile->maxLng = ( maxx / tile->originShift ) * 180.0;
	tile->maxLat = ( maxy / tile->originShift ) * 180.0;
	tile->maxLat = 180.0 / M_PI * (2.0 * atan( exp( tile->maxLat * M_PI / 180.0)) - M_PI / 2.0);

	XPLMWorldToLocal( tile->minLat, tile->minLng, 0.0, &(tile->X_LL), &(tile->Y_LL), &(tile->Z_LL) 	);
	XPLMWorldToLocal( tile->maxLat, tile->maxLng, 0.0, &(tile->X_UR), &(tile->Y_UR), &(tile->Z_UR) 	);


	tile->lng = (tile->maxLng + tile->minLng ) / 2.0;
	tile->lat = (tile->maxLat + tile->minLat ) / 2.0;


	//---------------------------------------------//


	TILE_SIZE		= ( tile->X_UR - tile->X_LL );
	MESH_SIZE		= MESH_ZOOM[(int)tile->z];
	tile->matrixSize	= MESH_SIZE + 1;
	stepMesh 		= TILE_SIZE / MESH_SIZE;

	tile->terX 		= (double **)malloc( tile->matrixSize * sizeof(double *) );
	tile->terY 		= (double **)malloc( tile->matrixSize * sizeof(double *) );
	tile->terZ 		= (double **)malloc( tile->matrixSize * sizeof(double *) );
	tile->TexCoordX 	= (double **)malloc( tile->matrixSize * sizeof(double *) );
	tile->TexCoordY		= (double **)malloc( tile->matrixSize * sizeof(double *) );

	for( i = 0; i < tile->matrixSize ; i++){
		tile->terX[i] 		= (double *)malloc( tile->matrixSize * sizeof(double) );
		tile->terY[i] 		= (double *)malloc( tile->matrixSize * sizeof(double) );
		tile->terZ[i] 		= (double *)malloc( tile->matrixSize * sizeof(double) );
		tile->TexCoordX[i] 	= (double *)malloc( tile->matrixSize * sizeof(double) );
		tile->TexCoordY[i]	= (double *)malloc( tile->matrixSize * sizeof(double) );

		for( j = 0 ; j < tile->matrixSize ; j++){
			pntX = tile->X_LL + ( i * stepMesh );
			pntZ = tile->Z_LL + ( j * stepMesh );

			XPLMProbeTerrainXYZ( inProbe, pntX, 0.0, pntZ, &outInfo);    
			tile->terX[i][j] 	= outInfo.locationX;
			tile->terY[i][j] 	= outInfo.locationY;
			tile->terZ[i][j] 	= outInfo.locationZ;
			tile->TexCoordX[i][j] 	=	(double)i / (double)(tile->matrixSize - 1);
			tile->TexCoordY[i][j] 	= 1.0f -(double)j / (double)(tile->matrixSize - 1);
		}
	}

	tile->matrixSize--;


	tile->next = NULL;
	tile->prev = NULL;



	return 0;
}

//---------------------------------------------------------------------------------------//


int fromXYZtoLatLon(double x, double y, double z, double *lat, double *lng){
	double minLng		= 0.0;
	double minLat		= 0.0;
	double maxLng		= 0.0;
	double maxLat		= 0.0;
	double minx		= 0.0;
	double miny		= 0.0;
	double maxx		= 0.0;
	double maxy		= 0.0;
	double Resolution 	= 0.0;
	double tileSize		= 256.0;
	double originShift	= 0.0;




	Resolution	= 2.0 * M_PI * 6378137 / tileSize / pow(2, z);
	originShift	= 2.0 * M_PI * 6378137 / 2.0;


	minx	= (x * tileSize)	* Resolution - originShift;
	maxx	= ((x+1.0) * tileSize)	* Resolution - originShift;

	miny	= originShift - (y * tileSize )		* Resolution;
	maxy	= originShift - ((y+1.0) * tileSize)	* Resolution;


	minLng = ( minx / originShift ) * 180.0;
	minLat = ( miny / originShift ) * 180.0;
	minLat = 180.0 / M_PI * (2.0 * atan( exp( minLat * M_PI / 180.0)) - M_PI / 2.0);

	maxLng = ( maxx / originShift ) * 180.0;
	maxLat = ( maxy / originShift ) * 180.0;
	maxLat = 180.0 / M_PI * (2.0 * atan( exp( maxLat * M_PI / 180.0)) - M_PI / 2.0);


	*lng = (maxLng + minLng ) / 2.0;
	*lat = (maxLat + minLat ) / 2.0;

	printf("%f %f\n", minLat, maxLat);


	return 0;
}



//---------------------------------------------------------------------------------------//

int destroyTile(struct  TileObj *tile){
	int i;

	// Free coordinates for openGL
	for( i = 0; i < tile->matrixSize+1 ; i++){
		free(tile->terX[i]);		free(tile->terY[i]);		free(tile->terZ[i]);
		free(tile->TexCoordX[i]);	free(tile->TexCoordY[i]);
	}

	free(tile->terX);	free(tile->terY);	free(tile->terZ);
	free(tile->TexCoordX);	free(tile->TexCoordY);

	// Free values calculate for tile url
	free(tile->pixelsPerLonDegree);
	free(tile->pixelsPerLonRadian);
	free(tile->numTiles);
	free(tile->bitmapOrigo[0]);	free(tile->bitmapOrigo[1]);
	free(tile->Galileo);
	free(tile->url);

	// Remove allocate structure.
	free(tile);
	tile = NULL;
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

//---------------------------------------------------------------------------------------//

PLUGIN_API int XPluginStart( char *outName, char *outSig, char *outDesc ){
	int i;

	// Plugin description
	strcpy(outName, "GMaps For X-Plane");
	strcpy(outSig,  "Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/GMaps/");


	// Console windows creation
	gConsole = XPLMCreateWindow(
			50, 600, 600, 200,               
			1,                               
			GMapsDrawWindowCallback, GMapsHandleKeyCallback, GMapsHandleMouseClickCallback,
			NULL);    


	// Register function to draw 3d obj
        XPLMRegisterDrawCallback(
			GMapsDrawCallback, 
			xplm_Phase_Objects, 
			0, NULL);                       


	
	XPLMRegisterFlightLoopCallback(		
			GMapsMainFunction,	
			1.0,
			NULL);
			
	
	XPLMRegisterKeySniffer( GMapsKeySniffer, 1, 0);

	gPlaneX 	= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY 	= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ 	= XPLMFindDataRef("sim/flightmodel/position/local_z");

	gPlaneHeading	= XPLMFindDataRef("sim/flightmodel/position/psi");
	gPlaneLat	= XPLMFindDataRef("sim/flightmodel/position/latitude");
	gPlaneLon	= XPLMFindDataRef("sim/flightmodel/position/longitude");
	gPlaneAlt	= XPLMFindDataRef("sim/flightmodel/position/elevation");	
	inProbe         = XPLMCreateProbe(xplm_ProbeY);  


	// Create directory cache
	mkdir(CACHE_DIR,  S_IRWXU);

	curl_global_init(CURL_GLOBAL_ALL);
	curl_handle = curl_easy_init();
	initCurlHandle(curl_handle);

	return 1;
}

//---------------------------------------------------------------------------------------//


int GMapsKeySniffer( char inChar, XPLMKeyFlags inFlags, char inVirtualKey, void *inRefcon ){
	gVirtualKey	= inVirtualKey;
	gFlags		= inFlags;
	gChar		= inChar;

	return 1;
}


//---------------------------------------------------------------------------------------//


void GMapsDrawWindowCallback( XPLMWindowID inWindowID, void *inRefcon){
        int     left, top, right, bottom;
        float   color[] = { 1.0, 1.0, 1.0 };   
	struct  consoleBuffer *cursor= NULL;
	int	i;

        XPLMGetWindowGeometry(inWindowID, &left, &top, &right, &bottom);
        XPLMDrawTranslucentDarkBox(left, top, right, bottom);
	// Message drow in debug windows
	if ( consoleOutput == NULL ) return;
	for ( cursor = consoleOutput, i = 0; cursor != NULL; cursor = cursor->next, i++){
		if (cursor->line ==  NULL ) continue;
	        XPLMDrawString(color, left + 5, ( bottom + 10 ) + ( i * 10) , cursor->line, NULL, xplmFont_Basic);
	}

}


//---------------------------------------------------------------------------------------//

int  GMapsDrawCallback( XPLMDrawingPhase inPhase, int inIsBefore, void *inRefcon){
	int	i, j;
	GLuint  texId;
	struct	TileObj *tile;

	if ( TileList == NULL ) return 1; // Nothing to draw

	
	XPLMSetGraphicsState(
			1, 	// inEnableFog,    
			1, 	// inNumberTexUnits,    
			1, 	// inEnableLighting,    
			1, 	// inEnableAlphaTesting,    
			1, 	// inEnableAlphaBlending,    
			0, 	// inEnableDepthTesting,    
			1);  	// inEnableDepthWriting


		    

	for( tile = TileList; tile != NULL; tile = tile->next){

		//glEnable(GL_TEXTURE_2D);
		//glBindTexture(GL_TEXTURE_2D, texId);
		glBegin(GL_TRIANGLES);
		for( i = 0 ; i < tile->matrixSize; i++){
			for( j = 0 ; j < tile->matrixSize; j++){


                              	// First triangle               
                                glColor3f(1.0, 0.0, 0.0);
                                //glTexCoord2f(	tile->TexCoordX[i][j], 		tile->TexCoordY[i][j]);
                                glVertex3f(	tile->terX[i][j],		tile->terY[i][j],	tile->terZ[i][j]);
                        
                                //glTexCoord2f(	tile->TexCoordX[i+1][j], 	tile->TexCoordY[i+1][j]);
                                glVertex3f(	tile->terX[i+1][j],		tile->terY[i+1][j],	tile->terZ[i+1][j]);

                                //glTexCoord2f(	tile->TexCoordX[i][j+1], 	tile->TexCoordY[i][j+1]);
                                glVertex3f(	tile->terX[i][j+1],		tile->terY[i][j+1],	tile->terZ[i][j+1]);

                        
                                // Second triangle
                                glColor3f(0.0, 1.0, 1.0);
                                //glTexCoord2f(	tile->TexCoordX[i+1][j+1], 	tile->TexCoordY[i+1][j+1]);
                                glVertex3f(	tile->terX[i+1][j+1],		tile->terY[i+1][j+1],	tile->terZ[i+1][j+1]);

                                //glTexCoord2f(	tile->TexCoordXi][j+1], 	tile->TexCoordYi][j+1]);
                                glVertex3f(	tile->terX[i][j+1],		tile->terY[i][j+1],	tile->terZ[i][j+1]);

                                //glTexCoord2f(	tile->TexCoordX[i+1][j], 	tile->TexCoordY[i+1][j]);
                                glVertex3f(	tile->terX[i+1][j],		tile->terY[i+1][j],	tile->terZ[i+1][j]);
	
			}
		}
		glEnd();
		//glDisable(GL_TEXTURE_2D);
	
	}
	return 1;
}

//---------------------------------------------------------------------------------------//

float GMapsMainFunction( float inElapsedSinceLastCall, float inElapsedTimeSinceLastFlightLoop, int inCounter, void *inRefcon){
	struct	TileObj *tile, *p;
	XPLMProbeInfo_t outInfo;  

	double 	planeX,		planeY, 	planeZ;
	double	outLatitude,	outLongitude,	outAltitude;
	double	terLatitude,	terLongitude,	terAltitude;
	double	Heading,	Altitude;
	double	x,		y;


	int		i;
	int		size	= 0;
	unsigned char	*image	= NULL;
	char		fileout[255];
	char		tmp[255];
	FILE		*file;


	/* If any data refs are missing, do not draw. */
	if (!gPlaneX || !gPlaneY || !gPlaneZ)	return 1.0;
	
	
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


	tile = (struct  TileObj *)malloc(sizeof(struct  TileObj));
	fillTileInfo(tile, outLatitude, outLongitude, Altitude );


	if ( ( currentPosition[0] == tile->x ) && ( currentPosition[1] == tile->y ) && ( currentPosition[2] == tile->z ) ) { destroyTile(tile); return 1.0; }

	currentPosition[0] = tile->x;
	currentPosition[1] = tile->y;
	currentPosition[2] = tile->z;

	double m	= 0.0;
	double alpha	= 0.0;
	double xstart	= 0.0;
	double ystart	= 0.0;

	if	( Heading <= 90.0  )	alpha = ( 90.0	  - Heading	);		
	else if ( Heading <= 270.0 )	alpha = ( Heading - 90.0 	) * -1.0;
	else				alpha = ( 450.0	  - Heading	);

	m 	= tan( alpha *  M_PI /  180.0 );
	xstart	= tile->x;
	ystart 	= tile->y;

        if ( TileList != NULL ){
                for(p = TileList, i = 0; p->next != NULL; p = p->next) { i++; };
                p->next = tile;
        }else{
                TileList = tile;
        }

	for ( x = 1.0 ; x < 10.0 ; x += 1.0 ){
		y = floor( m * x );

		fromXYZtoLatLon( x+xstart, y+ystart, tile->z, &outLatitude, &outLongitude );
		p = (struct  TileObj *)malloc(sizeof(struct  TileObj));
		fillTileInfo( p, outLatitude, outLongitude, Altitude );


		sprintf(tmp, "X: %f Y: %f z: %f Lat: %f Lon: %f\n", p->x, p->y, p->z, p->lat, p->lng);
		writeConsole(tmp);

		tile->next = p;
		tile = tile->next;
	}




	return 1.0;

	if ( ( size = downloadItem(curl_handle, tile->url, &image)) == 0 ){
		fprintf(stderr, "Error: download problem\n");
		return 1;
	}

	sprintf(fileout, "%s/tile-%d-%d-%d.jpg",  CACHE_DIR, (int)tile->x, (int)tile->y, (int)tile->z);
	printf("%s\n", fileout);

	file = fopen(fileout, "w"); 
	if(file == NULL) {
		fprintf(stderr, "Error: can't create file.\n");
		return 1;
	}
	fwrite(image, 1, size, file);	
	fclose(file);


	return 1.0;
}



/*
	curl_slist_free_all(cookie);  
	curl_slist_free_all(cursor);  
	curl_easy_cleanup(curl_handle);
	curl_global_cleanup();

	return 0;
}


*/








int	GMapsHandleMouseClickCallback( XPLMWindowID inWindowID, int x, int y, XPLMMouseStatus inMouse, void *inRefcon){  return 1; }
void    GMapsHandleKeyCallback( XPLMWindowID inWindowID, char inKey, XPLMKeyFlags inFlags, char inVirtualKey,  void *inRefcon, int  losingFocus){}




PLUGIN_API void	XPluginStop(void)	{  XPLMDestroyWindow(gConsole); }
PLUGIN_API void	XPluginDisable(void)	{}
PLUGIN_API int	XPluginEnable(void)	{ return 1; }
PLUGIN_API void XPluginReceiveMessage( XPLMPluginID inFromWho, long inMessage,  void *inParam){}



