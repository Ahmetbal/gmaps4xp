#if LIN
#include <GL/gl.h>
#include <GL/glu.h>
#else
#if __GNUC__
#include <OpenGL/gl.h>
#include <OpenGL/glu.h>
#else
#include <gl.h>
#endif
#endif


// Generic include
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pthread.h>

// Libreary include
#include <jpeglib.h>
#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>

// SDK include
#include "XPLMDisplay.h"
#include "XPLMDataAccess.h"
#include "XPLMGraphics.h"
#include "XPLMScenery.h"
#include "XPLMMenus.h"
#include "XPWidgets.h"
#include "XPStandardWidgets.h"


#define	CACHE_DIR 	"./GMapsCache"
#define GRID_SIZE	4


#define READY		0
#define LOADED		1
#define BUSY		2
#define FOUND		3
#define NOT_FOUND 	4


//#define USER_AGENT	"Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; it; rv:1.9.1.3) Gecko/20090824 Firefox/3.5.3 GTB"

#define HEADER_USER_AGENT	"User-Agent: Mozilla/5.0 (X11; U; Linux i686; it-IT; rv:1.9.0.14) Gecko/2009090216 Ubuntu/9.04 (jaunty) Firefox/3.0.14 GTB5"
#define HEADER_ACCEPT		"Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
#define HEADER_ACCEPT_LANGUAGE	"Accept-Language: it-IT,it;q=0.7,chrome://global/locale/intl.properties;q=0.3"		
#define HEADER_ACCEPT_ENCODING	"Accept-Encoding: gzip,deflate"
#define HEADER_ACCEPT_CHARSET	"ISO-8859-1,utf-8;q=0.7,*;q=0.7"
#define HEADER_KEEP_ALIVE	"Keep-Alive: 300"
#define HEADER_CONNECTION	"Connection: keep-alive"



// Define support structure
struct gl_texture_t{
	GLsizei	width;
	GLsizei height;

	GLenum	format;
	GLint	internalFormat;
	GLuint	id;

	GLubyte *texels;
};

struct MemoryStruct {
	char *memory;
	size_t size;
};

struct thread_data{
	int  	thread_id;
	char	*quad;
};


struct displayTile{
	char 	*quad;
	GLuint	texId;
	int	used;
	int	status;
	struct	displayTile *next;

} displayTile;


// Global variables dichiaration
XPLMDataRef		gPlaneX;
XPLMDataRef		gPlaneY;
XPLMDataRef		gPlaneZ;
XPLMProbeRef		inProbe;
XPWidgetID 		GMapsWidget = NULL;


CURL 			*curl;
CURLcode 		res;
struct MemoryStruct 	chunk;
struct displayTile	*listTile = NULL;

pthread_mutex_t 	mut = PTHREAD_MUTEX_INITIALIZER;
struct thread_data 	*thread_data_array;
pthread_t 		*threads;
struct curl_slist 	*headers = NULL;


char 	servers[4][16] 	= { "khm0.google.com", "khm1.google.com", "khm2.google.com", "khm3.google.com" };
int	server_index	= 0;	

// Function prototype
static struct gl_texture_t 	*ReadJPEGFromFile (const char *filename);
GLuint 				loadJPEGTexture (const char *filename);
int 				GetQuadtreeAddress(float lat, float lon, int zoom, char *quad);
int 				GetCoordinatesFromAddress(char *str, int zoom, float *output);
static size_t 			write_data(void *ptr, size_t size, size_t nmemb, void *stream);
static void 			print_cookies(CURL *curl);
size_t 				WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data);
void 				*myrealloc(void *ptr, size_t size);
void 				*DownloadTile(void *threadarg);
int 				DrawTile(char *quad, int zoom, double  outAltitude, int id);
static char			*GetNextTileX(char *addr, int forward);
static char			*GetNextTileY(char *addr, int forward);
GLuint 				getTexId(char *quad);
int 				setTexId(char *quad, GLuint  texId);
int 				PutListTile(char *quad,  GLuint  texId);
int 				setStatusImage(char *quad, int status);
int 				getStatusImage(char *quad);
char 				*getServerName();
int				printStatus(int status);
char 				*qrst2xyz(char *quad);


//----------------------------------------------------------------------------------------------------//
int MyDrawCallback(
				XPLMDrawingPhase     inPhase,    
                                int                  inIsBefore,    
                                void *               inRefcon);

void GMapsMenuHandler(		void * mRef, void * iRef);

int GMapsHandler(
			XPWidgetMessage			inMessage,
			XPWidgetID			inWidget,
			long				inParam1,
			long				inParam2);


