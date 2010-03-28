#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// SDK include
#include "XPLMDisplay.h"
#include "XPLMDataAccess.h"
#include "XPLMGraphics.h"
#include "XPLMScenery.h"
#include "XPLMMenus.h"
#include "XPWidgets.h"
#include "XPStandardWidgets.h"
#include "XPLMUtilities.h"


#define BUFFER_CONSOL_COL	80
#define BUFFER_CONSOL_LIN	35
#define SERVERS_NUMBER		4
#define GMAPS_VERION 		58


XPLMWindowID    gConsole		= NULL;
XPLMKeyFlags	gFlags			= 0;
char		gVirtualKey		= 0;
char		gChar			= 0;
char 	GMapServers[SERVERS_NUMBER][16]	= { "khm0.google.com", "khm1.google.com", "khm2.google.com", "khm3.google.com" };
int		GMapsServerIndex	= 0;


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
	double	x;
	double	y;
	double	z;
	double	lat;
	double	lng;
	double	tileSize;
	double	c;
	double	PI;
	double 	*pixelsPerLonDegree;
	double	*pixelsPerLonRadian;
	double	*numTiles;
	double	*bitmapOrigo[2];
	double	bc;
	double	Wa;
	char	*Galileo;
	char	*url;
} TileObj;



void	GMapsDrawWindowCallback( XPLMWindowID inWindowID, void *inRefcon);
int	GMapsHandleMouseClickCallback( XPLMWindowID inWindowID, int x, int y, XPLMMouseStatus inMouse, void *inRefcon);
int	GMapsKeySniffer( char inChar, XPLMKeyFlags inFlags, char inVirtualKey, void *inRefcon);
void	GMapsHandleKeyCallback( XPLMWindowID inWindowID, char inKey, XPLMKeyFlags inFlags, char inVirtualKey,  void *inRefcon, int  losingFocus);


