#include "gmaps.h"
#include "download.h"
#include "loadjpeg.h"

CURL    *curl_handle;

double distAprox(double lat1, double lon1, double lat2, double lon2) {
        double  R       = 6372.795477598;
        double  dLat    = 0.0;
        double  dLon    = 0.0;
        double  a       = 0.0;
        double  c       = 0.0;

        dLat = (lat2-lat1) * ( M_PI / 180.0 );
        dLon = (lon2-lon1) * ( M_PI / 180.0 );

        a       = sin(dLat/2.0) * sin(dLat/2.0) + cos(lat1 * ( M_PI / 180.0 )) * cos(lat2 * ( M_PI / 180.0 )) * sin(dLon/2.0) * sin(dLon/2.0);
        c       = 2.0 * atan2(sqrt(a), sqrt(1-a));

        return( R * c  * 1000.0);
}



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
	tile->alt	= alt;
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
			tile->terZ[i][j] 	= outInfo.locationZ;// + 0.01;
			tile->TexCoordX[i][j] 	= 	(double)i / (double)(tile->matrixSize - 1);
			tile->TexCoordY[i][j] 	= 	(double)j / (double)(tile->matrixSize - 1);

		}
	}

	tile->matrixSize--;

	tile->texture	= NULL;
	tile->loaded	= NOLOADED;
	tile->next	= NULL;
	tile->prev	= NULL;



	return 0;
}

//---------------------------------------------------------------------------------------//


int divedeCircle(double start, int parts, double view, double *steps){
	int i, k;
	double token	= 0.0;
	if (( parts % 2 ) != 1 ) return 1;

	token =  view / parts;
	for ( i = ( parts / 2 ) * -1, k = 0; i < ( parts / 2  ) + 1; i++, k++){

		steps[k] = start + (token * (double)i);
		if ( steps[k] > 180 )  steps[k] -= 360.0;
		if ( steps[k] < -180 ) steps[k] += 360.0;


	}

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


	return 0;
}

//---------------------------------------------------------------------------------------//

int addTextureToTile(struct  TileObj *tile, unsigned char *image, FILE *fp, int size){
	if (image != NULL){	
		if ( loadJpeg(image, 	NULL, 	size,	&tile->texture, &tile->imageWidth, &tile->imageHeight) ){
			fprintf(stderr, "Error: loadJpeg from Ram\n");
			return 1;
		}
	}else{
		if ( loadJpeg(NULL, 	fp, 	0, 	&tile->texture, &tile->imageWidth, &tile->imageHeight) ){
			fprintf(stderr, "Error: loadJpeg from File\n");
			return 1;
		}
	}

        // Image is ready, wating loading
        tile->loaded = WAIT; 
	
	return 0;
}


//---------------------------------------------------------------------------------------//



