#ifndef _GMAPS_H
#define _GMAPS_H

// Standard include
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

// lib cURL include
#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>

// OpenGL include
#include <GL/gl.h>
#include <GL/glu.h>

// POSIX Threads 
#include <pthread.h>    

// SDK X-Plane include
#include "XPLMDisplay.h"
#include "XPLMDataAccess.h"
#include "XPLMGraphics.h"
#include "XPLMScenery.h"
#include "XPLMMenus.h"
#include "XPWidgets.h"
#include "XPStandardWidgets.h"
#include "XPLMUtilities.h"
#include "XPLMProcessing.h"



#define BUFFER_CONSOL_COL	80
#define BUFFER_CONSOL_LIN	35
#define SERVERS_NUMBER		4
#define GMAPS_VERION 		58
#define LAYER_NMBER		20 
#define	CACHE_DIR		"./GMapsCache"
#define USER_AGENT		"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2 GTB7.0"
#define	TOKEN_STRING		"mSatelliteToken"

#define NOLOADED		0
#define WAIT			1
#define LOADED			2

#define	ENABLE			1
#define	DISABLE			0
#define	MAX_THREAD_NUMBER	100


XPLMWindowID    gConsole		= NULL;
XPLMKeyFlags	gFlags			= 0;
char		gVirtualKey		= 0;
char		gChar			= 0;
char 	GMapServers[SERVERS_NUMBER][16]	= { "khm0.google.com", "khm1.google.com", "khm2.google.com", "khm3.google.com" };
int		GMapsServerIndex	= 0;
double		currentPosition[3]	= {-1.0, -1.0, -1.0};

XPLMDataRef		gPlaneX;
XPLMDataRef		gPlaneY;
XPLMDataRef		gPlaneZ;
XPLMDataRef		gPlaneHeading;
XPLMDataRef		gPlaneLat;
XPLMDataRef		gPlaneLon;
XPLMDataRef		gPlaneAlt;

XPLMProbeRef		inProbe;

struct consoleBuffer{
	char *line;
	struct consoleBuffer *next;

} consoleBuffer;
struct	consoleBuffer *consoleOutput = NULL;


struct TileObj{
	double	x,		y,		z;
	double	lat,		lng,		alt;
	double	minLat,		minLng,		maxLat,		maxLng;
	double	X_LL,		Y_LL,		Z_LL;
	double	X_UR,		Y_UR,		Z_UR;
	double **terX,		**terY,		**terZ;
	double **TexCoordX,	**TexCoordY;

	double 	*pixelsPerLonDegree;
	double	*pixelsPerLonRadian;

	double	matrixSize;
	double	tileSize;
	double	originShift;
	double	c;
	double	Resolution;	
	double	*numTiles;
	double	*bitmapOrigo[2];
	double	bc;
	double	Wa;
	char	*Galileo;
	char	*url;


	GLuint  	texId;
        unsigned char   *texture;
	int		imageWidth;
	int		imageHeight;
	int		loaded;

	struct	TileObj *next;
	struct	TileObj *prev;

} TileObj;

// Pointer to head of tile list
struct TileObj *TileList	= NULL;


// Struct to pass data to thread
struct thread_data {
	int		thread_id;
	struct TileObj	*tile;
};

struct thread_data	thread_data_array[MAX_THREAD_NUMBER];
pthread_t		thread_id[MAX_THREAD_NUMBER];
int			thread_index = 0;

pthread_mutex_t		mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_attr_t		attr;



void	GMapsDrawWindowCallback( XPLMWindowID inWindowID, void *inRefcon);
int     GMapsDrawCallback( XPLMDrawingPhase inPhase, int inIsBefore, void *inRefcon);
int	GMapsHandleMouseClickCallback( XPLMWindowID inWindowID, int x, int y, XPLMMouseStatus inMouse, void *inRefcon);
int	GMapsKeySniffer( char inChar, XPLMKeyFlags inFlags, char inVirtualKey, void *inRefcon);
void	GMapsHandleKeyCallback( XPLMWindowID inWindowID, char inKey, XPLMKeyFlags inFlags, char inVirtualKey,  void *inRefcon, int  losingFocus);
float	GMapsMainFunction( float inElapsedSinceLastCall, float inElapsedTimeSinceLastFlightLoop, int inCounter, void *inRefcon);    


#endif
