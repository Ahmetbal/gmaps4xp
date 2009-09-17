#if IBM
#include <windows.h>
#endif
#if LIN
#include <GL/gl.h>
#include <GL/glu.h>
#else
#if __GNUC__
#include <OpenGL/gl.h>
#else
#include <gl.h>
#endif
#endif
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <jpeglib.h>
#include <math.h>


#include "XPLMDisplay.h"
#include "XPLMDataAccess.h"
#include "XPLMGraphics.h"
#include "XPLMScenery.h"


struct gl_texture_t{
	GLsizei width;
	GLsizei height;

	GLenum format;
	GLint internalFormat;
	GLuint id;

	GLubyte *texels;
};


static struct gl_texture_t *ReadJPEGFromFile (const char *filename);
GLuint 	loadJPEGTexture (const char *filename);
int 	GetQuadtreeAddress(float lat, float lon, int zoom, char *quad);
int 	GetCoordinatesFromAddress(char *str, int zoom, float *output);

XPLMDataRef		gPlaneX;
XPLMDataRef		gPlaneY;
XPLMDataRef		gPlaneZ;
GLuint 			texId; 
XPLMProbeRef		inProbe;

int MyDrawCallback(
				XPLMDrawingPhase     inPhase,    
                                int                  inIsBefore,    
                                void *               inRefcon);


PLUGIN_API int XPluginStart(	char *		outName,
				char *		outSig,
				char *		outDesc){


	strcpy(outName,	"GMaps For X-Plane");
	strcpy(outSig,	"Mario Cavicchi");
	strcpy(outDesc,	"http://members.ferrara.linux.it/cavicchi/GMaps");
	
	XPLMRegisterDrawCallback(	MyDrawCallback,	
					xplm_Phase_Objects, 	
					0,	
					NULL);
					
	gPlaneX 	= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY 	= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ 	= XPLMFindDataRef("sim/flightmodel/position/local_z");
	inProbe 	= XPLMCreateProbe(xplm_ProbeY);  
	texId		= loadJPEGTexture ("./test.jpg");

	if (!texId) return 1;
	return 1;
}

PLUGIN_API void	XPluginStop(void){
	XPLMUnregisterDrawCallback(
					MyDrawCallback,
					xplm_Phase_LastCockpit, 
					0,
					NULL);	
}

PLUGIN_API void XPluginDisable(void){}

PLUGIN_API int XPluginEnable(void){ return 1; }

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

int MyDrawCallback(	XPLMDrawingPhase     inPhase,    
                        int                  inIsBefore,    
                        void *               inRefcon){


	float 	planeX,		planeY, 	planeZ;
	float 	pntX,		pntY, 		pntZ;
	float 	*terX, 		*terY, 		*terZ;
	double	outLatitude,	outLongitude,	outAltitude;
	float	*TexCoordX, 	*TexCoordY;
	int	i,		j,		k;
	int	matrixSize;	
	float	stepMesh;	
	char 	quad[25] = {};
	float	coord[6];

	double 	tileX,		tileY, 		tileZ;
	double 	tileX_LL,	tileY_LL,	tileZ_LL;
	double 	tileX_UR,	tileY_UR,	tileZ_UR;

	int	zoom;
	int	TILE_SIZE, MESH_SIZE;

	XPLMProbeInfo_t outInfo;

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

	// Get tile posizione 
	GetCoordinatesFromAddress(quad, zoom, coord);

	// Get OGL coordiantes of tile posizione
	XPLMWorldToLocal( (double)coord[1], (double)coord[0], outAltitude, &tileX,	&tileY,		&tileZ 		);
	XPLMWorldToLocal( (double)coord[3], (double)coord[2], outAltitude, &tileX_LL,	&tileY_LL,	&tileZ_LL 	);
	XPLMWorldToLocal( (double)coord[5], (double)coord[4], outAltitude, &tileX_UR,	&tileY_UR,	&tileZ_UR 	);

	TILE_SIZE = (int)( tileX_UR - tileX_LL );
	MESH_SIZE = 4;

	printf("http://khm0.google.com/kh?v=3&t=%s center: %f %f TILE_SIZE: %d Plane: %f %f\n",quad, coord[1], coord[0], TILE_SIZE, outLatitude, outLongitude);


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

	return 1;
}

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

float MercatorToNormal( float y){
	y = sin( -1.0f * y * 4.0f * atan(1) / 180.0f );
	y = (1.0f + y ) / ( 1.0f - y );
	y = 0.5 * log(y);
	y = y * 1.0 / (2.0f * 4.0f *atan(1.0f));
	return(y + 0.5);

}
float NormalToMercator( float y){
	y = y - 0.5f;
	y = y * (2.0f * 4.0f * atan(1.0f) );
	y = expf(y * 2.0f );
	y = ( y - 1.0f ) / ( y  + 1.0f );
	y = atan( y / sqrt( -1.0f * y * y + 1.0f ) );
	return( y * -180.0f /(4.0f *atan(1.0f)) );

}



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