int destroyTile(struct  TileObj *tile){
	if (tile == NULL) return 0;

	// Free coordinates for openGL
	free(tile->terX);	free(tile->terY);	free(tile->terZ);
	free(tile->TexCoordX);	free(tile->TexCoordY);

	// Free values calculate for tile url
	free(tile->pixelsPerLonDegree);
	free(tile->pixelsPerLonRadian);
	free(tile->numTiles);
	free(tile->bitmapOrigo[0]);	free(tile->bitmapOrigo[1]);
	free(tile->Galileo);
	free(tile->url);

	
	if ( tile->loaded == LOADED )	glDeleteTextures(1,&tile->texId);
	if ( tile->texture != NULL  ) 	free(tile->texture);

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

	// Init curl handler
	curl_global_init(CURL_GLOBAL_ALL);
	curl_handle = curl_easy_init();
	initCurlHandle(curl_handle);

	// init threads
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	pthread_mutex_init(&mutex, NULL);

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
	struct	TileObj *tile;

	
	return 1;
	if ( TileList == NULL ) return 1; // Nothing to draw

	
	XPLMSetGraphicsState(
			ENABLE, 	// inEnableFog,    
			DISABLE,	// inNumberTexUnits,    
			ENABLE, 	// inEnableLighting,    
			ENABLE, 	// inEnableAlphaTesting,    
			ENABLE, 	// inEnableAlphaBlending,    
			DISABLE, 	// inEnableDepthTesting,    
			ENABLE);  	// inEnableDepthWriting


	pthread_mutex_lock(&mutex);
	for( tile = TileList; tile != NULL; tile = tile->next){
		// Skip tile is image is not ready
		if ( tile->loaded == NOLOADED ) continue;

		// Load tile if needed
		if ( tile->loaded == WAIT ){
			glGenTextures(1, &tile->texId );
			glBindTexture(GL_TEXTURE_2D, tile->texId);
		 	gluBuild2DMipmaps( GL_TEXTURE_2D, 3, tile->imageWidth, tile->imageHeight, GL_RGB, GL_UNSIGNED_BYTE, tile->texture );
			tile->loaded = LOADED;
		}


		glEnable(GL_TEXTURE_2D);
		glBindTexture(GL_TEXTURE_2D, tile->texId);
		glBegin(GL_TRIANGLES);
		for( i = 0 ; i < tile->matrixSize; i++){
			for( j = 0 ; j < tile->matrixSize; j++){


                              	// First triangle               
                                //glColor3f(1.0, 0.0, 0.0);
                                glTexCoord2f(	tile->TexCoordX[i][j], 		tile->TexCoordY[i][j]);
                                glVertex3f(	tile->terX[i][j],		tile->terY[i][j],	tile->terZ[i][j]);
                        
                                glTexCoord2f(	tile->TexCoordX[i+1][j], 	tile->TexCoordY[i+1][j]);
                                glVertex3f(	tile->terX[i+1][j],		tile->terY[i+1][j],	tile->terZ[i+1][j]);

                                glTexCoord2f(	tile->TexCoordX[i][j+1], 	tile->TexCoordY[i][j+1]);
                                glVertex3f(	tile->terX[i][j+1],		tile->terY[i][j+1],	tile->terZ[i][j+1]);

                        
                                // Second triangle
                                //glColor3f(0.0, 1.0, 1.0);
                                glTexCoord2f(	tile->TexCoordX[i+1][j+1], 	tile->TexCoordY[i+1][j+1]);
                                glVertex3f(	tile->terX[i+1][j+1],		tile->terY[i+1][j+1],	tile->terZ[i+1][j+1]);

                                glTexCoord2f(	tile->TexCoordX[i][j+1], 	tile->TexCoordY[i][j+1]);
                                glVertex3f(	tile->terX[i][j+1],		tile->terY[i][j+1],	tile->terZ[i][j+1]);

                                glTexCoord2f(	tile->TexCoordX[i+1][j], 	tile->TexCoordY[i+1][j]);
                                glVertex3f(	tile->terX[i+1][j],		tile->terY[i+1][j],	tile->terZ[i+1][j]);
	
			}
		}
		glEnd();
		glDisable(GL_TEXTURE_2D);
	
	}
	pthread_mutex_unlock(&mutex);

	return 1;
}

//---------------------------------------------------------------------------------------//

void *LoadTile( void *ptr ){

	struct thread_data	*data;
	struct TileObj		*tile, *p;
	char			fileout[1024];
	FILE			*file		= NULL;
	int			size		= 0;
	unsigned char		*image		= NULL;
	CURL 			*handle		= NULL;


	data = (struct thread_data *)ptr;
	tile = data->tile;


	sprintf(fileout, "%s/tile-%d-%d-%d.jpg",  CACHE_DIR, (int)tile->x, (int)tile->y, (int)tile->z);

	file = fopen(fileout, "rb"); 
	if(file == NULL) {
		if ( ( handle = curl_easy_duphandle(curl_handle) ) == NULL ){
			fprintf(stderr, "Error: Unable to copy handle for %s\n", tile->url);
			pthread_exit(NULL);
		}

		if ( ( size = downloadItem(handle, tile->url, &image)) == 0 ){
			fprintf(stderr, "Error: download problem %s\n", tile->url);
			pthread_exit(NULL);
		}
		file = fopen(fileout, "wb"); 
		if(file == NULL) {
			fprintf(stderr, "Error: can't create file %s\n", fileout);
			pthread_exit(NULL);
		}
		fwrite(image, 1, size, file);	
		addTextureToTile(tile,	image,	NULL,	size);
		fclose(file);
	}else{
		addTextureToTile(tile,	NULL,	file,	0);
		fclose(file);
	}

	
	pthread_mutex_lock(&mutex);
	if ( TileList == NULL ) TileList = tile; 
	else {
		for (p = TileList; p->next != NULL; p = p->next);
		p->next		= tile;
		tile->prev	= p;
		
	}
	pthread_mutex_unlock(&mutex);
	
	pthread_exit(NULL);
}

//---------------------------------------------------------------------------------------//