//----------------------------------------------------------------------------------------------------//
PLUGIN_API int XPluginStart(	char *		outName,
				char *		outSig,
				char *		outDesc){

	int 		dim;
	XPLMMenuID	id;
	int		item;


	strcpy(outName,	"GMaps For X-Plane");
	strcpy(outSig,	"Mario Cavicchi");
	strcpy(outDesc,	"http://members.ferrara.linux.it/cavicchi/GMaps/");


	
	item 		= XPLMAppendMenuItem(XPLMFindPluginsMenu(), "GMaps", NULL, 1);
	id 		= XPLMCreateMenu("GMaps", XPLMFindPluginsMenu(), item, GMapsMenuHandler, NULL);
	XPLMAppendMenuItem(id, "Setting", (void *)"GMaps", 1);




	
	XPLMRegisterDrawCallback(	MyDrawCallback,	
					xplm_Phase_Objects, 	
					0,	
					NULL);
					
	gPlaneX 	= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY 	= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ 	= XPLMFindDataRef("sim/flightmodel/position/local_z");
	inProbe 	= XPLMCreateProbe(xplm_ProbeY);  


	// Create directory for cache file
	mkdir(CACHE_DIR,  S_IRWXU);


	// lib cURL init, get cookies 
   	chunk.memory	= NULL; /* we expect realloc(NULL, size) to work */
    	chunk.size	= 0;    /* no data at this point */


	curl_global_init(CURL_GLOBAL_ALL);


	headers = curl_slist_append (headers, HEADER_USER_AGENT);
	headers = curl_slist_append (headers, HEADER_ACCEPT);
	headers = curl_slist_append (headers, HEADER_ACCEPT_LANGUAGE);
	headers = curl_slist_append (headers, HEADER_ACCEPT_ENCODING);
	headers = curl_slist_append (headers, HEADER_ACCEPT_CHARSET);
	headers = curl_slist_append (headers, HEADER_KEEP_ALIVE);
	headers = curl_slist_append (headers, HEADER_CONNECTION);

	// Fake Firefox
	curl = curl_easy_init();
 	curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 	1L);
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 	1);
	curl_easy_setopt(curl, CURLOPT_FORBID_REUSE, 	1);
	curl_easy_setopt(curl, CURLOPT_HTTPHEADER, 	headers);
 

	// Get coockie
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,	WriteMemoryCallback);
	curl_easy_setopt(curl, CURLOPT_WRITEDATA, 	(void *)&chunk);

	curl_easy_setopt(curl, CURLOPT_URL, 		"http://maps.google.com/"); 

	curl_easy_setopt(curl, CURLOPT_COOKIEFILE, 	"");
 
	res = curl_easy_perform(curl);
	if (res != CURLE_OK) {
		fprintf(stderr, "Curl perform failed: %s\n", curl_easy_strerror(res));
		return 1;
	}

	print_cookies(curl);
	dim = ( GRID_SIZE * GRID_SIZE + (((GRID_SIZE/2) + 2) * 4 ) );

	thread_data_array 	= (struct thread_data 	*)malloc( sizeof(struct thread_data	) * dim );
	threads			= (pthread_t 		*)malloc( sizeof(pthread_t		) * dim );




	return 1;
}
//----------------------------------------------------------------------------------------------------//

void GMapsMenuHandler(void * mRef, void * iRef){

	if (!strcmp((char *) iRef, "GMaps")){
		printf("ciao\n");
		GMapsWidget = XPCreateWidget(300, 550, 650, 230,
					1,			// Visible
					"GMaps Setting",	// desc
					1,			// root
					NULL,			// no container
					xpWidgetClass_MainWindow);

		XPSetWidgetProperty(GMapsWidget, xpProperty_MainWindowHasCloseBoxes, 1);
		//XPAddWidgetCallback(GMapsWidget, GMapsHandler);


		XPShowWidget(GMapsWidget);

	}
}

int GMapsHandler(
			XPWidgetMessage			inMessage,
			XPWidgetID			inWidget,
			long				inParam1,
			long				inParam2){

	if ( inMessage == xpMessage_CloseButtonPushed ){
		//XPDestroyWidget(GMapsWidget, 1);
		return 1;
	}


}


//----------------------------------------------------------------------------------------------------//

PLUGIN_API void	XPluginStop(void){
	curl_easy_cleanup(curl);
	XPLMUnregisterDrawCallback(
					MyDrawCallback,
					xplm_Phase_LastCockpit, 
					0,
					NULL);	
}