int frameCreator(struct  TileObj *tile, int level){
	int	i		= 0;
	int	rc		= 0;
	double 	x, y;
	double	x_start		= 0.0;
	double	y_start		= 0.0;
	double	x_end		= 0.0;
	double	y_end		= 0.0;
	double	lat		= 0.0;
	double	lng		= 0.0;
	double	*x_frame	= NULL;
	double	*y_frame	= NULL;
	int	*frame		= NULL;
	int	frame_lenght 	= 0;


	struct TileObj *p, *q;


	frame_lenght	= ( level != 0 ) ? (level * 8) : 1;
	x_frame		= (double *)	malloc( frame_lenght * sizeof(double)	);
	y_frame		= (double *)	malloc( frame_lenght * sizeof(double)	);
	frame		= (int *)	malloc( frame_lenght * sizeof(int)	);


	// Create a frame of tile around the plane
	// 
	//	x	x	x
	//
	//	x	T	x
	//
	//	x	x	x

	if ( frame_lenght > 1 ){
		x_start		= tile->x - (double)level;
		y_start		= tile->y - (double)level;
		x_end		= tile->x + (double)level + 1.0;
		y_end		= tile->y + (double)level;

		for (x = x_start;	x < x_end; 	x+= 1.0, i++){
			x_frame[i]	= x;
			y_frame[i]	= y_start;
			frame[i]	= TRUE;	

		}

		for (y = y_start + 1.0; y < y_end; 	y+= 1.0, i++){
			x_frame[i]	= x_start;
			y_frame[i]	= y;
			frame[i]	= TRUE;

			i++;

			x_frame[i]	= x_end - 1;
			y_frame[i]	= y;
			frame[i]	= TRUE;
		}

		for (x = x_start; 	x < x_end;	x+= 1.0, i++){
			x_frame[i]	= x;
			y_frame[i]	= y_end;
			frame[i]	= TRUE;
		}
	}else{
		x_frame[i]	= tile->x;
		y_frame[i]	= tile->y;
		frame[i]	= TRUE;

	}


	// Remove from the list of loaded tile not used 
		
        pthread_mutex_lock(&mutex);
	if ( TileList != NULL ){
		printf("Start Cleanning...\n");
		for( p = TileList; p != NULL; p = ( p != NULL ) ? p->next : NULL ){

			// Search tile in the frame
			for ( i = 0; i < frame_lenght; i++) if ( ( p->x == x_frame[i] ) && ( p->y == y_frame[i] ) ){ frame[i] = FALSE; break; }


			// tile not found in the frame, so I have to remove it
			if ( i == frame_lenght ){	

				q = p;
				if ( ( p->prev == NULL ) && ( p->next == NULL ) )	printf("One tile\n");
				if ( ( p->prev == NULL ) && ( p->next != NULL ) )	printf("Head tile\n");
				if ( ( p->prev != NULL ) && ( p->next == NULL ) )	printf("Tail tile\n");
				if ( ( p->prev != NULL ) && ( p->next != NULL ) )	printf("Center tile\n");


				if ( p->prev == NULL ){		// Remove from head

					printf("Remove from head...\n");
					TileList = ( p->next != NULL ) ? p->next : NULL;
					
					if ( TileList != NULL )	TileList->prev	= NULL;

				}else if ( p->next == NULL ){ 	// Remove from tail

					printf("Remove from tail...\n");
					p	= p->prev;
					p->next	= NULL;

				} else { 			// Remove from center

					printf("Remove from center...\n");
					p->prev->next = p->next;
					p->next->prev = p->prev; 

				}
				destroyTile(q);
			}

		} 
		printf("End Cleanning...\n");
	}
        pthread_mutex_unlock(&mutex);
	

	// load image...

	printf("Start Image request...\n");
	for (i = 0; i < frame_lenght; i++){
		if ( frame[i] != TRUE ) continue;

		fromXYZtoLatLon(x_frame[i], y_frame[i], tile->z, &lat, &lng);

		p = NULL;
		p = (struct  TileObj *)malloc(sizeof(struct  TileObj));
		fillTileInfo(p, lat, lng, tile->alt );

		thread_data_array[thread_index].tile		= p;
		thread_data_array[thread_index].thread_id	= thread_index;

		// multithread
		if ( ( rc = pthread_create( &thread_id[thread_index], &attr, LoadTile, (void *)&thread_data_array[thread_index]) ) ){
			fprintf(stderr, "Error: return code from pthread_create() is %d\n", rc);
			break;			
      		}
		thread_index = (thread_index + 1 ) % MAX_THREAD_NUMBER;

	}

	printf("End Image request...\n");


	return 0;
}

//---------------------------------------------------------------------------------------//



float GMapsMainFunction( float inElapsedSinceLastCall, float inElapsedTimeSinceLastFlightLoop, int inCounter, void *inRefcon){
	XPLMProbeInfo_t outInfo;  

	double 	planeX,		planeY, 	planeZ;
	double	outLatitude,	outLongitude,	outAltitude;
	double	terLatitude,	terLongitude,	terAltitude;
	double	Heading,	Altitude;


	struct  TileObj *tile = NULL;

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

	//frameCreator(tile, 0);
	frameCreator(tile, 2);

	destroyTile(tile);
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