//----------------------------------------------------------------------------------------------------//
PLUGIN_API void XPluginDisable(void){}

//----------------------------------------------------------------------------------------------------//
PLUGIN_API int XPluginEnable(void){ return 1; }

//----------------------------------------------------------------------------------------------------//
PLUGIN_API void XPluginReceiveMessage(	XPLMPluginID		inFromWho,
					long			inMessage,
					void *			inParam){}

/*
Zoom level 0 1:20088000.56607700 meters
Zoom level 1 1:10044000.28303850 meters
Zoom level 2 1:5022000.14151925 meters
Zoom level 3 1:2511000.07075963 meters
Zoom level 4 1:1255500.03537981 meters
Zoom level 5 1:627750.01768991 meters
Zoom level 6 1:313875.00884495 meters
Zoom level 7 1:156937.50442248 meters
Zoom level 8 1:78468.75221124 meters
Zoom level 9 1:39234.37610562 meters
Zoom level 10 1:19617.18805281 meters
Zoom level 11 1:9808.59402640 meters
Zoom level 12 1:4909.29701320 meters
Zoom level 13 1:2452.14850660 meters
Zoom level 14 1:1226.07425330 meters
Zoom level 15 1:613.03712665 meters
Zoom level 16 1:306.51856332 meters
Zoom level 17 1:153.25928166 meters
Zoom level 18 1:76.62964083 meters
Zoom level 19 1:38.31482042 meters
*/

//----------------------------------------------------------------------------------------------------//
int MyDrawCallback(	XPLMDrawingPhase     inPhase,    
                        int                  inIsBefore,    
                        void *               inRefcon){


	int	i,x,y;
	float 	planeX,		planeY, 	planeZ;
	double	outLatitude,	outLongitude,	outAltitude;
	char 	quad[25] = {};
	char	*cursor, *c2, *frame;
	int	zoom;
	int	FRAME_GRID_SIZE;


	/* If any data refs are missing, do not draw. */
	if (!gPlaneX || !gPlaneY || !gPlaneZ)	return 1;
		
	/* Fetch the plane's location at this instant in OGL coordinates. */	
	planeX 	= XPLMGetDataf(gPlaneX);
	planeY 	= XPLMGetDataf(gPlaneY);
	planeZ 	= XPLMGetDataf(gPlaneZ);

	// Get Geo position of the plane
	XPLMLocalToWorld(planeX, planeY, planeZ, &outLatitude, &outLongitude, &outAltitude);
	//printf("Lat: %f Lon: %f Alt: %f x: %f y: %f z: %f\n", outLatitude, outLongitude, outAltitude, planeX, planeY, planeZ);

	// Set zoom livel
	zoom = 19;


	
	// Get google maps string based on plane coordinates
	GetQuadtreeAddress(outLatitude, outLongitude, zoom, quad);
	quad[ strlen(quad) - 1 ] = 'q';

	// move to top left
	cursor = quad;
	for( i = 0 ; i < (int)(GRID_SIZE/2); i++){
		cursor = GetNextTileX(cursor,0); 
		cursor = GetNextTileY(cursor,0);
	}
	frame = cursor;
	// Drow near the plane
 	for (x = 0, i = 0; x < GRID_SIZE; x++) {
		c2 	= cursor;
		cursor 	= GetNextTileX(cursor,1);
		for (y = 0; y < GRID_SIZE; y++, i++){
			DrawTile( c2, zoom, outAltitude, i);
			c2 = GetNextTileY(c2,1);
		}
	}


	
	// Drow first frame
	frame = GetNextTileX( frame, 0 ); 
	frame = GetNextTileY( frame, 0 );
	frame[ strlen(frame) - 1 ] = '\0';
	cursor = frame;
	FRAME_GRID_SIZE =  (int)(GRID_SIZE/2) + 2;
	zoom--;

 	for (x = 0, i = 0; x < FRAME_GRID_SIZE; x++) {
		c2 	= cursor;
		cursor 	= GetNextTileX(cursor,1);
		for (y = 0; y < FRAME_GRID_SIZE; y++, i++){
			if ( y == 0 ) 				DrawTile( c2, zoom, outAltitude, i);
			if ( y == (FRAME_GRID_SIZE - 1) ) 	DrawTile( c2, zoom, outAltitude, i);

			if ( x == 0 ) 				DrawTile( c2, zoom, outAltitude, i);
			if ( x == (FRAME_GRID_SIZE - 1) ) 	DrawTile( c2, zoom, outAltitude, i);
			
			c2 = GetNextTileY(c2,1);
		}
	}





	return 1;
}

//----------------------------------------------------------------------------------------------------//
static struct gl_texture_t *ReadJPEGFromFile (const char *filename){
	struct gl_texture_t *texinfo = NULL;
	FILE *fp = NULL;
	struct jpeg_decompress_struct cinfo;
	struct jpeg_error_mgr jerr;
	JSAMPROW j;
	int i;

	fp = fopen (filename, "rb");
	if (!fp) return NULL;
	jpeg_create_decompress (&cinfo);
	
	cinfo.err = jpeg_std_error (&jerr);
	jpeg_stdio_src (&cinfo, fp);


	jpeg_read_header (&cinfo, TRUE);
	jpeg_start_decompress (&cinfo);

	texinfo = (struct gl_texture_t *)malloc (sizeof (struct gl_texture_t));
	texinfo->width = cinfo.image_width;
	texinfo->height = cinfo.image_height;
	texinfo->internalFormat = cinfo.num_components;

	if (cinfo.num_components == 1) 	texinfo->format = GL_LUMINANCE;
	else				texinfo->format = GL_RGB;

	texinfo->texels = (GLubyte *)malloc (sizeof (GLubyte) * texinfo->width * texinfo->height * texinfo->internalFormat);

	for (i = 0; i < texinfo->height; ++i){
		j = 	(texinfo->texels +
			((texinfo->height - (i + 1)) * texinfo->width * texinfo->internalFormat));
		jpeg_read_scanlines (&cinfo, &j, 1);
	}


	jpeg_finish_decompress (&cinfo);
	jpeg_destroy_decompress (&cinfo);
	
	fclose (fp);
	return(texinfo);
}

//----------------------------------------------------------------------------------------------------//
GLuint loadJPEGTexture (const char *filename){
	struct gl_texture_t *jpeg_tex = NULL;
	GLuint tex_id = 0;

	jpeg_tex = ReadJPEGFromFile (filename);


	if (jpeg_tex && jpeg_tex->texels){
		glGenTextures (1, &jpeg_tex->id);

		glBindTexture (GL_TEXTURE_2D, jpeg_tex->id);

		glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
		glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);


#if 0
		glTexImage2D (GL_TEXTURE_2D, 0, jpeg_tex->internalFormat,
				jpeg_tex->width, jpeg_tex->height, 0, jpeg_tex->format,
				GL_UNSIGNED_BYTE, jpeg_tex->texels);

#else

		gluBuild2DMipmaps (GL_TEXTURE_2D, jpeg_tex->internalFormat,
	                         jpeg_tex->width, jpeg_tex->height,
	                         jpeg_tex->format, GL_UNSIGNED_BYTE, jpeg_tex->texels);
#endif

		tex_id = jpeg_tex->id;

		free (jpeg_tex->texels);
		free (jpeg_tex);
	}
	return tex_id;
}

//----------------------------------------------------------------------------------------------------//
float MercatorToNormal( float y){
	y = sin( -1.0f * y * 4.0f * atan(1) / 180.0f );
	y = (1.0f + y ) / ( 1.0f - y );
	y = 0.5 * log(y);
	y = y * 1.0 / (2.0f * 4.0f *atan(1.0f));
	return(y + 0.5);

}
//----------------------------------------------------------------------------------------------------//
float NormalToMercator( float y){
	y = y - 0.5f;
	y = y * (2.0f * 4.0f * atan(1.0f) );
	y = expf(y * 2.0f );
	y = ( y - 1.0f ) / ( y  + 1.0f );
	y = atan( y / sqrt( -1.0f * y * y + 1.0f ) );
	return( y * -180.0f /(4.0f *atan(1.0f)) );

}


//----------------------------------------------------------------------------------------------------//

int GetQuadtreeAddress(float lat, float lon, int zoom, char *quad){   
	char 	lookup[4] = { 'q', 'r', 't', 's' };
	float 	x, y;
	int	i, b;


	quad[0] = 't';
	x 	= ( 180.0f + lon ) / 360.0f;
	y	= MercatorToNormal(lat);

	for (i = 1 ; i < zoom ; i++){
		b = 0;
		x = x - (int)x;
		y = y - (int)y;
		if ( x >= 0.5f ) b += 1;
		if ( y >= 0.5f ) b += 2;
		quad[i] = lookup[b];
		x *= 2;
		y *= 2;

	}
	return(0);
}

//----------------------------------------------------------------------------------------------------//
int GetCoordinatesFromAddress(char *str, int zoom, float *output){

	// get normalized coordinate first
        float 	x 	= 0.0f;
        float	y 	= 0.0f;
	float	scale 	= 1.0f;
	float	lon_min, lat_min, lon_max, lat_max, lon, lat;

	int	i;

	for ( i = 1 ; i < zoom ; i++ ){
		scale *= 0.5;
		if ( ( str[i] == 'r' ) || ( str[i] == 's' ) ) x += scale;
		if ( ( str[i] == 't' ) || ( str[i] == 's' ) ) y += scale;
	}


	output[0] = lon		= (x + scale * 0.5f - 0.5f) * 360.0f;
	output[1] = lat		= NormalToMercator( y + scale * 0.5 );

	output[2] = lon_min	= (x - 0.5f) * 360.0f;
	output[3] = lat_min	= NormalToMercator(y);

	output[4] = lon_max	= ( x + scale - 0.5f ) * 360.0f;
	output[5] = lat_max	= NormalToMercator( y + scale );


	return(0);
}

//----------------------------------------------------------------------------------------------------//
void *myrealloc(void *ptr, size_t size){
	if(ptr)	return realloc(ptr, size);
	else	return malloc(size);
}

//----------------------------------------------------------------------------------------------------//

size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data){
	size_t realsize = size * nmemb;
	struct MemoryStruct *mem = (struct MemoryStruct *)data;
 
	mem->memory = (char *)myrealloc(mem->memory, mem->size + realsize + 1);
	if (mem->memory) {
		memcpy(&(mem->memory[mem->size]), ptr, realsize);
		mem->size += realsize;
		mem->memory[mem->size] = 0;
	}
	return realsize;
}

//----------------------------------------------------------------------------------------------------//
 
static void print_cookies(CURL *curl){
	CURLcode res;
	struct curl_slist *cookies;
	struct curl_slist *nc;
	int i;
 
	printf("Cookies, it knows:\n");
	res = curl_easy_getinfo(curl, CURLINFO_COOKIELIST, &cookies);
	if (res != CURLE_OK) {
		fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
		exit(1);
	}
	nc = cookies, i = 1;
	while (nc) {
	printf("[%d]: %s\n", i, nc->data);
		nc = nc->next;
		i++;
	}
	if (i == 1) {
		printf("(none)\n");
	}
	curl_slist_free_all(cookies);
}

//----------------------------------------------------------------------------------------------------//
static size_t write_data(void *ptr, size_t size, size_t nmemb, void *stream){
	int written = fwrite(ptr, size, nmemb, (FILE *)stream);
	return written;
}


//----------------------------------------------------------------------------------------------------//
void *DownloadTile(void *threadarg){

	FILE 		*image;
	char		image_name[255] = {};
	char		image_url[255] 	= {};
	char		quad[25]	= {};
	CURL		*icurl;
	CURLcode	ires;

	struct curl_slist	*cookies;
	struct thread_data	*data;

	data 	= (struct thread_data *)threadarg;

	res = curl_easy_getinfo(curl, CURLINFO_COOKIELIST, &cookies);
	if (res != CURLE_OK) {
		printf("Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
		pthread_exit(0);
	}

	icurl = curl_easy_init();
 	curl_easy_setopt(icurl, CURLOPT_NOPROGRESS, 		1L);
	curl_easy_setopt(icurl, CURLOPT_FOLLOWLOCATION, 	1);
	curl_easy_setopt(icurl, CURLOPT_FORBID_REUSE, 		1);
	curl_easy_setopt(icurl, CURLOPT_HTTPHEADER,      	headers); 

	ires 	= curl_easy_setopt(icurl, CURLOPT_COOKIELIST, cookies->data);

    	if (ires != CURLE_OK) {
		printf("Curl curl_easy_setopt failed: %s\n", curl_easy_strerror(ires));
		pthread_exit(0);
	}




	pthread_mutex_lock(&mut);	// Lock!
	strcpy(quad, data->quad);

	sprintf(image_url, "http://%s/kh/v=45&%s", 	getServerName(), 	qrst2xyz(quad));
	

	pthread_mutex_unlock(&mut);	// Unlock!

	sprintf(image_name, "%s/%s.jpg", 		CACHE_DIR, 		quad);
	//printf("Start to download %s ...\n", image_url);

	// Image download 
	curl_easy_setopt(icurl, CURLOPT_URL, image_url);

	image = fopen(image_name,"w");
	if (image == NULL) {
		printf("fopen in DownloadTile problem!\n");
		curl_easy_cleanup(icurl);
		pthread_exit(0);
	}
	curl_easy_setopt(icurl,	CURLOPT_WRITEFUNCTION, 	write_data);
	curl_easy_setopt(icurl,	CURLOPT_WRITEDATA, 	image);
	curl_easy_perform(icurl);
	if (ires != CURLE_OK){
		printf("Curl perform failed: %s\n", curl_easy_strerror(ires));
		pthread_exit(0);	
	}

	fclose(image);

	pthread_mutex_lock(&mut);	// Lock!
	if ( setStatusImage(quad, READY) == NOT_FOUND ){
		printf("setStatusImage in DownloadTile problem!\n");
		pthread_exit(0);
	}	
	pthread_mutex_unlock(&mut);	// Unlock!

	//printf("End to download %s...\n", image_name);
	pthread_exit(0);
}

//----------------------------------------------------------------------------------------------------//
int  DrawTile(char *quad, int zoom, double  outAltitude, int id){

	float	*TexCoordX, 	*TexCoordY;
	int	i,		j,		k;
	int	matrixSize;	
	float	stepMesh;	
	GLuint  texId;
	char	image_name[255] = {};

	float	coord[6];
	double 	tileX,		tileY, 		tileZ;
	double 	tileX_LL,	tileY_LL,	tileZ_LL;
	double 	tileX_UR,	tileY_UR,	tileZ_UR;
	float 	pntX,		pntY, 		pntZ;
	float 	*terX, 		*terY, 		*terZ;


	int	TILE_SIZE, MESH_SIZE;
	XPLMProbeInfo_t outInfo;

	sprintf(image_name, "%s/%s.jpg", CACHE_DIR, quad );

	switch(	getStatusImage(quad) ) {
		case NOT_FOUND:
			PutListTile(quad, 0);
			break;

		case FOUND:
			setStatusImage(quad, BUSY);	
			// Download image
			thread_data_array[id].quad = (char *)malloc(sizeof(char) * ( strlen(quad) + 1) );
			strcpy(thread_data_array[id].quad, quad);
			thread_data_array[id].thread_id = id;
			
			pthread_create( &threads[id], NULL, DownloadTile, (void *) &thread_data_array[id] );
			break;

		case BUSY:
			break;

		case READY:
			setTexId( quad, loadJPEGTexture(image_name) );
			setStatusImage(quad, LOADED);
			break;

		case LOADED:
			texId = getTexId(quad);
			break;
		default:
			printf("Status %d unknow!\n", getStatusImage(quad));
			break;

	}
	if ( getStatusImage(quad) != LOADED ) return(0);


	// Get tile posizione 
	GetCoordinatesFromAddress(quad, zoom, coord);

	// Get OGL coordiantes of tile posizione
	XPLMWorldToLocal( (double)coord[1], (double)coord[0], outAltitude, &tileX,	&tileY,		&tileZ 		);
	XPLMWorldToLocal( (double)coord[3], (double)coord[2], outAltitude, &tileX_LL,	&tileY_LL,	&tileZ_LL 	);
	XPLMWorldToLocal( (double)coord[5], (double)coord[4], outAltitude, &tileX_UR,	&tileY_UR,	&tileZ_UR 	);

	TILE_SIZE = (int)( tileX_UR - tileX_LL );
	MESH_SIZE = 4;

	//printf("http://khm0.google.com/kh?v=3&t=%s center: %f %f TILE_SIZE: %d Plane: %f %f\n",quad, coord[1], coord[0], TILE_SIZE, outLatitude, outLongitude);


	matrixSize	= MESH_SIZE + 1;
	stepMesh 	= (float)TILE_SIZE / (float)MESH_SIZE;

	terX 		= (float *)malloc( ( matrixSize * matrixSize ) * sizeof(float) );
	terY 		= (float *)malloc( ( matrixSize * matrixSize ) * sizeof(float) );
	terZ 		= (float *)malloc( ( matrixSize * matrixSize ) * sizeof(float) );
	TexCoordX 	= (float *)malloc( ( matrixSize * matrixSize ) * sizeof(float) );
	TexCoordY	= (float *)malloc( ( matrixSize * matrixSize ) * sizeof(float) );

	outInfo.structSize = sizeof(outInfo);

	
	for( i = 0, k = 0; i < matrixSize ; i++){
		for( j = 0 ; j < matrixSize ; j++, k++){
			pntX = tileX_LL + ( i * stepMesh );
			pntZ = tileZ_LL + ( j * stepMesh );
			pntY = tileY;
			//printf("pntX: %f pntY: %f pntZ: %f i: %d j: %d\n", pntX, pntY, pntZ, i, j);

			XPLMProbeTerrainXYZ( inProbe, pntX, pntY, pntZ, &outInfo);    
			terX[k] 	= outInfo.locationX;
			terY[k] 	= outInfo.locationY;
			terZ[k] 	= outInfo.locationZ;

			TexCoordX[k] 	=	(float)i / (float)(matrixSize - 1);
			TexCoordY[k] 	= 1.0f -(float)j / (float)(matrixSize - 1);
			//printf("%f\t%f\n", TexCoordX[k], TexCoordY[k]);
		}
	}

	/* Reset the graphics state.  This turns off fog, texturing, lighting,
	 * alpha blending or testing and depth reading and writing, which
	 * guarantees that our axes will be seen no matter what. */
	XPLMSetGraphicsState(0, 0, 0, 0, 0, 0, 0);
	

	glEnable(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, texId);
	glBegin(GL_TRIANGLES);
	for( i = 0 ; i < ( matrixSize - 1 ); i++){
		for( j = 0 ; j < ( matrixSize - 1 ); j++){
			
			// First triangle		
			// glColor3f(1.0, 0.0, 0.0);
			k = j 		+ ( matrixSize * i 	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);
			
			k = j  		+ ( matrixSize * (i+1)	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);

			k = j + 1  	+ ( matrixSize * i 	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);


			// Second triangle
			// glColor3f(0.0, 1.0, 1.0);
			k = j + 1	+ ( matrixSize * (i+1)	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);

			k = j + 1  	+ ( matrixSize * i 	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);

			k = j  		+ ( matrixSize * (i+1)	);
			glTexCoord2f(TexCoordX[k], TexCoordY[k]);
			glVertex3f(terX[k], terY[k], terZ[k]);


		}
	}
	glEnd();
	glDisable(GL_TEXTURE_2D);
	return(0);
}

//----------------------------------------------------------------------------------------------------//


static char *GetNextTileX(char *addr, int forward){
	int 		length, i;
	char		last;
	static char	*parent;
	static char	*new_addr;


	if (!strcmp(addr, "") ){
		return(new_addr);
		return(0); 
	}

	parent		= (char *)malloc(sizeof(char) * 25);
	new_addr 	= (char *)malloc(sizeof(char) * 25);
	for (i = 0; i < 25 ; i ++){ parent[i] = '\0'; new_addr[i] = '\0'; }

	length		= strlen(addr);
	last		= addr[ length - 1 ];
	strncpy(parent, addr, length-1);
	
	if 	( last == 'q' ) {	last = 'r'; 	if (! forward ) parent = GetNextTileX( parent,  forward );	}	
	else if ( last == 'r' ) {	last = 'q'; 	if (  forward ) parent = GetNextTileX( parent,  forward );	}	
	else if ( last == 's' ) {	last = 't'; 	if (  forward ) parent = GetNextTileX( parent,  forward ); 	}	
	else if ( last == 't' ) {	last = 's'; 	if (! forward ) parent = GetNextTileX( parent,  forward );	}	

	sprintf(new_addr, "%s%c", parent, last);
	return(new_addr);

	return(0);

}


//----------------------------------------------------------------------------------------------------//

static char *GetNextTileY(char *addr, int forward){
	int 		length, i;
	char		last;
	static char	*parent;
	static char	*new_addr;


	if (!strcmp(addr, "") ){
		return(new_addr);
		return(0); 
	}

	parent		= (char *)malloc(sizeof(char) * 25);
	new_addr 	= (char *)malloc(sizeof(char) * 25);
	for (i = 0; i < 25 ; i ++){ parent[i] = '\0'; new_addr[i] = '\0'; }

	length		= strlen(addr);
	last		= addr[ length - 1 ];
	strncpy(parent, addr, length-1);
	
	if 	( last == 'q' ) {	last = 't'; 	if (! forward ) parent = GetNextTileY( parent,  forward );	}	
	else if ( last == 'r' ) {	last = 's'; 	if (! forward ) parent = GetNextTileY( parent,  forward );	}	
	else if ( last == 's' ) {	last = 'r'; 	if (  forward ) parent = GetNextTileY( parent,  forward ); 	}	
	else if ( last == 't' ) {	last = 'q'; 	if (  forward ) parent = GetNextTileY( parent,  forward );	}	

	sprintf(new_addr, "%s%c", parent, last);
	return(new_addr);

	return(0);

}

//----------------------------------------------------------------------------------------------------//
int PutListTile(char *quad,  GLuint  texId){
	struct displayTile *tmp;

	//printf("PutListTile... %s\n", quad);
	if (listTile == NULL){
		//printf("Empty list...\n");
		listTile = (struct displayTile *)malloc(sizeof( struct displayTile ) );
		listTile->quad = (char *)malloc(sizeof(char) * ( strlen(quad) + 1) );
		strcpy(listTile->quad,quad);
		listTile->texId 	= texId;
		listTile->status 	= FOUND;
		listTile->next		= NULL;
		return(FOUND);
	}
	for( tmp = listTile; tmp->next != NULL; tmp = tmp->next  ){};
	
	tmp->next 	= (struct displayTile *)malloc(sizeof(struct displayTile) );
	tmp->next->quad = (char *)malloc(sizeof(char) * ( strlen(quad) + 1) );

	strcpy(tmp->next->quad,quad);
	tmp->next->texId 	= texId;
	tmp->next->status	= FOUND;
	tmp->next->next 	= NULL;
	return(FOUND);
}


//----------------------------------------------------------------------------------------------------//

GLuint getTexId(char *quad){
	struct displayTile *tmp;
	//printf("searchTexId %s...\n", quad);
	if ( listTile == NULL ) return(NOT_FOUND);
	for( tmp = listTile; tmp->next != NULL; tmp = tmp->next  ){
		if ( !strcmp(tmp->quad, quad) ){
			return(tmp->texId);
		}
	}
	return(NOT_FOUND);
}


//----------------------------------------------------------------------------------------------------//
int setTexId(char *quad, GLuint  texId){
	struct displayTile *tmp;
	//printf("searchTexId %s...\n", quad);
	if ( listTile == NULL ) return(NOT_FOUND);
	for( tmp = listTile; tmp->next != NULL; tmp = tmp->next  ){
		if ( !strcmp(tmp->quad, quad) ){
			tmp->texId = texId;
			return(FOUND);
		}
	}
	return(NOT_FOUND);
}

//----------------------------------------------------------------------------------------------------//


int setStatusImage(char *quad, int status){
	struct displayTile *tmp;
	if ( listTile == NULL ) return(NOT_FOUND);
	for( tmp = listTile; tmp->next != NULL; tmp = tmp->next  ){
		if ( !strcmp(tmp->quad, quad) ){
			tmp->status = status;
			return(FOUND);
		}
	}
	return(NOT_FOUND);
}

//----------------------------------------------------------------------------------------------------//

int getStatusImage(char *quad){
	struct displayTile *tmp;
	if ( listTile == NULL ) return(NOT_FOUND);
	for( tmp = listTile; tmp->next != NULL; tmp = tmp->next  ){
		if ( !strcmp(tmp->quad, quad) ){
			return(tmp->status);
		}
	}
	return(NOT_FOUND);
}


//----------------------------------------------------------------------------------------------------//

char *getServerName(){
	char *out;
	out = servers[server_index];
	server_index++;
	if (server_index == 4 ) server_index = 0;
	return(out);
}


//----------------------------------------------------------------------------------------------------//
int printStatus(int status){
	switch(status){
		case READY:
			printf("READY");
			break;	
		case LOADED:
			printf("LOADED");
			break;
		case BUSY:
			printf("BUSY");
			break;
		case FOUND:
			printf("FOUND");
			break;
		case NOT_FOUND:
			printf("NOT_FOUND");
			break;
			
	}
	return(0);

}

//----------------------------------------------------------------------------------------------------//
char *qrst2xyz(char *quad){
	int 	i,j;
        int 	x = 0;
        int 	y = 0;
        int 	z = 17;
	char 	c;
	char	gal[8] 		= "Galileo";
        char	qrst[4][3] 	= { "00", "01", "10", "11" };

	static 	char tmp[255];
	// 48

	for(i= 1; i < strlen(quad) ; i++){
		c = quad[i];
		if ( c == 'q' ) j = 0;
		if ( c == 't' ) j = 1;
		if ( c == 'r' ) j = 2;
		if ( c == 's' ) j = 3;
		x = x * 2 + ( qrst[j][0] - 48 );
		y = y * 2 + ( qrst[j][1] - 48 );
		z = z - 1;
	}	

	//f="Galileo".substr(0,(b.x*3+b.y)%8)
	gal[ ((x*3+y)%8)+1 ] = '\0';

	sprintf(tmp, "x=%d&y=%d&zoom=%d&s=Gal", x,y,z);


	return(tmp);
}

